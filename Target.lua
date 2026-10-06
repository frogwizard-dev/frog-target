local ADDON, ns = ...

-- The bar for one unit. The target's (ns.Target) and the focus's (ns.Focus) are both made here,
-- from the same code: each keeps its own place, scale, width and switches (Bar:Own, Bar:Has),
-- and shares the look, the text, the icons and the layout of casts, auras and the power bar.
local Bar = {}
Bar.__index = Bar

local issecret, Safe = FrogLib.issecret, FrogLib.Safe
-- Reading casts and when the cast bar shows (FrogLib.Cast), the curve an empty power bar fades
-- by (FrogLib.Curve), the colours (FrogLib.Color), the icons by the name (FrogLib.Icons) and the
-- click buttons (FrogLib.Secure) are shared with Frog Wizard's other bars.
local Cast, Curve, Color, Icons = FrogLib.Cast, FrogLib.Curve, FrogLib.Color, FrogLib.Icons

-- What tells the two apart: frame and button names, and the event for a new unit.
local UNITS = {
    target = { frame = "FrogTargetFrame", click = "FrogTargetClick", totClick = "FrogTargetToTClick",
        event = "PLAYER_TARGET_CHANGED", fake = "Striking Dummy" },
    focus = { frame = "FrogTargetFocusFrame", click = "FrogTargetFocusClick", totClick = "FrogTargetFocusToTClick",
        event = "PLAYER_FOCUS_CHANGED", fake = "Training Dummy" },
}

-- Shown while unlocked with nothing targeted, so there's something to drag and style.
local FAKE_TOT = { name = "You", level = "70", value = 100, max = 100, percent = 100 }

local POWER_EVENTS = { UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true }

-- "reaction": tapped grey, players in their class colour, then hostile red / neutral yellow /
-- friendly green; `color` when the game won't say. "xiv": FFXIV's (FrogLib.Color.XIV).
local REACTION = {
    tapped = { r = 0.55, g = 0.55, b = 0.55 }, class = true,
    hostile = { r = 0.90, g = 0.32, b = 0.25 }, neutral = { r = 0.95, g = 0.85, b = 0.35 },
    friendly = { r = 0.45, g = 0.85, b = 0.40 },
}

local function BarColor(unit)
    local db = ns.db
    if unit and db.colorMode == "xiv" then return Color.XIVUnit(unit) end
    if unit and db.colorMode == "reaction" then
        local r, g, b = Color.Unit(unit, REACTION)
        if r then return r, g, b end
    end
    return db.color.r, db.color.g, db.color.b
end

-- Text in a light version of the bar's colour, with a dark outline so it lifts off the world.
local function TintText(fs, r, g, b)
    if ns.db.text.tinted then
        fs:SetTextColor(Color.Lighten(r, g, b, 0.55))
    else
        fs:SetTextColor(1, 1, 1)
    end
end

------------------------------------------------------------------------------
-- Icons beside the name: raid marker, leader/assistant, group role, PvP, quest mob. Each is
-- FrogLib.Icons' (SHOW for a unit, PREVIEW for the unlocked sample); the raid marker is a
-- FontString, as which mark it is can be secret.
------------------------------------------------------------------------------

local ICON_ORDER = { "raid", "leader", "role", "pvp", "quest" } -- nearest the name first

local function Text(parent)
    -- A default font up front: SetText errors on a FontString with none, and the configured
    -- font is only applied later in Apply.
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    return fs
end

------------------------------------------------------------------------------
-- The two bars, and what's theirs
------------------------------------------------------------------------------

local function NewBar(unit)
    local u = UNITS[unit]
    local fake = { name = u.fake, level = "70", value = 76, max = 100, percent = 76, shield = 12 }
    return setmetatable({
        unit = unit,
        names = u,
        changeEvent = u.event,
        fake = fake,
        -- The power bar's sample: its words, plus the name and level.
        fakePower = { name = fake.name, level = fake.level, value = 62, max = 100, percent = 62 },
    }, Bar)
end

ns.Target = NewBar("target")
ns.Focus = NewBar("focus")
ns.Bars = { ns.Target, ns.Focus }

-- This bar's own settings: the target's are at the top of the saved settings, where 0.1 kept
-- them; the focus's are under `focus`.
function Bar:Own()
    if self.unit == "focus" then return ns.db.focus end
    return ns.db
