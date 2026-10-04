local _, ns = ...

-- FrogTarget's bars, in WoW's own art, three looks (ns.db.style):
--   "classic": the 1.x status bar texture on a dark track, in the grey stone border tooltips
--              and old frames use;
--   "modern":  a plain fill on a dark track, with nothing round it but a 1px black
--              edge;
--   "forever": the cooldown manager's bar fill, in our own Forever-style frame (below).
-- Same methods as the XIV addons' gauges, so Target.lua drives them unchanged: SetHeight,
-- SetTexture, SetColor, SetValues, and the absorb shield ones; SetSpark adds the cast bar's spark.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local STONE = "Interface\\Tooltips\\UI-Tooltip-Border"
local SMOOTH = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local IMMEDIATE = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate

local STYLES = {
    classic = { texture = "Interface\\TargetingFrame\\UI-StatusBar", stone = true },
    -- A plain fill (FrogUI's Matte, or flat colour without FrogUI) and nothing round it but the
    -- 1px black edge. (Not the cooldown manager's bar art: it has its own frame drawn in.)
    modern = { texture = "Interface\\AddOns\\FrogUI\\Media\\Bars\\Matte.tga", fallback = WHITE, edge = true },
    forever = { atlas = "UI-HUD-CoolDownManager-Bar", frame = true,
        texture = "Interface\\TargetingFrame\\UI-StatusBar" },
}

-- The Forever frame: our own (Media\ForeverFrame.tga, 16x16), in the style of Forever's bar
-- frames: a dark outline, a light metallic rim brighter along the top, and a dark inner line,
-- each one screen pixel wide, with the corners cut. Nine-sliced at one texel per screen pixel, so
-- it's crisp at any bar size and nothing stretches but its straight edges. It sits 2 pixels out
-- from the bar, its inner line over the fill's edge, so the fill sits inside it.
local FRAME_FILE = "Interface\\AddOns\\FrogTarget\\Media\\ForeverFrame.tga"
local FRAME_SIZE, FRAME_SLICE, FRAME_OUT = 16, 3, 2
local FRAME_KEYS = { "tl", "t", "tr", "l", "r", "bl", "b", "br" }

local function FrameArt(bar)
    local p = {}
    for _, key in ipairs(FRAME_KEYS) do
        local t = bar:CreateTexture(nil, "OVERLAY", nil, 5)
        t:SetTexture(FRAME_FILE, nil, nil, "NEAREST")
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
        p[key] = t
    end
    return p
end

-- thickness: screen pixels per texel (1 to 3), a whole number so it stays crisp.
local function PlaceFrameArt(p, bar, thickness)
    local px = (thickness or 1) * 768 / select(2, GetPhysicalScreenSize()) / bar:GetEffectiveScale()
    local m, out = FRAME_SLICE * px, FRAME_OUT * px
    local a, b = FRAME_SLICE / FRAME_SIZE, (FRAME_SIZE - FRAME_SLICE) / FRAME_SIZE
    p.tl:SetTexCoord(0, a, 0, a)
    p.t:SetTexCoord(a, b, 0, a)
    p.tr:SetTexCoord(b, 1, 0, a)
    p.l:SetTexCoord(0, a, a, b)
    p.r:SetTexCoord(b, 1, a, b)
    p.bl:SetTexCoord(0, a, b, 1)
    p.b:SetTexCoord(a, b, b, 1)
    p.br:SetTexCoord(b, 1, b, 1)
    for _, t in pairs(p) do t:ClearAllPoints() end
    p.tl:SetPoint("TOPLEFT", bar, "TOPLEFT", -out, out)
    p.tr:SetPoint("TOPRIGHT", bar, "TOPRIGHT", out, out)
    p.bl:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -out, -out)
    p.br:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", out, -out)
    for _, key in ipairs({ "tl", "tr", "bl", "br" }) do p[key]:SetSize(m, m) end
    p.t:SetPoint("TOPLEFT", p.tl, "TOPRIGHT")
    p.t:SetPoint("BOTTOMRIGHT", p.tr, "BOTTOMLEFT")
    p.b:SetPoint("TOPLEFT", p.bl, "TOPRIGHT")
    p.b:SetPoint("BOTTOMRIGHT", p.br, "BOTTOMLEFT")
    p.l:SetPoint("TOPLEFT", p.tl, "BOTTOMLEFT")
    p.l:SetPoint("BOTTOMRIGHT", p.bl, "TOPRIGHT")
    p.r:SetPoint("TOPLEFT", p.tr, "BOTTOMLEFT")
    p.r:SetPoint("BOTTOMRIGHT", p.br, "TOPRIGHT")
end

local function Loaded(addon)
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return isLoaded and isLoaded(addon)
end

local function HasAtlas(name)
    return name and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local Gauge = {}
Gauge.__index = Gauge

function Gauge:Style()
    return STYLES[self.style or (ns.db and ns.db.style)] or STYLES.classic
end

function ns.CreateGauge(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local g = setmetatable({ bar = bar, h = 12 }, Gauge)

    g.track = bar:CreateTexture(nil, "BACKGROUND")
    g.track:SetAllPoints()
    -- Forever: the cooldown manager's frame, behind and round the bar.
    g.frame = FrameArt(bar)

    -- Classic: the stone border, on a frame just outside the bar.
    g.stone = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    g.stone:SetFrameLevel(bar:GetFrameLevel() + 3)

    -- Modern: a thin dark edge round the bar.
    g.edge = {}
    for _, key in ipairs({ "top", "bottom", "left", "right" }) do
        local t = bar:CreateTexture(nil, "OVERLAY", nil, 6)
        t:SetColorTexture(0, 0, 0, 1)
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
        g.edge[key] = t
    end

    g.spark = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    g.spark:SetTexture(SPARK)
    g.spark:SetBlendMode("ADD")
    g.spark:Hide()

    g:Layout()
    return g
end

-- The fill: the chosen texture, or the look's own (an atlas where the client has it).
function Gauge:ApplyTexture()
    local style, path = self:Style(), self.texturePath
    local fill
    if path and path ~= "" then
        self.bar:SetStatusBarTexture(path)
    elseif style.atlas and HasAtlas(style.atlas) then
        self.bar:SetStatusBarTexture(WHITE)
        self.bar:GetStatusBarTexture():SetAtlas(style.atlas)
    elseif style.fallback and not Loaded("FrogUI") then
        self.bar:SetStatusBarTexture(style.fallback)
    else
        self.bar:SetStatusBarTexture(style.texture)
    end
    fill = self.bar:GetStatusBarTexture()
    self.spark:ClearAllPoints()
    self.spark:SetPoint("CENTER", fill, "RIGHT", 0, 0)
    self:AnchorAbsorb()
    if self.color then self:SetColor(unpack(self.color)) end
end

function Gauge:Layout()
    local style, bar = self:Style(), self.bar
    bar:SetHeight(self.h)

    if style.frame then PlaceFrameArt(self.frame, bar, ns.db and ns.db.frameThickness) end
    self.track:SetColorTexture(0, 0, 0, 0.55)
    for _, t in pairs(self.frame) do t:SetShown(style.frame == true) end

    if style.stone then
        -- The stone line is the outer ~3px of its 12px edge: with the frame 3px past the bar, the
        -- line meets the fill, with no dark gap between them.
        self.stone:ClearAllPoints()
        self.stone:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 3)
        self.stone:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -3)
        self.stone:SetBackdrop({ edgeFile = STONE, edgeSize = 12 })
        local c = ns.db and ns.db.borderColor or { r = 0.75, g = 0.75, b = 0.75 }
        self.stone:SetBackdropBorderColor(c.r, c.g, c.b, 1)
        self.stone:Show()
    else
        self.stone:Hide()
    end

    -- One screen pixel, outside the bar.
    local p = 768 / select(2, GetPhysicalScreenSize()) / bar:GetEffectiveScale()
    local e = self.edge
    e.top:ClearAllPoints()
    e.top:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", -p, 0)
    e.top:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", p, 0)
    e.top:SetHeight(p)
    e.bottom:ClearAllPoints()
    e.bottom:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -p, 0)
    e.bottom:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", p, 0)
    e.bottom:SetHeight(p)
    e.left:ClearAllPoints()
    e.left:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
    e.left:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 0, 0)
    e.left:SetWidth(p)
    e.right:ClearAllPoints()
    e.right:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 0)
    e.right:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 0, 0)
    e.right:SetWidth(p)
    for _, t in pairs(e) do t:SetShown(style.edge == true) end

    self.spark:SetSize(math.max(10, self.h * 1.6), self.h * 2.6)
    self:ApplyTexture()
