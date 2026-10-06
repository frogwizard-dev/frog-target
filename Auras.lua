local _, ns = ...
local Auras = {}
Auras.__index = Auras

-- Status effects under a unit's bar, in two rows, each with its own settings: debuffs (yours,
-- then everyone else's) and buffs, in either order (auras.order). Each row is one of 12.1's
-- AuraContainers: the engine picks and draws the auras, so it keeps working where addons can't
-- read aura data. Lessons carried over from PersonalResourceTweaks: position a container before
-- setting it up, never anchor anything to it, and size the buttons ourselves (the engine makes
-- them 0x0). How many auras there are can be secret, so each row is given room for one line.
-- Each bar (the target's, the focus's) has its own set: ns.NewAuras(bar). The row settings are
-- shared; whether a bar shows them at all is the bar's own (bar:Has("auras")).

local SORT = AuraContainerSortMethod and AuraContainerSortMethod.Default
local SORT_DIR = AuraContainerSortDirection and AuraContainerSortDirection.Normal
local TIMER_HEIGHT = 12 -- the timer printed under each icon

local A = FrogLib.Auras -- the rows' building blocks (FrogLib's Auras.lua)

-- Rounded icons, the shape of FrogUI's action bar buttons (and the cooldown manager's): the
-- icon cut by the rounded mask inside a 2px border, the border rounded the same way round the
-- whole button, and the cooldown sweep following the corners. Square: a 1px border.
local function Shape(icon, border, button, cooldown)
    A.Shape(icon, border, button, cooldown, ns.db.auras.rounded)
end

local function StyleButton(d)
    local all, t = ns.db.auras, ns.db.text
    local cfg = all[d.row]
    if d.size ~= cfg.size and pcall(d.button.SetSize, d.button, cfg.size, cfg.size) then
        d.size = cfg.size
    end
    local font, size = all.font or t.font, math.max(9, math.floor(cfg.size * 0.46))
    ns.Media:SetFont(d.stack, font, size, t.outline)
    ns.Media:SetFont(d.duration, font, size, t.outline)
    d.duration:SetShown(cfg.showTimer)
end

-- styled: the row's list of styled buttons, restyled when the settings change.
local function MakeInit(styled, row, harmful)
    return function(button)
        -- The timer goes under the icon rather than on it.
        local d = A.InitButton(button, { border = harmful and { 0.75, 0.12, 0.08 } or nil,
            rounded = ns.db.auras.rounded, style = function(new)
                new.row = row
                StyleButton(new)
            end })
        table.insert(styled, d)
    end
end

local function Layout(cfg, spacing)
    -- Extra line spacing leaves room for the timer printed under each icon.
    return { elementWidth = cfg.size, elementHeight = cfg.size, elementSpacing = spacing,
        lineSpacing = spacing + (cfg.showTimer and TIMER_HEIGHT or 0) }
end

------------------------------------------------------------------------------
-- A bar's set of rows
------------------------------------------------------------------------------

-- owner: the bar they hang under (Target.lua), for its unit, its switches and its width.
function ns.NewAuras(owner)
    local a = setmetatable({
        owner = owner,
        unit = owner.unit,
        -- Per row: its container, what it was built with, its group keys and its styled buttons.
        rows = { debuffs = { styled = {} }, buffs = { styled = {} } },
        -- Rows with nothing in them (see CheckEmpty).
        empty = { debuffs = false, buffs = false },
        samples = { debuffs = {}, buffs = {} },
    }, Auras)
    local watcher = CreateFrame("Frame")
    watcher:RegisterUnitEvent("UNIT_AURA", owner.unit)
    watcher:RegisterEvent(owner.changeEvent)
    watcher:SetScript("OnEvent", function()
        if ns.db then a:CheckEmpty() end
    end)
    return a
end

------------------------------------------------------------------------------
-- Where the rows go
------------------------------------------------------------------------------