end

-- Whether the focus bar is switched on (the target's always is).
function Bar:Enabled()
    if self.unit == "focus" then return ns.db.focus.enabled end
    return true
end

-- Whether this bar shows a part: "cast", "auras", "power" or "tot" (its unit's target). The
-- target's switches live with each part's settings; the focus's in its own.
function Bar:Has(part)
    if self.unit == "focus" then return ns.db.focus[part] and true or false end
    return ns.db[part].enabled
end

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------

function Bar:Init()
    local unit = self.unit
    local f = CreateFrame("Frame", self.names.frame, UIParent)
    f:SetHeight(26)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    -- Dragged while unlocked, centred exactly when let go near the middle of the screen; the
    -- tint, shown only then, marks it (FrogLib's Mover.lua and Grid.lua).
    FrogLib.Mover.Make(f, { save = function(point) self:Own().point = point end, grid = true, tint = 4 })
    self.frame = f

    local g = ns.CreateGauge(f)
    g.bar:SetPoint("BOTTOMLEFT")
    g.bar:SetPoint("BOTTOMRIGHT")
    g:EnableAbsorb()
    self.gauge = g

    self.left = Text(f)
    self.left:SetPoint("BOTTOMLEFT", g.bar, "TOPLEFT", 1, 2)
    self.left:SetJustifyH("LEFT")
    self.right = Text(f)
    self.right:SetPoint("BOTTOMRIGHT", g.bar, "TOPRIGHT", -1, 2)
    self.right:SetJustifyH("RIGHT")
    self.left:SetWordWrap(false)

    self:BuildPower()
    self:BuildCombo()
    self:BuildCast()
    self:BuildToT()
    self.icons = {}
    for _, key in ipairs(ICON_ORDER) do
        self.icons[key] = key == "raid" and Text(f) or f:CreateTexture(nil, "OVERLAY")
    end
    self.auras = ns.NewAuras(self)

    f:RegisterEvent(self.changeEvent)
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    for _, event in ipairs({ "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED" }) do
        pcall(f.RegisterEvent, f, event)
    end
    pcall(f.RegisterUnitEvent, f, "UNIT_CLASSIFICATION_CHANGED", unit)
    f:RegisterUnitEvent("UNIT_HEALTH", unit)
    f:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
    f:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit)
    f:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
    f:RegisterUnitEvent("UNIT_LEVEL", unit)
    f:RegisterUnitEvent("UNIT_FACTION", unit)
    f:RegisterUnitEvent("UNIT_FLAGS", unit) -- entering/leaving combat recolours the bar
    for event in pairs(POWER_EVENTS) do
        pcall(f.RegisterUnitEvent, f, event, unit)
    end
    for _, event in ipairs(Cast.EVENTS) do
        pcall(f.RegisterUnitEvent, f, event, unit)
    end
    f:SetScript("OnEvent", function(_, event)
        if event == self.changeEvent then
            self:Update(true)
            self.auras:UnitChanged()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if self.clicksPending then self:SetupClicks() end
        elseif event:find("^UNIT_SPELLCAST") then
            self:UpdateCast(event)
        elseif POWER_EVENTS[event] then
            self:UpdatePower(false)
            self:UpdatePowerWords()
        else
            self:Update(false)
        end
    end)

    -- A unit's target (target of target) has no events of its own, so poll it a few times a second.
    local elapsed = 0
    f:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed > 0.2 then
            elapsed = 0
            self:UpdateToT()
        end
    end)

    self:Apply()
end

-- The power bar: a thinner gauge under the health bar, or floating over its bottom edge. It
-- sits on a frame of its own a few levels up, so a floating one is drawn over the health bar
-- (its absorb and its border too); its text on another above its own border.
function Bar:BuildPower()
    local holder = CreateFrame("Frame", nil, self.frame)
    holder:SetAllPoints()
    holder:SetFrameLevel(self.gauge.bar:GetFrameLevel() + 5)
    local p = ns.CreateGauge(holder)
    local top = CreateFrame("Frame", nil, p.bar)
    top:SetAllPoints()
    top:SetFrameLevel(p.bar:GetFrameLevel() + 6)
    p.text = Text(top)
    p.text:SetPoint("CENTER", p.bar, "CENTER", 0, 0)
    p.bar:Hide()
    self.power = p
end

-- Your combo points on the target bar: a row of small bars in the look, from FrogLib's
-- Combo.lua (only for a character that has them).
function Bar:BuildCombo()
    if self.unit ~= "target" or not FrogLib.Combo.Has() then return end
    self.combo = FrogLib.Combo.NewRow(self.frame, function(_, holder)
        local g = ns.CreateGauge(holder)
        return g, g.bar
    end)
    FrogLib.Combo.Watch(function() self:UpdateCombo() end, function() self:ApplyCombo() end)
end

-- FFXIV shows an enemy's cast as a glowing white-gold line floating over the right half of
-- the bar, with the spell name hanging underneath it.
function Bar:BuildCast()
    local g = ns.CreateGauge(self.frame)
    g:SetColor(1, 0.72, 0.30)
    g:SetSpark(true)
    local c = g.bar
    c.gauge = g
    c.label = Text(c)
    c.label:SetPoint("TOPRIGHT", c, "BOTTOMRIGHT", 0, -3)
    c.label:SetJustifyH("RIGHT")
    -- Remaining time, to the left of the cast line. The duration can be secret, so it only
    -- goes straight into SetFormattedText.
    c.time = Text(c)
    c.time:SetPoint("RIGHT", c, "LEFT", -8, 0)
    c.time:SetJustifyH("RIGHT")
    -- What's on it, as FrogLib's driver decides.
    c.driver = Cast.NewDriver({
        show = function(info)
            Cast.Fill(c, info)
            c.label:SetText(info.text)
            if Cast.Locked(info) then
                g:SetColor(0.6, 0.6, 0.6)
            else
                g:SetColor(1, 0.72, 0.3)
            end
            c:Show()
        end,
        -- Held briefly so an interrupt is visible, as FFXIV does.
        hold = function(event)
            c:SetMinMaxValues(0, 1)
            c:SetValue(1)
            g:SetColor(0.85, 0.2, 0.15)
            c.label:SetText(event == "UNIT_SPELLCAST_FAILED" and FAILED or INTERRUPTED)
        end,
        -- Unlocked: a sample cast so its place and look can be judged, unless there's a real one.
        sample = function()
            c:SetMinMaxValues(0, 1)
            c:SetValue(0.6)
            g:SetColor(1, 0.72, 0.3)
            c.label:SetText("Shadow Bolt")
            c.time:SetText(ns.db.cast.showTime and "1.4" or "")
            c:Show()
        end,
        hide = function() c:Hide() end,
        refresh = function() self:UpdateCast() end,
    })
    c:SetScript("OnUpdate", function(bar)
        local d = bar.driver
        if d.sample then return end
        if not ns.db.cast.showTime or d.holdUntil then
            bar.time:SetText("")
            return
        end
        Cast.ShowTime(bar, bar.time)
    end)
    c:Hide()
    self.cast = c
end

function Bar:BuildToT()
    -- ">>>" between the bars, as FFXIV links a target to its target.
    self.chevrons = Text(self.frame)
    self.chevrons:SetText(">>>")
    self.chevrons:SetTextColor(1, 0.82, 0, 0.8)

    local t = CreateFrame("Frame", nil, self.frame)
    t.gauge = ns.CreateGauge(t)
    t.name = Text(t)
    t.name:SetPoint("BOTTOMLEFT", t.gauge.bar, "TOPLEFT", 1, 4)
    t.name:SetJustifyH("LEFT")
    t.name:SetWordWrap(false)
    t:Hide()
    self.tot = t
end

------------------------------------------------------------------------------
-- Clicks: left-click targets, right-click opens the unit menu
------------------------------------------------------------------------------

-- The bars themselves are plain frames, so clicks go to secure buttons laid over them and
-- shown by RegisterUnitWatch (FrogLib.Secure's: right-click opens the unit menu). The buttons copy
-- the bar's position rather than anchoring to it: anything a secure frame is anchored to becomes
-- protected too, and the bar couldn't then be shown or hidden in combat (ADDON_ACTION_BLOCKED on
-- FrogTargetFrame:SetShown).
local function ClickButton(name, unit)
    return (FrogLib.Secure.UnitButton(name, unit, { tooltip = true }))
end

-- Secure frames can only be placed and shown out of combat; changes made in combat wait.
function Bar:SetupClicks()
    if InCombatLockdown() then
        self.clicksPending = true
        return
    end
    self.clicksPending = nil
    local db, own = ns.db, self:Own()
    if not self.click then
        self.click = ClickButton(self.names.click, self.unit)
        self.totClick = ClickButton(self.names.totClick, self.unit .. "target")
    end
    -- Off while unlocked, so the bar can be dragged.
    local on = db.clicks and db.locked and self:Enabled()
    local function watch(b, active)
        if active then
            RegisterUnitWatch(b)
        else
            UnregisterUnitWatch(b)
            b:Hide()
        end
    end

    -- Same place, scale and size as the bar frame; the hit rect reaches a little past its
    -- edges so the thin gauge is easy to hit.
    local c = self.click
    c:SetScale(own.scale)
    c:ClearAllPoints()
    c:SetPoint(own.point[1], UIParent, own.point[3], own.point[4], own.point[5])
    c:SetSize(own.width, self.frame:GetHeight())
    c:SetHitRectInsets(-2, -2, -2, -(6 + self:PowerDrop())) -- down over a power bar too
    watch(c, on)

    -- The unit's target: its gauge starts `gap` past the end of the bar. Anchoring one
    -- secure button to the other is fine.
    local t = self.totClick
    t:SetScale(own.scale)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", c, "BOTTOMRIGHT", db.tot.gap, 0)
    t:SetSize(db.tot.width, self.frame:GetHeight())
    t:SetHitRectInsets(-2, -2, -2, -6)
    watch(t, on and self:Has("tot"))
end

------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------

-- Between the health bar and a power bar under it, so their borders just meet: two stone lines
-- (3 each) in the classic look, two Forever frames (2 texels out each), two 1px edges.
function Bar:PowerGap()
    local db = ns.db
    if db.style == "classic" then return 6 end
    local px = FrogLib.Pixel(self.frame)
    if db.style == "forever" then return px * (4 * (db.frameThickness or 1) + 1) end
    return px * 3
end

-- How far the power bar reaches below the health bar. From the settings alone, not from whether
-- the unit has power, so nothing jumps about.
function Bar:PowerReach()
    if not self:Has("power") then return 0 end
    local cfg = ns.db.power
    if cfg.float then return math.max(0, cfg.height / 2 - cfg.offset) end
    return self:PowerGap() + cfg.height
end

-- How far the combo points reach below the power bar (kept out of cat form too, so nothing
-- jumps with every shift).
function Bar:ComboDrop()
    local cfg = ns.db.combo
    if not (self.combo and cfg.enabled) then return 0 end
    return self:PowerGap() + cfg.height
end

-- How far everything under the health bar reaches (the power bar, the combo points), so the
-- auras and a cast bar below clear it.
function Bar:PowerDrop()
    return self:PowerReach() + self:ComboDrop()
end

function Bar:ApplyCombo()
    local row, db = self.combo, ns.db
    if not row then return end
    local cfg = db.combo
    if not (cfg.enabled and row:Refresh(not db.locked)) then
        row.holder:Hide()
        return
    end
    local c, gap = cfg.color, self:PowerGap()
    -- Their borders just meet, as the health and power bars' do, plus any extra room.
    row:Layout(self:Own().width, cfg.height, gap + cfg.spacing, function(g, w, h)
        g:SetHeight(h)
        g:SetTexture(db.texture)
        g.bar:SetWidth(w)
        g:SetColor(c.r, c.g, c.b)
    end)
    row.holder:ClearAllPoints()
    row.holder:SetPoint("TOPLEFT", self.gauge.bar, "BOTTOMLEFT", 0, -(self:PowerReach() + gap))
    self:UpdateCombo()
end

-- The count (a sample while unlocked); it may be secret, so it only goes into the bars.
function Bar:UpdateCombo()
    if self.combo then self.combo:Update(not ns.db.locked, ns.db.combo.hideEmpty) end
end

function Bar:ApplyPower()
    local db, cfg, p = ns.db, ns.db.power, self.power
    p:SetHeight(cfg.height)
    p:SetTexture(db.texture)
    p.bar:ClearAllPoints()
    if cfg.float then
        -- Centred on the health bar's bottom edge: half over the bar, half below it. Its empty
        -- part darker than usual, so the health bar under it doesn't show through.
        p:SetTrackAlpha(0.85)
        p.bar:SetPoint("CENTER", self.gauge.bar, "BOTTOM", cfg.x, cfg.offset)
        p.bar:SetWidth(self:Own().width * cfg.width / 100)
    else
        p:SetTrackAlpha(nil)
        local gap = self:PowerGap()
        p.bar:SetPoint("TOPLEFT", self.gauge.bar, "BOTTOMLEFT", 0, -gap)
        p.bar:SetPoint("TOPRIGHT", self.gauge.bar, "BOTTOMRIGHT", 0, -gap)
    end
    ns.Media:SetFont(p.text, db.text.font, cfg.textSize, db.text.outline)
end

function Bar:Apply()
    local db, t, own = ns.db, ns.db.text, self:Own()
    local f = self.frame
    f:SetScale(own.scale)
    f:SetWidth(own.width)
    f:ClearAllPoints()
    f:SetPoint(own.point[1], UIParent, own.point[3], own.point[4], own.point[5])
    f:EnableMouse(not db.locked)
    f.unlockTint:SetShown(not db.locked)
    FrogLib.Grid:SetShown(not db.locked, "FrogTarget")
    if self.unit == "target" then
        -- Combo points are drawn on Blizzard's target frame, so they stay.
        FrogLib.Hider.Set(ADDON, "TargetFrame", db.hideTargetFrame, { keep = { "ComboFrame" } })
    else
        FrogLib.Hider.Set(ADDON, "FocusFrame", own.enabled and own.hideBlizzard)
    end

    self.gauge:SetHeight(db.height)
    self.gauge:SetTexture(db.texture)
    ns.Media:SetFont(self.left, t.font, t.size, t.outline)
    ns.Media:SetFont(self.right, t.font, t.size, t.outline)
    self.left:SetWidth(own.width * 0.72) -- long names truncate before reaching the right text
    -- The classic look's stone border takes a few pixels round each bar; the text clears it.
    local lift = db.style == "classic" and 6 or 2
    self.left:ClearAllPoints()
    self.left:SetPoint("BOTTOMLEFT", self.gauge.bar, "TOPLEFT", 1, lift)
    self.right:ClearAllPoints()
    self.right:SetPoint("BOTTOMRIGHT", self.gauge.bar, "TOPRIGHT", -1, lift)

    self:ApplyPower()
    self:ApplyCombo()

    local c = self.cast
    c:ClearAllPoints()
    if db.cast.position == "auras" then
        c:SetPoint("TOPRIGHT", self.gauge.bar, "BOTTOMRIGHT", 0, self.auras:Bottom() - db.cast.gap)
    elseif db.cast.position == "below" then
        -- Clear of both bars' stone borders in the classic look, and of a power bar.
        c:SetPoint("TOPRIGHT", self.gauge.bar, "BOTTOMRIGHT", 0,
            -(db.cast.gap + (db.style == "classic" and 10 or 2) + self:PowerDrop()))
    else
        c:SetPoint("BOTTOMRIGHT", self.gauge.bar, "TOPRIGHT", 0, db.cast.offset)
    end
    c:SetWidth(db.cast.width)
    ns.Media:SetFont(c.time, t.font, t.size, t.outline)
    c.time:SetTextColor(1, 0.95, 0.85)
    c.gauge:SetHeight(db.cast.height)
    c.gauge:SetTexture(db.texture)
    ns.Media:SetFont(c.label, t.font, t.size + 2, t.outline)
    c.label:ClearAllPoints()
    c.label:SetPoint("TOPRIGHT", c, "BOTTOMRIGHT", 0, -(lift + 1))
    c.time:ClearAllPoints()
    c.time:SetPoint("RIGHT", c, "LEFT", -(lift + 6), 0)
    c.label:SetTextColor(1, 0.95, 0.85)

    local tot = self.tot
    tot.gauge:SetHeight(db.height)
    tot.gauge:SetTexture(db.texture)
    tot.gauge.bar:ClearAllPoints()
    tot.gauge.bar:SetPoint("BOTTOMLEFT", self.gauge.bar, "BOTTOMRIGHT", db.tot.gap, 0)
    tot.gauge.bar:SetWidth(db.tot.width)
    tot.name:SetWidth(db.tot.width)
    tot.name:ClearAllPoints()
    tot.name:SetPoint("BOTTOMLEFT", tot.gauge.bar, "TOPLEFT", 1, lift + 2)
    ns.Media:SetFont(tot.name, t.font, t.size - 1, t.outline)
    ns.Media:SetFont(self.chevrons, t.font, math.max(8, t.size - 3), t.outline)
    self.chevrons:ClearAllPoints()
    self.chevrons:SetPoint("CENTER", self.gauge.bar, "RIGHT", db.tot.gap / 2, 0)

    self.auras:Apply(f, self.gauge.bar)
    self.auras:Preview(f, self.gauge.bar, not db.locked)
    self:SetupClicks()
    self:Update(true)
    -- A font file is loaded on first use, and text set in that same moment can render blank;
    -- write the text again once it's in.
    C_Timer.After(0.1, function() self:Update(true) end)
    C_Timer.After(1, function() self:Update(true) end)
end

------------------------------------------------------------------------------
-- Updates
------------------------------------------------------------------------------

function Bar:Update(instant)
    local db = ns.db
    local exists = self:Enabled() and UnitExists(self.unit)
    local preview = self:Enabled() and not exists and not db.locked
    self.frame:SetShown(exists or preview)
    if not exists and not preview then return end

    local unit = exists and self.unit or nil
    local fake = preview and self.fake
    local g = self.gauge
    if preview then
        g:SetValues(fake.value, fake.max, true)
        g:SetAbsorb(fake.shield, fake.max)
    else
        local max = UnitHealthMax(unit)
        g:SetValues(UnitHealth(unit), max, instant)
        -- The shield total can be secret; it only ever goes into the gauge's status bars.
        g:SetAbsorb((UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)) or 0, max)
    end
    g:ShowAbsorb(db.absorb)
    local r, g, b = BarColor(unit)
    self.gauge:SetColor(r, g, b)
    ns.SetUnitText(self.left, db.text.left, unit, fake)
    ns.SetUnitText(self.right, db.text.right, unit, fake)
    TintText(self.left, r, g, b)
    TintText(self.right, r, g, b)
    self:UpdateIcons(unit)
    self:UpdatePower(instant)

    if instant then
        self:UpdateCast()
        self:UpdateToT()
    end
