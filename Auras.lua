local _, ns = ...
local Auras = {}
Auras.__index = Auras

-- Status effects under a unit's bar in two rows with their own settings: debuffs (yours, then
-- others') and buffs, either on top. Each row is one of 12.1's AuraContainers, which pick and draw
-- the auras where addons can't read them; how many there are can be secret, so each row gets room
-- for one line. Each bar has its own set (ns.NewAuras(bar)); the row settings are shared.

local SORT = AuraContainerSortMethod and AuraContainerSortMethod.Default
local SORT_DIR = AuraContainerSortDirection and AuraContainerSortDirection.Normal
local TIMER_HEIGHT = 12 -- the timer printed under each icon

local AuraKit = FrogLib.Auras -- the rows' building blocks (FrogLib's Auras.lua)

-- Rounded icons, the shape of FrogUI's action bar buttons, the cooldown sweep following the
-- corners; square: a 1px border.
local function Shape(icon, border, button, cooldown)
    AuraKit.Shape(icon, border, button, cooldown, ns.db.auras.rounded)
end

-- The engine makes the buttons 0x0, so they're sized here.
local function StyleButton(parts)
    local all, text = ns.db.auras, ns.db.text
    local settings = all[parts.row]
    if parts.size ~= settings.size and pcall(parts.button.SetSize, parts.button, settings.size, settings.size) then
        parts.size = settings.size
    end
    local font, size = all.font or text.font, math.max(9, math.floor(settings.size * 0.46))
    ns.Media:SetFont(parts.stack, font, size, text.outline)
    ns.Media:SetFont(parts.duration, font, size, text.outline)
    parts.duration:SetShown(settings.showTimer)
end

-- styled: the row's list of styled buttons, restyled when the settings change.
local function MakeInit(styled, row, harmful)
    return function(button)
        -- The timer goes under the icon rather than on it.
        local parts = AuraKit.InitButton(button, { border = harmful and { 0.75, 0.12, 0.08 } or nil,
            rounded = ns.db.auras.rounded, style = function(new)
                new.row = row
                StyleButton(new)
            end })
        table.insert(styled, parts)
    end
end

local function Layout(settings, spacing)
    -- Extra line spacing leaves room for the timer printed under each icon.
    return { elementWidth = settings.size, elementHeight = settings.size, elementSpacing = spacing,
        lineSpacing = spacing + (settings.showTimer and TIMER_HEIGHT or 0) }
end

------------------------------------------------------------------------------
-- A bar's set of rows
------------------------------------------------------------------------------

-- owner: the bar they hang under (Target.lua), for its unit, its switches and its width.
function ns.NewAuras(owner)
    local auras = setmetatable({
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
        if ns.db then auras:CheckEmpty() end
    end)
    return auras
end

------------------------------------------------------------------------------
-- Where the rows go
------------------------------------------------------------------------------

-- How far below the health bar the auras start: clear of the classic stone border, a power bar
-- hanging under the bar, and the cast bar and its spell name when that sits below the bar too.
function Auras:Top()
    local db = ns.db
    local y = (db.style == "classic" and -10 or -6) - self.owner:PowerDrop()
    if self.owner:Has("cast") and db.cast.position == "below" then
        y = y - (db.cast.gap + (db.style == "classic" and 10 or 2) + db.cast.height + db.text.size + 6)
    end
    return y
end

local function Filter(row)
    if row == "buffs" then return "HELPFUL" end
    return ns.db.auras.debuffs.mode == "mine" and "HARMFUL|PLAYER" or "HARMFUL"
end

-- How many auras there are can be secret, but whether there are any isn't: the first one's data
-- comes back, or nothing does.
function Auras:HasAny(row)
    if not UnitExists(self.unit) then return false end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, self.unit, 1, Filter(row))
    -- Can't tell: keep the row open.
    if not ok or FrogLib.issecret(aura) then return true end
    return aura ~= nil
end

-- A row with nothing in it closes up (auras.fold), so the rows below move up; not while unlocked,
-- when the samples fill them.
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
    local settings = ns.db.auras[row]
    return settings.size + (settings.showTimer and TIMER_HEIGHT or 0)
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
    local settings = ns.db.auras[row]
    return (settings.mode or "") .. "|" .. settings.max .. "|" .. self:RowTop(row) .. "|" .. tostring(ns.db.auras.rounded)
end

