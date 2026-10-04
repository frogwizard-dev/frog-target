local _, ns = ...
local Target = {}
ns.Target = Target

local issecret = ns.issecret
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ELAPSED = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime
local REMAINING = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
local IMMEDIATE = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate

-- Shown while unlocked with nothing targeted, so there's something to drag and style.
local FAKE = { name = "Striking Dummy", level = "70", value = 76, max = 100, percent = 76, shield = 12 }
local FAKE_TOT = { name = "You", level = "70", value = 100, max = 100, percent = 100 }

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local XIV_ENGAGED = { 0.95, 0.42, 0.50 } -- pink-red: fighting
local XIV_PASSIVE = { 0.96, 0.86, 0.56 } -- pale gold: not engaged yet
local XIV_FRIEND = { 0.50, 0.78, 1.00 }  -- light blue: you, players, friendly NPCs

local function Safe(v)
    if issecret(v) then return nil end
    return v
end

local function BarColor(unit)
    local db = ns.db
    if unit and db.colorMode == "xiv" then
        local c
        if Safe(UnitIsFriend("player", unit)) then
            c = XIV_FRIEND
        elseif Safe(UnitAffectingCombat(unit)) then
            c = XIV_ENGAGED
        else
            c = XIV_PASSIVE
        end
        return c[1], c[2], c[3]
    elseif unit and db.colorMode == "reaction" then
        if Safe(UnitIsTapDenied(unit)) then return 0.55, 0.55, 0.55 end
        if Safe(UnitIsPlayer(unit)) then
            local _, class = UnitClass(unit)
            local cc = class and RAID_CLASS_COLORS[class]
            if cc then return cc.r, cc.g, cc.b end
        end
        local reaction = Safe(UnitReaction(unit, "player"))
        if reaction then
            if reaction <= 3 then return 0.90, 0.32, 0.25 end
            if reaction == 4 then return 0.95, 0.85, 0.35 end
            return 0.45, 0.85, 0.40
        end
    end
    return db.color.r, db.color.g, db.color.b
end

-- Text in a light version of the bar's colour, with a dark outline so it lifts off the world.
local function TintText(fs, r, g, b)
    if ns.db.text.tinted then
        fs:SetTextColor(r + (1 - r) * 0.55, g + (1 - g) * 0.55, b + (1 - b) * 0.55)
    else
        fs:SetTextColor(1, 1, 1)
    end
end

------------------------------------------------------------------------------
-- Icons beside the name: raid marker, leader/assistant, group role, PvP, quest mob
------------------------------------------------------------------------------

local ICON_ORDER = { "raid", "leader", "role", "pvp", "quest" } -- nearest the name first
local RAID_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local PVP_COORDS = { 0.08, 0.58, 0.045, 0.545 } -- the old PvP badges sit in the corner of a larger file
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }

-- Modern atlas where the client has it, otherwise the classic file.
local function SetIcon(tex, atlas, file, coords)
    if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas)
    else
        tex:SetTexture(file)
        tex:SetTexCoord(unpack(coords or { 0, 1, 0, 1 }))
    end
end

-- The raid marker is a FontString showing the icon as inline markup: the index can be secret,
-- and SetFormattedText is the one place a secret can still be displayed.
local function RaidMarkup(size)
    return "|T" .. RAID_ICON .. "%d:" .. size .. ":" .. size .. "|t"
end

-- Each sets its icon and returns true if it applies to the unit.
local SHOW = {}
function SHOW.raid(fs, unit, size)
    local index = GetRaidTargetIndex(unit)
    if not issecret(index) and not index then return false end
    return (pcall(fs.SetFormattedText, fs, RaidMarkup(size), index))