end

-- The texts above the bar again when the power changes, if they show any of it.
function Bar:UpdatePowerWords()
    if not (self:Enabled() and UnitExists(self.unit)) then return end
    local text = ns.db.text
    if FrogLib.Unit.UsesPower(text.left) then ns.SetUnitText(self.left, text.left, self.unit) end
    if FrogLib.Unit.UsesPower(text.right) then ns.SetUnitText(self.right, text.right, self.unit) end
end

-- An empty power bar fades out (power.hideEmpty): a unit that's generated nothing and spent
-- nothing has no use for it. When the power can be read, a new unit at 0 has it gone at once,
-- and one that drops to 0 keeps it for EMPTY_WAIT seconds first (rage ebbing between swings).
-- In combat the power can be secret, so a curve over its percent becomes the bar's opacity
-- instead, engine-side: 0 when empty, 1 otherwise.
local EMPTY_WAIT = 3

function Bar:EmptyAlpha(unit, instant)
    if not (unit and ns.db.power.hideEmpty) then return 1 end
    local power = UnitPower(unit)
    if not issecret(power) then
        if power > 0 then
            self.emptySince = nil
            return 1
        end
        local now = GetTime()
        if instant then self.emptySince = now - EMPTY_WAIT end
        self.emptySince = self.emptySince or now
        local left = EMPTY_WAIT - (now - self.emptySince)
        if left <= 0 then return 0 end
        if not self.emptyTimer then
            self.emptyTimer = true
            C_Timer.After(left + 0.05, function()
                self.emptyTimer = nil
                self:UpdatePower(false)
            end)
        end
        return 1
    end
    local a = Curve.Power(unit, Curve.Empty())
    if issecret(a) or a ~= nil then return a end
    return 1