-- The container is placed before it's set up, and nothing is anchored to it (both lessons from
-- PersonalResourceTweaks).
function Auras:Build(row, parent, anchor)
    local built, all = self.rows[row], ns.db.auras
    local settings = all[row]
    AuraKit.Release(built.container)
    built.container = nil
    local container = AuraKit.NewContainer(parent)
    if not container then return end

    container:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, self:RowTop(row))
    AuraKit.Flow(container, "TOPLEFT", "RIGHT", "DOWN")

    wipe(built.styled)
    built.keys = {}
    local layout = Layout(settings, all.spacing)
    local function Add(key, filter, harmful)
        local ok, message = pcall(container.AddAuraGroup, container, key, filter, {
            maxFrameCount = settings.max, sortMethod = SORT, sortDirection = SORT_DIR,
            initializeFrame = MakeInit(built.styled, row, harmful), layout = layout,
        })
        if ok then built.keys[#built.keys + 1] = key else ns.Print("Couldn't set up status effects:", message) end
    end
    if row == "debuffs" then
        -- Yours first, then everyone else's.
        Add("mine", "HARMFUL|PLAYER", true)
        if settings.mode == "all" then Add("others", "HARMFUL|!PLAYER", true) end
    else
        Add("buffs", "HELPFUL", false)
    end
    container:SetUnit(self.unit)
    container:UpdateAllAuras()
    built.container = container
    built.signature = self:Signature(row)
end

function Auras:Apply(parent, anchor)
    local all = ns.db.auras
    -- A bar that's switched off (the focus's) doesn't build its rows until it's switched on.
    local enabled = self.owner:Enabled()
    for row, built in pairs(self.rows) do
        -- Where it sits is part of what it's built with: moving it means building it again.
        if enabled and (not built.container or built.signature ~= self:Signature(row)) then self:Build(row, parent, anchor) end
        local container = built.container
        if container then
            local layout = Layout(all[row], all.spacing)
            for _, key in ipairs(built.keys) do pcall(container.SetAuraGroupLayout, container, key, layout) end
            AuraKit.SetLineSize(container, self.owner:Own().width + 0.4)
            container:SetShown(self:Shown(row))
            for _, parts in ipairs(built.styled) do pcall(StyleButton, parts) end
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

function Auras:Sample(parent, row, index)
    local sample = self.samples[row][index]
    -- A sample's shape is fixed when it's made, like a real icon's: remade if the shape changed.
    if sample and sample.rounded == ns.db.auras.rounded then return sample end
    if sample then sample:Hide() end
    sample = CreateFrame("Frame", nil, parent)
    sample.border = sample:CreateTexture(nil, "BACKGROUND")
    sample.border:SetAllPoints()
    sample.icon = sample:CreateTexture(nil, "ARTWORK")
    sample.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Shape(sample.icon, sample.border, sample)
    sample.rounded = ns.db.auras.rounded
    sample.stack = sample:CreateFontString(nil, "OVERLAY")
    sample.stack:SetPoint("BOTTOMRIGHT", -1, 1)
    sample.duration = sample:CreateFontString(nil, "OVERLAY")
    sample.duration:SetPoint("TOP", sample, "BOTTOM", 0, -1)
    self.samples[row][index] = sample
    return sample
end

function Auras:Preview(parent, anchor, on)
    local all, text = ns.db.auras, ns.db.text
    for row, built in pairs(self.rows) do
        if built.container then built.container:SetShown(self:Shown(row) and not on) end
        local settings = all[row]
        local show = on and self:Shown(row)
        local size = settings.size
        local font, fontSize = all.font or text.font, math.max(9, math.floor(size * 0.46))
        for i, example in ipairs(SAMPLES[row]) do
            local sample = self:Sample(parent, row, i)
            if show then
                sample:SetSize(size, size)
                sample:ClearAllPoints()
                sample:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (i - 1) * (size + all.spacing), self:RowTop(row))
                sample.icon:SetTexture(example.icon)
                if row == "debuffs" then
                    sample.border:SetColorTexture(0.8, 0.1, 0.1, 1)
                else
                    sample.border:SetColorTexture(0, 0, 0, 1)
                end
                ns.Media:SetFont(sample.stack, font, fontSize, text.outline)
                ns.Media:SetFont(sample.duration, font, fontSize, text.outline)
                sample.stack:SetText(example.stack or "")
                sample.duration:SetText(settings.showTimer and example.time or "")
            end
            sample:SetShown(show)
        end
    end
end

-- The containers are bound to a unit token ("target", "focus"); a new unit needs a fresh parse.
function Auras:UnitChanged()
    for _, built in pairs(self.rows) do
        if built.container then pcall(built.container.UpdateAllAuras, built.container) end
    end
end