end
function SHOW.leader(tex, unit)
    if Safe(UnitIsGroupLeader(unit)) then
        SetIcon(tex, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
        return true
    elseif Safe(UnitIsGroupAssistant(unit)) then
        SetIcon(tex, "UI-HUD-UnitFrame-Player-Group-AssistantIcon", "Interface\\GroupFrame\\UI-Group-AssistantIcon")
        return true
    end
    return false
end
function SHOW.role(tex, unit)
    local role = UnitGroupRolesAssigned and Safe(UnitGroupRolesAssigned(unit))
    if not role or not ROLE_ATLAS[role] then return false end
    SetIcon(tex, ROLE_ATLAS[role], "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",
        GetTexCoordsForRoleSmallCircle and { GetTexCoordsForRoleSmallCircle(role) })
    return true
end
-- Players only: faction guards are flagged too, and a badge on every guard is noise.
function SHOW.pvp(tex, unit)
    if not Safe(UnitIsPlayer(unit)) then return false end
    if Safe(UnitIsPVPFreeForAll(unit)) then
        SetIcon(tex, "UI-HUD-UnitFrame-Player-PVP-FFAIcon", "Interface\\TargetingFrame\\UI-PVP-FFA", PVP_COORDS)
        return true
    end
    if Safe(UnitIsPVP(unit)) then
        local faction = Safe(UnitFactionGroup(unit))
        if faction == "Horde" or faction == "Alliance" then
            SetIcon(tex, "UI-HUD-UnitFrame-Player-PVP-" .. faction .. "Icon",
                "Interface\\TargetingFrame\\UI-PVP-" .. faction, PVP_COORDS)
            return true
        end
    end
    return false
end
function SHOW.quest(tex, unit)
    if not Safe(UnitIsQuestBoss(unit)) then return false end
    SetIcon(tex, "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest", "Interface\\TargetingFrame\\PortraitQuestBadge")
    return true
end

-- Samples for the unlocked preview.
local PREVIEW = {
    raid = function(fs, size)
        fs:SetFormattedText(RaidMarkup(size), 1)
        return true
    end,
    leader = function(tex)
        SetIcon(tex, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
        return true
    end,
}

local function Text(parent)
    -- A default font up front: SetText errors on a FontString with none, and the configured
    -- font is only applied later in Apply.
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    return fs
end

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------

function Target:Init()
    local f = CreateFrame("Frame", "FrogTargetFrame", UIParent)
    f:SetHeight(26)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
        ns.Grid:Track(frame)
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        ns.Grid:Track(nil)
        -- Centred exactly when let go near the middle of the screen (Grid.lua).
        local p, rp, x, y = ns.Grid:Snap(frame)
        ns.db.point = { p, "UIParent", rp, x, y }
    end)
    -- Tint shown only while unlocked, marking the draggable area.
    f.unlockTint = f:CreateTexture(nil, "BACKGROUND")
    f.unlockTint:SetPoint("TOPLEFT", -4, 4)
    f.unlockTint:SetPoint("BOTTOMRIGHT", 4, -4)
    f.unlockTint:SetColorTexture(0.3, 0.6, 1, 0.2)
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

    self:BuildCast()
    self:BuildToT()
    self.icons = {}
    for _, key in ipairs(ICON_ORDER) do
        self.icons[key] = key == "raid" and Text(f) or f:CreateTexture(nil, "OVERLAY")
    end

    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    for _, event in ipairs({ "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED" }) do
        pcall(f.RegisterEvent, f, event)
    end
    pcall(f.RegisterUnitEvent, f, "UNIT_CLASSIFICATION_CHANGED", "target")
    f:RegisterUnitEvent("UNIT_HEALTH", "target")
    f:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
    f:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
    f:RegisterUnitEvent("UNIT_NAME_UPDATE", "target")
    f:RegisterUnitEvent("UNIT_LEVEL", "target")
    f:RegisterUnitEvent("UNIT_FACTION", "target")
    f:RegisterUnitEvent("UNIT_FLAGS", "target") -- entering/leaving combat recolours the bar
    for _, event in ipairs(CAST_EVENTS) do
        pcall(f.RegisterUnitEvent, f, event, "target")
    end
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_TARGET_CHANGED" then
            self:Update(true)
            ns.Auras:TargetChanged()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if self.clicksPending then self:SetupClicks() end
        elseif event:find("^UNIT_SPELLCAST") then
            self:UpdateCast(event)
        else
            self:Update(false)
        end
    end)

    -- Target of target has no events of its own, so poll it a few times a second.
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

-- FFXIV shows an enemy's cast as a glowing white-gold line floating over the right half of
-- the bar, with the spell name hanging underneath it.
function Target:BuildCast()
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
    c:SetScript("OnUpdate", function(bar)
        if bar.sample then return end
        if not ns.db.cast.showTime or bar.holdUntil then
            bar.time:SetText("")
            return
        end
        local ok, duration = pcall(bar.GetTimerDuration, bar)
        if ok and duration then
            pcall(bar.time.SetFormattedText, bar.time, "%.1f", duration:GetRemainingDuration())
        end
    end)
    c:Hide()
    self.cast = c
end