end

-- Values may be secret: they only go into the gauge and SetFormattedText. A unit with no power
-- at all (a critter) shows none, when that much can be told.
function Bar:UpdatePower(instant)
    local p, cfg = self.power, ns.db.power
    local unit = self:Enabled() and UnitExists(self.unit) and self.unit or nil
    local show = self:Has("power") and (unit ~= nil or not ns.db.locked)
    if show and unit then
        local max = UnitPowerMax(unit)
        if Safe(max) == 0 then
            show = false
        else
            p:SetValues(UnitPower(unit), max, instant)
        end
    elseif show then
        p:SetValues(self.fakePower.value, self.fakePower.max, true) -- unlocked: a sample
    end
    p.bar:SetShown(show)
    if not show then return end
    p.bar:SetAlpha(self:EmptyAlpha(unit, instant))
    local r, g, b = Color.Power(unit)
    p:SetColor(r, g, b)
    ns.SetUnitText(p.text, cfg.text, unit, not unit and self.fakePower, true)
    TintText(p.text, r, g, b)
end

-- Where the icon row starts, and which way it grows:
-- { point on first icon, relative-to key, its point, base x, base y, step direction }.
local ICON_ANCHORS = {
    left = { "RIGHT", "left", "LEFT", -4, 0, -1 },       -- beside the name, growing left
    right = { "LEFT", "bar", "RIGHT", 6, 0, 1 },         -- past the end of the bar, growing right
    above = { "BOTTOMLEFT", "left", "TOPLEFT", 0, 4, 1 }, -- above the name, growing right
}

