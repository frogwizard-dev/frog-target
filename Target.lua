local ADDON, ns = ...

-- The bar for one unit. The target's and the focus's are both made here, from the same code: each
-- keeps its own place, scale, width and switches (Bar:Own, Bar:Has), and shares the look, the
-- text, the icons and the layout of casts, auras and the power bar.
local Bar = {}
Bar.__index = Bar

local issecret, Safe = FrogLib.issecret, FrogLib.Safe
-- Shared with Frog Wizard's other bars: casts (FrogLib.Cast), the curve an empty power bar fades by,
-- the colours, the icons by the name, and the click buttons (FrogLib.Secure).
local Cast, Curve, Color, Icons, Secure = FrogLib.Cast, FrogLib.Curve, FrogLib.Color, FrogLib.Icons, FrogLib.Secure
local Text = FrogLib.Text.Shadowed

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
local function TintText(text, r, g, b)
    if ns.db.text.tinted then
        text:SetTextColor(Color.Lighten(r, g, b, 0.55))
    else
        text:SetTextColor(1, 1, 1)
    end
end

------------------------------------------------------------------------------
-- Icons beside the name: raid marker, leader/assistant, group role, PvP, quest mob (FrogLib.Icons';
-- the raid marker is a FontString, as which mark it is can be secret).
------------------------------------------------------------------------------

local ICON_ORDER = { "raid", "leader", "role", "pvp", "quest" } -- nearest the name first

------------------------------------------------------------------------------
-- The two bars, and what's theirs
------------------------------------------------------------------------------

local function NewBar(unit)
    local names = UNITS[unit]
    local fake = { name = names.fake, level = "70", value = 76, max = 100, percent = 76, shield = 12 }
    return setmetatable({
        unit = unit,
        names = names,
        changeEvent = names.event,
        fake = fake,
        -- The power bar's sample: its words, plus the name and level.
        fakePower = { name = fake.name, level = fake.level, value = 62, max = 100, percent = 62 },
    }, Bar)
end