-- How far below the health bar the auras start: clear of the classic look's stone border, of a
-- power bar hanging under the bar, and of the cast bar and its spell name when that sits below
-- the bar too.
function Auras:Top()
    local db = ns.db
    local y = (db.style == "classic" and -10 or -6) - self.owner:PowerDrop()
    if self.owner:Has("cast") and db.cast.position == "below" then
        y = y - (db.cast.gap + (db.style == "classic" and 10 or 2) + db.cast.height + db.text.size + 6)
    end
    return y
end

-- A row with nothing in it closes up (auras.fold), so the rows below move up, and opens again
-- when something lands. How many auras there are can be secret, but whether there are any isn't:
-- the first one's data comes back, or nothing does. Not while unlocked: the samples fill them.
local function Filter(row)
    if row == "buffs" then return "HELPFUL" end
    return ns.db.auras.debuffs.mode == "mine" and "HARMFUL|PLAYER" or "HARMFUL"
end

function Auras:HasAny(row)
    if not UnitExists(self.unit) then return false end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, self.unit, 1, Filter(row))
    -- Can't tell: keep the row open.
    if not ok or FrogLib.issecret(aura) then return true end
    return aura ~= nil
end

function Auras:Shown(row)
    local all = ns.db.auras
    if not (self.owner:Has("auras") and all[row].enabled) then return false end
    return not ns.db.locked or not (all.fold and self.empty[row])
end

-- After a change of unit or of its auras: lays the rows out again if one has opened or closed.
function Auras:CheckEmpty()
    if not self.owner:Enabled() then return end
    local changed = false
    for row in pairs(self.empty) do
        local now = not self:HasAny(row)
        if now ~= self.empty[row] then
            self.empty[row] = now
            changed = true
        end
    end
    if changed and ns.db.auras.fold and self.owner.frame then self.owner:Apply() end
end

local function Height(row)
    local cfg = ns.db.auras[row]
    return cfg.size + (cfg.showTimer and TIMER_HEIGHT or 0)
end

local function Order()
    if ns.db.auras.order == "buffs" then return { "buffs", "debuffs" } end
    return { "debuffs", "buffs" }
end

-- Where `row` starts, below the health bar: under the rows above it.
function Auras:RowTop(row)
    local y = self:Top()
    for _, other in ipairs(Order()) do
        if other == row then return y end
        if self:Shown(other) then y = y - Height(other) - ns.db.auras.rowGap end
    end
    return y
end

-- Where the last shown row ends: a cast bar set "under the auras" goes below it.
function Auras:Bottom()
    local y, any = self:Top(), false
    for _, row in ipairs(Order()) do
        if self:Shown(row) then
            y = self:RowTop(row) - Height(row)
            any = true
        end
    end
    return any and y or self:Top() + 6
end

------------------------------------------------------------------------------
-- Building and applying
------------------------------------------------------------------------------

function Auras:Signature(row)
    local cfg = ns.db.auras[row]
    return (cfg.mode or "") .. "|" .. cfg.max .. "|" .. self:RowTop(row) .. "|" .. tostring(ns.db.auras.rounded)
end

function Auras:Build(row, parent, anchor)
    local r, all = self.rows[row], ns.db.auras
    local cfg = all[row]
    A.Release(r.container)
    r.container = nil
    local c = A.NewContainer(parent)
    if not c then return end

    c:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, self:RowTop(row))
    A.Flow(c, "TOPLEFT", "RIGHT", "DOWN")

    wipe(r.styled)
    r.keys = {}
    local layout = Layout(cfg, all.spacing)
    local function add(key, filter, harmful)
        local ok2, err = pcall(c.AddAuraGroup, c, key, filter, {
            maxFrameCount = cfg.max, sortMethod = SORT, sortDirection = SORT_DIR,
            initializeFrame = MakeInit(r.styled, row, harmful), layout = layout,
        })
        if ok2 then r.keys[#r.keys + 1] = key else ns.Print("Couldn't set up status effects:", err) end
    end
    if row == "debuffs" then
        -- Yours first, then everyone else's.
        add("mine", "HARMFUL|PLAYER", true)
        if cfg.mode == "all" then add("others", "HARMFUL|!PLAYER", true) end
    else
        add("buffs", "HELPFUL", false)
    end
    c:SetUnit(self.unit)
    c:UpdateAllAuras()
    r.container = c
    r.signature = self:Signature(row)
end

function Auras:Apply(parent, anchor)
    local all = ns.db.auras
    -- A bar that's switched off (the focus's) doesn't build its rows until it's switched on.
    local enabled = self.owner:Enabled()
    for row, r in pairs(self.rows) do
        -- Where it sits is part of what it's built with: moving it means building it again.
        if enabled and (not r.container or r.signature ~= self:Signature(row)) then self:Build(row, parent, anchor) end
        local c = r.container
        if c then
            local layout = Layout(all[row], all.spacing)
            for _, key in ipairs(r.keys) do pcall(c.SetAuraGroupLayout, c, key, layout) end
            A.SetLineSize(c, self.owner:Own().width + 0.4)
            c:SetShown(self:Shown(row))
            for _, d in ipairs(r.styled) do pcall(StyleButton, d) end
        end
    end