end

function Gauge:SetStyle(style)
    self.style = style
    self:Layout()
end

function Gauge:SetHeight(h)
    self.h = h
    self:Layout()
end

function Gauge:SetTexture(path)
    self.texturePath = path
    self:Layout()
end

-- The cast bar's spark, at the end of the fill.
function Gauge:SetSpark(on)
    self.spark:SetShown(on)
end

function Gauge:SetColor(r, g, b)
    self.color = { r, g, b }
    self.bar:SetStatusBarColor(r, g, b)
end

-- Values may be secret; StatusBar setters accept them directly.
function Gauge:SetValues(value, max, instant)
    self.bar:SetMinMaxValues(0, max)
    self.bar:SetValue(value, instant and IMMEDIATE or SMOOTH)
end

------------------------------------------------------------------------------
-- Absorb shields (optional: EnableAbsorb once, then SetAbsorb), as in the XIV addons
------------------------------------------------------------------------------

-- A shield fills the missing part of the bar from the fill's edge, and whatever doesn't fit
-- there is laid over the right end of the fill (so a shield at full health still shows). The
-- amount can be secret, so the split is done by clipping, never arithmetic:
--   ahead: a bar starting at the fill's edge, clipped to the missing part -> min(shield, missing)
--   over:  a right-to-left bar across the bar, clipped to the fill        -> max(0, shield - missing)
local SHIELD_STRIPES = "Interface\\RaidFrame\\Shield-Overlay" -- Blizzard's diagonal shield stripes