function Target:BuildToT()
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
-- shown by RegisterUnitWatch. The buttons copy the bar's position rather than anchoring to it:
-- anything a secure frame is anchored to becomes protected too, and the bar couldn't then be
-- shown or hidden in combat (ADDON_ACTION_BLOCKED on FrogTargetFrame:SetShown). On 12.x a unit button's own "togglemenu" is gated and silently
-- does nothing, so right-click runs "/click" on a hidden SecureActionButton child whose
-- togglemenu isn't gated (the same route EllesmereUI's unit frames use).
local function ClickButton(name, unit)
    local b = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    b:SetAttribute("unit", unit)
    b:SetAttribute("*type1", "target")
    b:RegisterForClicks("AnyUp")

    local menu = CreateFrame("Button", name .. "Menu", b, "SecureActionButtonTemplate")
    menu:SetSize(1, 1)
    menu:EnableMouse(false)
    menu:RegisterForClicks("AnyUp")
    for i = 1, 5 do menu:SetAttribute("type" .. i, "togglemenu") end
    menu:SetAttribute("useparent-unit", true)
    menu:SetAttribute("useOnKeyDown", false) -- act on the up-click whatever the key-down setting
    b:SetAttribute("*type2", "macro")
    b:SetAttribute("*macrotext2", "/click " .. name .. "Menu")

    b:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit(unit)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    b:Hide()
    return b
end

-- Secure frames can only be placed and shown out of combat; changes made in combat wait.
function Target:SetupClicks()
    if InCombatLockdown() then
        self.clicksPending = true
        return
    end
    self.clicksPending = nil
    local db = ns.db
    if not self.click then
        self.click = ClickButton("FrogTargetClick", "target")
        self.totClick = ClickButton("FrogTargetToTClick", "targettarget")
    end
    -- Off while unlocked, so the bar can be dragged.
    local on = db.clicks and db.locked
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
    c:SetScale(db.scale)
    c:ClearAllPoints()
    c:SetPoint(db.point[1], UIParent, db.point[3], db.point[4], db.point[5])
    c:SetSize(db.width, self.frame:GetHeight())
    c:SetHitRectInsets(-2, -2, -2, -6)
    watch(c, on)

    -- Target's target: its gauge starts `gap` past the end of the target bar. Anchoring one
    -- secure button to the other is fine.
    local t = self.totClick
    t:SetScale(db.scale)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", c, "BOTTOMRIGHT", db.tot.gap, 0)
    t:SetSize(db.tot.width, self.frame:GetHeight())
    t:SetHitRectInsets(-2, -2, -2, -6)
    watch(t, on and db.tot.enabled)
end

------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------

function Target:Apply()
    local db, t = ns.db, ns.db.text
    local f = self.frame
    f:SetScale(db.scale)
    f:SetWidth(db.width)
    f:ClearAllPoints()
    f:SetPoint(db.point[1], UIParent, db.point[3], db.point[4], db.point[5])
    f:EnableMouse(not db.locked)
    f.unlockTint:SetShown(not db.locked)
    ns.Grid:SetShown(not db.locked)
    -- Combo points are drawn on Blizzard's target frame, so they stay.
    ns.HideBlizzardFrame("TargetFrame", db.hideTargetFrame, { "ComboFrame" })

    self.gauge:SetHeight(db.height)
    self.gauge:SetTexture(db.texture)
    ns.Media:SetFont(self.left, t.font, t.size, t.outline)
    ns.Media:SetFont(self.right, t.font, t.size, t.outline)
    self.left:SetWidth(db.width * 0.72) -- long names truncate before reaching the right text
    -- The classic look's stone border takes a few pixels round each bar; the text clears it.
    local lift = db.style == "classic" and 6 or 2
    self.left:ClearAllPoints()
    self.left:SetPoint("BOTTOMLEFT", self.gauge.bar, "TOPLEFT", 1, lift)
    self.right:ClearAllPoints()
    self.right:SetPoint("BOTTOMRIGHT", self.gauge.bar, "TOPRIGHT", -1, lift)

    local c = self.cast
    c:ClearAllPoints()
    if db.cast.position == "auras" then
        c:SetPoint("TOPRIGHT", self.gauge.bar, "BOTTOMRIGHT", 0, ns.AurasBottom() - db.cast.gap)
    elseif db.cast.position == "below" then
        -- Clear of both bars' stone borders in the classic look.
        c:SetPoint("TOPRIGHT", self.gauge.bar, "BOTTOMRIGHT", 0, -(db.cast.gap + (db.style == "classic" and 10 or 2)))
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

    ns.Auras:Apply(f, self.gauge.bar)
    ns.Auras:Preview(f, self.gauge.bar, not db.locked)
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

function Target:Update(instant)
    local db = ns.db
    local exists = UnitExists("target")
    local preview = not exists and not db.locked
    self.frame:SetShown(exists or preview)
    if not exists and not preview then return end

    local unit = exists and "target" or nil
    local g = self.gauge
    if preview then
        g:SetValues(FAKE.value, FAKE.max, true)
        g:SetAbsorb(FAKE.shield, FAKE.max)
    else
        local max = UnitHealthMax("target")
        g:SetValues(UnitHealth("target"), max, instant)
        -- The shield total can be secret; it only ever goes into the gauge's status bars.
        g:SetAbsorb((UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("target")) or 0, max)
    end
    g:ShowAbsorb(db.absorb)
    local r, g, b = BarColor(unit)
    self.gauge:SetColor(r, g, b)
    ns.SetUnitText(self.left, db.text.left, unit, preview and FAKE)
    ns.SetUnitText(self.right, db.text.right, unit, preview and FAKE)
    TintText(self.left, r, g, b)
    TintText(self.right, r, g, b)
    self:UpdateIcons(unit)

    if instant then
        self:UpdateCast()
        self:UpdateToT()
    end