end

------------------------------------------------------------------------------
-- While unlocked: pretend auras in each row where the real ones go (the real ones hidden), so
-- the layout can be judged without a unit that has any.
------------------------------------------------------------------------------

local SAMPLES = {
    debuffs = {
        { icon = "Interface\\Icons\\Ability_Warrior_Sunder", time = "24s", stack = "3" },
        { icon = "Interface\\Icons\\Ability_Gouge", time = "12s" },
        { icon = "Interface\\Icons\\Ability_Warrior_WarCry", time = "18s" },
        { icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", time = "6s" },
    },
    buffs = {
        { icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", time = "25s" },
        { icon = "Interface\\Icons\\Spell_Nature_Rejuvenation", time = "1m" },
        { icon = "Interface\\Icons\\Spell_Holy_WordFortitude", time = "28m" },
    },
}

function Auras:Sample(parent, row, i)
    local s = self.samples[row][i]
    -- A sample's shape is fixed when it's made, like a real icon's: remade if the shape changed.
    if s and s.rounded == ns.db.auras.rounded then return s end
    if s then s:Hide() end
    s = CreateFrame("Frame", nil, parent)
    s.border = s:CreateTexture(nil, "BACKGROUND")
    s.border:SetAllPoints()
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Shape(s.icon, s.border, s)
    s.rounded = ns.db.auras.rounded
    s.stack = s:CreateFontString(nil, "OVERLAY")
    s.stack:SetPoint("BOTTOMRIGHT", -1, 1)
    s.duration = s:CreateFontString(nil, "OVERLAY")
    s.duration:SetPoint("TOP", s, "BOTTOM", 0, -1)
    self.samples[row][i] = s
    return s
end

function Auras:Preview(parent, anchor, on)
    local all, t = ns.db.auras, ns.db.text
    for row, r in pairs(self.rows) do
        if r.container then r.container:SetShown(self:Shown(row) and not on) end
        local cfg = all[row]
        local show = on and self:Shown(row)
        local size = cfg.size
        local font, fontSize = all.font or t.font, math.max(9, math.floor(size * 0.46))
        for i, d in ipairs(SAMPLES[row]) do
            local s = self:Sample(parent, row, i)
            if show then
                s:SetSize(size, size)
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (i - 1) * (size + all.spacing), self:RowTop(row))
                s.icon:SetTexture(d.icon)
                if row == "debuffs" then
                    s.border:SetColorTexture(0.8, 0.1, 0.1, 1)
                else
                    s.border:SetColorTexture(0, 0, 0, 1)
                end
                ns.Media:SetFont(s.stack, font, fontSize, t.outline)
                ns.Media:SetFont(s.duration, font, fontSize, t.outline)
                s.stack:SetText(d.stack or "")
                s.duration:SetText(cfg.showTimer and d.time or "")
            end
            s:SetShown(show)
        end
    end
end

-- The containers are bound to a unit token ("target", "focus"); a new unit needs a fresh parse.
function Auras:UnitChanged()
    for _, r in pairs(self.rows) do
        if r.container then pcall(r.container.UpdateAllAuras, r.container) end
    end
end