-- Shown icons line up from the chosen anchor, offset by the x/y setting. unit nil = preview.
function Bar:UpdateIcons(unit)
    local cfg = ns.db.icons
    local a = ICON_ANCHORS[cfg.anchor] or ICON_ANCHORS.left
    local relative = a[2] == "bar" and self.gauge.bar or self.left
    local prev
    for _, key in ipairs(ICON_ORDER) do
        local tex = self.icons[key]
        local shown = false
        if cfg.enabled and cfg[key] then
            if unit then
                shown = Icons.SHOW[key](tex, unit, cfg.size)
            elseif Icons.PREVIEW[key] then
                shown = Icons.PREVIEW[key](tex, cfg.size)
            end
        end
        tex:SetShown(shown)
        if shown then
            if tex:GetObjectType() == "Texture" then tex:SetSize(cfg.size, cfg.size) end
            tex:ClearAllPoints()
            if prev then
                if a[6] < 0 then
                    tex:SetPoint("RIGHT", prev, "LEFT", -2, 0)
                else
                    tex:SetPoint("LEFT", prev, "RIGHT", 2, 0)
                end
            else
                tex:SetPoint(a[1], relative, a[3], a[4] + cfg.x, a[5] + cfg.y)
            end
            prev = tex
        end
    end
end

