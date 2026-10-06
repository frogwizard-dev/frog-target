local _, ns = ...

-- FrogTarget's bars, in WoW's own art, three looks (ns.db.style):
--   "classic": the 1.x status bar texture on a dark track, in the grey stone border tooltips
--              and old frames use;
--   "modern":  a plain fill on a dark track, with nothing round it but a 1px black
--              edge;
--   "forever": the cooldown manager's bar fill, in our own Forever-style frame (FrogLib's).
-- Same methods as the XIV addons' gauges, so Target.lua drives them unchanged: SetHeight,
-- SetTexture, SetColor, SetValues, and the absorb shield ones; SetSpark adds the cast bar's spark,
-- SetTrackAlpha darkens the empty part (the floating power bar).

local WHITE = "Interface\\Buttons\\WHITE8X8"
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
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

-- The borders (Edges, the classic stone and the Forever frame): FrogLib's
-- (Libs\FrogLib\Borders.lua).
local Borders = FrogLib.Borders

local Loaded = FrogLib.Loaded

local function HasAtlas(name)
    return name and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- The absorb shield methods are FrogLib's (Gauge.lua), looked up there each time.
local Gauge = setmetatable({}, { __index = function(_, k) return FrogLib.Gauge.Absorb[k] end })
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
    -- Forever: our Forever-style frame round the bar.
    g.frame = Borders.Forever(bar, "OVERLAY", 5)

    -- Classic: the stone border, on a frame just outside the bar.
    g.stone = Borders.Stone(bar, 3)

    -- Modern: a thin dark edge round the bar.
    g.edge = Borders.Edges(bar, bar, "OVERLAY", 6)

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

    self.track:SetColorTexture(0, 0, 0, self.trackAlpha or 0.55)
    -- Classic: the stone, 3px past the bar, so its line (the outer ~3px of its 12px edge) meets
    -- the fill with no dark gap. Modern: one black screen pixel outside the bar.
    local border = (style.stone and "classic") or (style.frame and "forever") or (style.edge and "pixel") or "none"
    Borders.Show({ edges = self.edge, stone = self.stone, forever = self.frame }, border, { size = 1,
        color = { r = 0, g = 0, b = 0 }, stoneColor = ns.db and ns.db.borderColor or { r = 0.75, g = 0.75, b = 0.75 },
        thickness = ns.db and ns.db.frameThickness })

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

-- How dark the empty part of the bar is (nil: the usual). The floating power bar's is darker,
-- so the health bar under it doesn't show through.
function Gauge:SetTrackAlpha(alpha)
    self.trackAlpha = alpha
    self.track:SetColorTexture(0, 0, 0, alpha or 0.55)
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