end

-- Where the icon row starts, and which way it grows:
-- { point on first icon, relative-to key, its point, base x, base y, step direction }.
local ICON_ANCHORS = {
    left = { "RIGHT", "left", "LEFT", -4, 0, -1 },       -- beside the name, growing left
    right = { "LEFT", "bar", "RIGHT", 6, 0, 1 },         -- past the end of the bar, growing right
    above = { "BOTTOMLEFT", "left", "TOPLEFT", 0, 4, 1 }, -- above the name, growing right
}

-- Shown icons line up from the chosen anchor, offset by the x/y setting. unit nil = preview.
function Target:UpdateIcons(unit)
    local cfg = ns.db.icons
    local a = ICON_ANCHORS[cfg.anchor] or ICON_ANCHORS.left
    local relative = a[2] == "bar" and self.gauge.bar or self.left
    local prev
    for _, key in ipairs(ICON_ORDER) do
        local tex = self.icons[key]
        local shown = false
        if cfg.enabled and cfg[key] then
            if unit then
                shown = SHOW[key](tex, unit, cfg.size)
            elseif PREVIEW[key] then
                shown = PREVIEW[key](tex, cfg.size)
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

function Target:UpdateCast(event)
    local c = self.cast
    if not ns.db.cast.enabled then
        c:Hide()
        return
    end
    -- Unlocked: a sample cast so its place and look can be judged, unless there's a real one.
    local function Sample()
        c.sample = true
        c:SetMinMaxValues(0, 1)
        c:SetValue(0.6)
        c.gauge:SetColor(1, 0.72, 0.3)
        c.label:SetText("Shadow Bolt")
        c.time:SetText(ns.db.cast.showTime and "1.4" or "")
        c:Show()
    end
    c.sample = nil
    if not UnitExists("target") then
        if not ns.db.locked then Sample() else c:Hide() end
        return
    end

    local _, text, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
    local duration, direction
    if text then
        duration, direction = UnitCastingDuration and UnitCastingDuration("target"), ELAPSED
    else
        _, text, _, _, _, _, notInterruptible = UnitChannelInfo("target")
        if text then
            duration, direction = UnitChannelDuration and UnitChannelDuration("target"), REMAINING
        end
    end

    if text and duration then
        c.holdUntil = nil
        pcall(c.SetTimerDuration, c, duration, IMMEDIATE, direction)
        c.label:SetText(text)
        if not issecret(notInterruptible) and notInterruptible then
            c.gauge:SetColor(0.6, 0.6, 0.6)
        else
            c.gauge:SetColor(1, 0.72, 0.3)
        end
        c:Show()
    elseif (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED") and c:IsShown() then
        -- Hold the bar briefly so an interrupt is visible, as FFXIV does.
        c:SetMinMaxValues(0, 1)
        c:SetValue(1)
        c.gauge:SetColor(0.85, 0.2, 0.15)
        c.label:SetText(event == "UNIT_SPELLCAST_FAILED" and FAILED or INTERRUPTED)
        local hold = GetTime() + 0.8
        c.holdUntil = hold
        C_Timer.After(0.8, function()
            if c.holdUntil == hold then c:Hide() end
        end)
    elseif not ns.db.locked then
        Sample()
    elseif not c.holdUntil then
        c:Hide()
    end
end

function Target:UpdateToT()
    local tot, cfg = self.tot, ns.db.tot
    local show, r, g, b
    if not cfg.enabled then
        show = false
    elseif not UnitExists("target") then
        show = not ns.db.locked
        if show then
            tot.gauge:SetValues(FAKE_TOT.value, FAKE_TOT.max, true)
            if ns.db.colorMode == "xiv" then r, g, b = unpack(XIV_FRIEND) else r, g, b = BarColor(nil) end
            ns.SetUnitText(tot.name, cfg.template, nil, FAKE_TOT)
        end
    elseif UnitExists("targettarget") then
        show = true
        tot.gauge:SetValues(UnitHealth("targettarget"), UnitHealthMax("targettarget"))
        r, g, b = BarColor("targettarget")
        ns.SetUnitText(tot.name, cfg.template, "targettarget")
    end
    if show then
        tot.gauge:SetColor(r, g, b)
        TintText(tot.name, r, g, b)
    end
    tot:SetShown(show)
    self.chevrons:SetShown(show)
end