local function ShieldBar(parent)
    local sb = CreateFrame("StatusBar", nil, parent)
    sb:SetStatusBarTexture(WHITE)
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(0)
    local stripes = sb:CreateTexture(nil, "ARTWORK", nil, 1)
    sb.hasStripes = stripes:SetTexture(SHIELD_STRIPES, "REPEAT", "REPEAT") and true or false
    stripes:SetHorizTile(true)
    stripes:SetVertTile(true)
    stripes:SetAllPoints(sb:GetStatusBarTexture())
    sb.stripes = stripes
    return sb
end

function Gauge:EnableAbsorb()
    if self.absorb then return end
    local bar = self.bar
    local a = {}
    a.missClip = CreateFrame("Frame", nil, bar)
    a.missClip:SetClipsChildren(true)
    a.ahead = ShieldBar(a.missClip)
    a.fillClip = CreateFrame("Frame", nil, bar)
    a.fillClip:SetClipsChildren(true)
    a.over = ShieldBar(a.fillClip)
    a.over:SetReverseFill(true)
    a.over:SetAllPoints(bar)
    for _, f in ipairs({ a.missClip, a.fillClip }) do f:SetFrameLevel(bar:GetFrameLevel() + 2) end
    bar:HookScript("OnSizeChanged", function(_, w) a.ahead:SetWidth(w) end)
    a.ahead:SetWidth(bar:GetWidth())
    self.absorb = a
    self:AnchorAbsorb()
    self:SetAbsorbColor(1, 1, 1)
end

function Gauge:AnchorAbsorb()
    local a = self.absorb
    if not a then return end
    local bar, fill = self.bar, self.bar:GetStatusBarTexture()
    a.missClip:ClearAllPoints()
    a.missClip:SetPoint("TOPLEFT", fill, "TOPRIGHT")
    a.missClip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
    a.ahead:ClearAllPoints()
    a.ahead:SetPoint("TOPLEFT", fill, "TOPRIGHT")
    a.ahead:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
    a.fillClip:ClearAllPoints()
    a.fillClip:SetPoint("TOPLEFT", bar, "TOPLEFT")
    a.fillClip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
end

function Gauge:SetAbsorbColor(r, g, b)
    local a = self.absorb
    if not a then return end
    for _, sb in ipairs({ a.ahead, a.over }) do
        sb:SetStatusBarColor(r, g, b, sb.hasStripes and 0.25 or 0.55)
        sb.stripes:SetVertexColor(r, g, b, 0.85)
    end
end

function Gauge:SetAbsorb(value, max)
    local a = self.absorb
    if not a then return end
    for _, sb in ipairs({ a.ahead, a.over }) do
        sb:SetMinMaxValues(0, max)
        sb:SetValue(value)
    end
end

function Gauge:ShowAbsorb(shown)
    local a = self.absorb
    if not a then return end
    a.missClip:SetShown(shown)
    a.fillClip:SetShown(shown)
end