ns.Bars = { NewBar("target"), NewBar("focus") }

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
    local frame = CreateFrame("Frame", self.names.frame, UIParent)
    frame:SetHeight(26)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    -- Dragged while unlocked, centred exactly when let go near the middle of the screen; the
    -- tint, shown only then, marks it (FrogLib's Mover.lua and Grid.lua).
    FrogLib.Mover.Make(frame, { save = function(point) self:Own().point = point end, grid = true, tint = 4 })
    self.frame = frame

    local gauge = ns.CreateGauge(frame)
    gauge.bar:SetPoint("BOTTOMLEFT")
    gauge.bar:SetPoint("BOTTOMRIGHT")
    gauge:EnableAbsorb()
    self.gauge = gauge

    self.left = Text(frame)
    self.left:SetPoint("BOTTOMLEFT", gauge.bar, "TOPLEFT", 1, 2)
    self.left:SetJustifyH("LEFT")
    self.right = Text(frame)
    self.right:SetPoint("BOTTOMRIGHT", gauge.bar, "TOPRIGHT", -1, 2)
    self.right:SetJustifyH("RIGHT")
    self.left:SetWordWrap(false)

    self:BuildPower()
    self:BuildCombo()
    self:BuildCast()
    self:BuildToT()
    self.icons = {}
    for _, key in ipairs(ICON_ORDER) do
        self.icons[key] = key == "raid" and Text(frame) or frame:CreateTexture(nil, "OVERLAY")
    end
    self.auras = ns.NewAuras(self)

    frame:RegisterEvent(self.changeEvent)
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    for _, event in ipairs({ "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    pcall(frame.RegisterUnitEvent, frame, "UNIT_CLASSIFICATION_CHANGED", unit)
    frame:RegisterUnitEvent("UNIT_HEALTH", unit)
    frame:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
    frame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit)
    frame:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
    frame:RegisterUnitEvent("UNIT_LEVEL", unit)
    frame:RegisterUnitEvent("UNIT_FACTION", unit)
    frame:RegisterUnitEvent("UNIT_FLAGS", unit) -- entering/leaving combat recolours the bar
    for event in pairs(POWER_EVENTS) do
        pcall(frame.RegisterUnitEvent, frame, event, unit)
    end
    for _, event in ipairs(Cast.EVENTS) do
        pcall(frame.RegisterUnitEvent, frame, event, unit)
    end
    frame:SetScript("OnEvent", function(_, event, _, _, _, interruptedBy)
        if event == self.changeEvent then
            self:Update(true)
            self.auras:UnitChanged()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if self.clicksPending then self:SetupClicks() end
        elseif event:find("^UNIT_SPELLCAST") then
            self:UpdateCast(event, interruptedBy)
        elseif POWER_EVENTS[event] then
            self:UpdatePower(false)
            self:UpdatePowerWords()
        else
            self:Update(false)
        end
    end)

    -- A unit's target (target of target) has no events of its own, so poll it a few times a second: a new one (or one
    -- that can't be told apart, its GUID secret) drawn in full, and the same one in full once a second, only its
    -- health between.
    local waited, lastGUID, lastFull = 0, nil, 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + elapsed
        if waited <= 0.2 then return end
        waited = 0
        local other = self.unit .. "target"
        local guid, now = UnitGUID(other), GetTime()
        if issecret(guid) or guid == nil or guid ~= lastGUID or now - lastFull >= 1 or not self.tot:IsShown() then
            lastGUID, lastFull = not issecret(guid) and guid or nil, now
            self:UpdateToT()
        else
            self.tot.gauge:SetValues(UnitHealth(other), UnitHealthMax(other))
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
    local power = ns.CreateGauge(holder)
    local top = CreateFrame("Frame", nil, power.bar)
    top:SetAllPoints()
    top:SetFrameLevel(power.bar:GetFrameLevel() + 6)
    power.text = Text(top)
    power.text:SetPoint("CENTER", power.bar, "CENTER", 0, 0)
    power.bar:Hide()
    self.power = power
end

-- Your combo points on the target bar: a row of small bars in the look, from FrogLib's
-- Combo.lua (only for a character that has them).
function Bar:BuildCombo()
    if self.unit ~= "target" or not FrogLib.Combo.Has() then return end
    self.combo = FrogLib.Combo.NewRow(self.frame, function(_, holder)
        local gauge = ns.CreateGauge(holder)
        return gauge, gauge.bar
    end)
    FrogLib.Combo.Watch(function() self:UpdateCombo() end, function() self:ApplyCombo() end)
end

-- FFXIV shows an enemy's cast as a glowing white-gold line floating over the right half of
-- the bar, with the spell name hanging underneath it.
function Bar:BuildCast()
    local gauge = ns.CreateGauge(self.frame)
    gauge:SetColor(1, 0.72, 0.30)
    gauge:SetSpark(true)
    local cast = gauge.bar
    cast.gauge = gauge
    cast.label = Text(cast)
    cast.label:SetPoint("TOPRIGHT", cast, "BOTTOMRIGHT", 0, -3)
    cast.label:SetJustifyH("RIGHT")
    -- Remaining time, to the left of the cast line. The duration can be secret, so it only
    -- goes straight into SetFormattedText.
    cast.time = Text(cast)
    cast.time:SetPoint("RIGHT", cast, "LEFT", -8, 0)
    cast.time:SetJustifyH("RIGHT")
    cast.driver = Cast.NewLine({
        bar = cast, gauge = gauge, label = cast.label, time = cast.time,
        showTime = function() return ns.db.cast.showTime end,
        refresh = function() self:UpdateCast() end,
        sample = { label = "Shadow Bolt", value = 0.6, time = "1.4" },
    })
    cast:Hide()
    self.cast = cast
end

function Bar:BuildToT()
    -- ">>>" between the bars, as FFXIV links a target to its target.
    self.chevrons = Text(self.frame)
    self.chevrons:SetText(">>>")
    self.chevrons:SetTextColor(1, 0.82, 0, 0.8)

    local tot = CreateFrame("Frame", nil, self.frame)
    tot.gauge = ns.CreateGauge(tot)
    tot.name = Text(tot)
    tot.name:SetPoint("BOTTOMLEFT", tot.gauge.bar, "TOPLEFT", 1, 4)
    tot.name:SetJustifyH("LEFT")
    tot.name:SetWordWrap(false)
    tot:Hide()
    self.tot = tot
end

------------------------------------------------------------------------------
-- Clicks: left-click targets, right-click opens the unit menu
------------------------------------------------------------------------------

-- Clicks go to secure buttons over the bars (FrogLib.Secure's), which copy the bar's position: a
-- frame a secure one is anchored to turns protected, and couldn't then be shown or hidden in combat.
local function ClickButton(name, unit)
    return (Secure.UnitButton(name, unit, { tooltip = true }))
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

    -- Same place, scale and size as the bar frame; the hit rect reaches a little past its
    -- edges so the thin gauge is easy to hit.
    local click = self.click
    click:SetScale(own.scale)
    click:ClearAllPoints()
    click:SetPoint(own.point[1], UIParent, own.point[3], own.point[4], own.point[5])
    click:SetSize(own.width, self.frame:GetHeight())
    click:SetHitRectInsets(-2, -2, -2, -(6 + self:PowerDrop())) -- down over a power bar too
    Secure.Watch(click, on)

    -- The unit's target: its gauge starts `gap` past the end of the bar. Anchoring one
    -- secure button to the other is fine.
    local totClick = self.totClick
    totClick:SetScale(own.scale)
    totClick:ClearAllPoints()
    totClick:SetPoint("BOTTOMLEFT", click, "BOTTOMRIGHT", db.tot.gap, 0)
    totClick:SetSize(db.tot.width, self.frame:GetHeight())
    totClick:SetHitRectInsets(-2, -2, -2, -6)
    Secure.Watch(totClick, on and self:Has("tot"))
end

------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------

-- Between the health bar and a power bar under it, so their borders meet: two stone lines (3
-- each) in the classic look, two Forever frames (2 texels out each), two 1px edges.
function Bar:PowerGap()
    local db = ns.db
    if db.style == "classic" then return 6 end
    local pixel = FrogLib.Pixel(self.frame)
    if db.style == "forever" then return pixel * (4 * (db.frameThickness or 1) + 1) end
    return pixel * 3
end

-- How far the power bar reaches below the health bar. From the settings alone, not from whether
-- the unit has power, so nothing jumps about.
function Bar:PowerReach()
    if not self:Has("power") then return 0 end
    local power = ns.db.power
    if power.float then return math.max(0, power.height / 2 - power.offset) end
    return self:PowerGap() + power.height
end

-- How far the combo points reach below the power bar (kept out of cat form too, so nothing
-- jumps with every shift).
function Bar:ComboDrop()
    local combo = ns.db.combo
    if not (self.combo and combo.enabled) then return 0 end
    return self:PowerGap() + combo.height
end

-- How far everything under the health bar reaches (the power bar, the combo points), so the
-- auras and a cast bar below clear it.
function Bar:PowerDrop()
    return self:PowerReach() + self:ComboDrop()
end

function Bar:ApplyCombo()
    local row, db = self.combo, ns.db
    if not row then return end
    local combo = db.combo
    if not (combo.enabled and row:Refresh(not db.locked)) then
        row.holder:Hide()
        return
    end
    local color, gap = combo.color, self:PowerGap()
    -- Their borders meet, as the health and power bars' do, plus any extra room.
    row:Layout(self:Own().width, combo.height, gap + combo.spacing, function(gauge, width, height)
        gauge:SetHeight(height)
        gauge:SetTexture(db.texture)
        gauge.bar:SetWidth(width)
        gauge:SetColor(color.r, color.g, color.b)
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
    local db, settings, power = ns.db, ns.db.power, self.power
    power:SetHeight(settings.height)
    power:SetTexture(db.texture)
    power.bar:ClearAllPoints()
    if settings.float then
        -- Centred on the health bar's bottom edge: half over the bar, half below it. Its empty
        -- part darker than usual, so the health bar under it doesn't show through.
        power:SetTrackAlpha(0.85)
        power.bar:SetPoint("CENTER", self.gauge.bar, "BOTTOM", settings.x, settings.offset)
        power.bar:SetWidth(self:Own().width * settings.width / 100)
    else
        power:SetTrackAlpha(nil)
        local gap = self:PowerGap()
        power.bar:SetPoint("TOPLEFT", self.gauge.bar, "BOTTOMLEFT", 0, -gap)
        power.bar:SetPoint("TOPRIGHT", self.gauge.bar, "BOTTOMRIGHT", 0, -gap)
    end
    ns.Media:SetFont(power.text, db.text.font, settings.textSize, db.text.outline)
end

function Bar:Apply()
    local db, text, own = ns.db, ns.db.text, self:Own()
    local frame = self.frame
    frame:SetScale(own.scale)
    frame:SetWidth(own.width)
    frame:ClearAllPoints()
    frame:SetPoint(own.point[1], UIParent, own.point[3], own.point[4], own.point[5])
    frame:EnableMouse(not db.locked)
    frame.unlockTint:SetShown(not db.locked)
    FrogLib.Grid:SetShown(not db.locked, "FrogTarget")
    if self.unit == "target" then
        -- Blizzard's combo points (drawn on its target frame) stay, unless ours are on: then
        -- they'd be shown twice (and another addon hiding them couldn't).
        local ownCombo = self.combo and db.combo.enabled
        FrogLib.Hider.Set(ADDON, "TargetFrame", db.hideTargetFrame, { keep = ownCombo and {} or { "ComboFrame" } })
    else
        FrogLib.Hider.Set(ADDON, "FocusFrame", own.enabled and own.hideBlizzard)
    end

    self.gauge:SetHeight(db.height)
    self.gauge:SetTexture(db.texture)
    ns.Media:SetNameFont(self.left, text.font, text.size, text.outline) -- the name: other scripts draw too
    ns.Media:SetFont(self.right, text.font, text.size, text.outline)
    self.left:SetWidth(own.width * 0.72) -- long names truncate before reaching the right text
    -- The classic look's stone border takes a few pixels round each bar; the text clears it.
    local lift = db.style == "classic" and 6 or 2
    self.left:ClearAllPoints()
    self.left:SetPoint("BOTTOMLEFT", self.gauge.bar, "TOPLEFT", 1, lift)
    self.right:ClearAllPoints()
    self.right:SetPoint("BOTTOMRIGHT", self.gauge.bar, "TOPRIGHT", -1, lift)

    self:ApplyPower()
    self:ApplyCombo()

    local cast = self.cast
    cast:ClearAllPoints()
    if db.cast.position == "auras" then
        cast:SetPoint("TOPRIGHT", self.gauge.bar, "BOTTOMRIGHT", 0, self.auras:Bottom() - db.cast.gap)
    elseif db.cast.position == "below" then
        -- Clear of both bars' stone borders in the classic look, and of a power bar.
        cast:SetPoint("TOPRIGHT", self.gauge.bar, "BOTTOMRIGHT", 0,
            -(db.cast.gap + (db.style == "classic" and 10 or 2) + self:PowerDrop()))
    else
        cast:SetPoint("BOTTOMRIGHT", self.gauge.bar, "TOPRIGHT", 0, db.cast.offset)
    end
    cast:SetWidth(db.cast.width)
    ns.Media:SetFont(cast.time, text.font, text.size, text.outline)
    cast.time:SetTextColor(1, 0.95, 0.85)
    cast.gauge:SetHeight(db.cast.height)
    cast.gauge:SetTexture(db.texture)
    ns.Media:SetFont(cast.label, text.font, text.size + 2, text.outline)
    cast.label:ClearAllPoints()
    cast.label:SetPoint("TOPRIGHT", cast, "BOTTOMRIGHT", 0, -(lift + 1))
    cast.time:ClearAllPoints()
    cast.time:SetPoint("RIGHT", cast, "LEFT", -(lift + 6), 0)
    cast.label:SetTextColor(1, 0.95, 0.85)

    local tot = self.tot
    tot.gauge:SetHeight(db.height)
    tot.gauge:SetTexture(db.texture)
    tot.gauge.bar:ClearAllPoints()
    tot.gauge.bar:SetPoint("BOTTOMLEFT", self.gauge.bar, "BOTTOMRIGHT", db.tot.gap, 0)
    tot.gauge.bar:SetWidth(db.tot.width)
    tot.name:SetWidth(db.tot.width)
    tot.name:ClearAllPoints()
    tot.name:SetPoint("BOTTOMLEFT", tot.gauge.bar, "TOPLEFT", 1, lift + 2)
    ns.Media:SetNameFont(tot.name, text.font, text.size - 1, text.outline)
    ns.Media:SetFont(self.chevrons, text.font, math.max(8, text.size - 3), text.outline)
    self.chevrons:ClearAllPoints()
    self.chevrons:SetPoint("CENTER", self.gauge.bar, "RIGHT", db.tot.gap / 2, 0)

    self.auras:Apply(frame, self.gauge.bar)
    self.auras:Preview(frame, self.gauge.bar, not db.locked)
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
    local gauge = self.gauge
    if preview then
        gauge:SetValues(fake.value, fake.max, true)
        gauge:SetAbsorb(fake.shield, fake.max)
    else
        local max = UnitHealthMax(unit)
        gauge:SetValues(UnitHealth(unit), max, instant)
        -- The shield total can be secret; it only ever goes into the gauge's status bars.
        gauge:SetAbsorb((UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)) or 0, max)
    end
    gauge:ShowAbsorb(db.absorb)
    local r, g, b = BarColor(unit)
    gauge:SetColor(r, g, b)
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

-- An empty power bar fades out (power.hideEmpty): gone at once for a new unit at 0, after EMPTY_WAIT
-- for one that drops to 0 (rage ebbing); in combat a curve over its secret percent does it instead.
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
    local alpha = Curve.Power(unit, Curve.Empty())
    if issecret(alpha) or alpha ~= nil then return alpha end
    return 1
end

-- Values may be secret: they only go into the gauge and SetFormattedText. A unit with no power
-- at all (a critter) shows none, when that much can be told.
function Bar:UpdatePower(instant)
    local power, settings = self.power, ns.db.power
    local unit = self:Enabled() and UnitExists(self.unit) and self.unit or nil
    local show = self:Has("power") and (unit ~= nil or not ns.db.locked)
    if show and unit then
        local max = UnitPowerMax(unit)
        if Safe(max) == 0 then
            show = false
        else
            power:SetValues(UnitPower(unit), max, instant)
        end
    elseif show then
        power:SetValues(self.fakePower.value, self.fakePower.max, true) -- unlocked: a sample
    end
    power.bar:SetShown(show)
    if not show then return end
    power.bar:SetAlpha(self:EmptyAlpha(unit, instant))
    local r, g, b = Color.Power(unit)
    power:SetColor(r, g, b)
    ns.SetUnitText(power.text, settings.text, unit, not unit and self.fakePower, true)
    TintText(power.text, r, g, b)
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
    local settings = ns.db.icons
    local anchor = ICON_ANCHORS[settings.anchor] or ICON_ANCHORS.left
    local relative = anchor[2] == "bar" and self.gauge.bar or self.left
    local previous
    for _, key in ipairs(ICON_ORDER) do
        local icon = self.icons[key]
        local shown = false
        if settings.enabled and settings[key] then
            if unit then
                shown = Icons.SHOW[key](icon, unit, settings.size)
            elseif Icons.PREVIEW[key] then
                shown = Icons.PREVIEW[key](icon, settings.size)
            end
        end
        icon:SetShown(shown)
        if shown then
            if icon:GetObjectType() == "Texture" then icon:SetSize(settings.size, settings.size) end
            icon:ClearAllPoints()
            if previous then
                if anchor[6] < 0 then
                    icon:SetPoint("RIGHT", previous, "LEFT", -2, 0)
                else
                    icon:SetPoint("LEFT", previous, "RIGHT", 2, 0)
                end
            else
                icon:SetPoint(anchor[1], relative, anchor[3], anchor[4] + settings.x, anchor[5] + settings.y)
            end
            previous = icon
        end
    end
end

function Bar:UpdateCast(event, interruptedBy)
    local cast, unit = self.cast, self.unit
    if not self:Has("cast") then
        cast:Hide()
        return
    end
    local exists = UnitExists(unit)
    cast.driver:Update((issecret(exists) or exists) and unit or nil, event, not ns.db.locked, interruptedBy)
end

function Bar:UpdateToT()
    local tot, settings = self.tot, ns.db.tot
    local other = self.unit .. "target"
    local show, r, g, b
    if not self:Has("tot") then
        show = false
    elseif not UnitExists(self.unit) then
        show = not ns.db.locked
        if show then
            tot.gauge:SetValues(FAKE_TOT.value, FAKE_TOT.max, true)
            if ns.db.colorMode == "xiv" then
                local friend = Color.XIV.friend
                r, g, b = friend.r, friend.g, friend.b
            else
                r, g, b = BarColor(nil)
            end
            ns.SetUnitText(tot.name, settings.template, nil, FAKE_TOT)
        end
    elseif UnitExists(other) then
        show = true
        tot.gauge:SetValues(UnitHealth(other), UnitHealthMax(other))
        r, g, b = BarColor(other)
        ns.SetUnitText(tot.name, settings.template, other)
    end
    if show then
        tot.gauge:SetColor(r, g, b)
        TintText(tot.name, r, g, b)
    end
    tot:SetShown(show)
    self.chevrons:SetShown(show)
end