function Bar:UpdateCast(event)
    local c, unit = self.cast, self.unit
    if not self:Has("cast") then
        c:Hide()
        return
    end
    local exists = UnitExists(unit)
    c.driver:Update((issecret(exists) or exists) and unit or nil, event, not ns.db.locked)
end

function Bar:UpdateToT()
    local tot, cfg = self.tot, ns.db.tot
    local other = self.unit .. "target"
    local show, r, g, b
    if not self:Has("tot") then
        show = false
    elseif not UnitExists(self.unit) then
        show = not ns.db.locked
        if show then
            tot.gauge:SetValues(FAKE_TOT.value, FAKE_TOT.max, true)
            if ns.db.colorMode == "xiv" then
                local c = Color.XIV.friend
                r, g, b = c.r, c.g, c.b
            else
                r, g, b = BarColor(nil)
            end
            ns.SetUnitText(tot.name, cfg.template, nil, FAKE_TOT)
        end
    elseif UnitExists(other) then
        show = true
        tot.gauge:SetValues(UnitHealth(other), UnitHealthMax(other))
        r, g, b = BarColor(other)
        ns.SetUnitText(tot.name, cfg.template, other)
    end
    if show then
        tot.gauge:SetColor(r, g, b)
        TintText(tot.name, r, g, b)
    end
    tot:SetShown(show)
    self.chevrons:SetShown(show)
end
