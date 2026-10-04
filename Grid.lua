local _, ns = ...

-- A layout grid over the screen while the bar is unlocked, and snapping to the screen's
-- horizontal centre: let go of a frame with its centre within SNAP of the middle and it's
-- centred exactly. The centre line lights up while a drag is near enough to snap.
--   ns.Grid:SetShown(on)                    -- with the unlock
--   ns.Grid:Track(frame) / ns.Grid:Track()  -- from OnDragStart / OnDragStop
--   local p, rp, x, y = ns.Grid:Snap(frame) -- after StopMovingOrSizing: its point to save

local Grid = {}
ns.Grid = Grid

local SPACING = 32 -- between lines, in interface units
local SNAP = 16    -- how near the middle snaps
local LINE = { 1, 1, 1, 0.08 }
local CENTRE = { 1, 0.82, 0, 0.45 }
local CENTRE_HOT = { 1, 0.82, 0, 1 }

local grid, tracked

-- One screen pixel in UIParent's units.
local function Pixel()
    return 768 / select(2, GetPhysicalScreenSize()) / UIParent:GetEffectiveScale()
end

-- How far `frame`'s centre is from the screen's, across, in UIParent's units.
local function OffCentre(frame)
    local x = frame:GetCenter()
    if not x then return math.huge end
    return x * frame:GetEffectiveScale() / UIParent:GetEffectiveScale() - UIParent:GetWidth() / 2
end

local function Build()
    grid = CreateFrame("Frame", nil, UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("BACKGROUND")
    grid.lines = {}
    grid:Hide()
    grid:SetScript("OnUpdate", function()
        local near = tracked and math.abs(OffCentre(tracked)) <= SNAP
        local c = near and CENTRE_HOT or CENTRE
        grid.centre:SetColorTexture(c[1], c[2], c[3], c[4])
        grid.centre:SetWidth(Pixel() * (near and 3 or 2))
    end)
end

-- Lines out from the middle, so the centre ones land exactly on the centre.
local function Layout()
    local w, h, px = UIParent:GetWidth(), UIParent:GetHeight(), Pixel()
    local n = 0
    local function Add(vertical, offset, colour, thickness)
        n = n + 1
        local t = grid.lines[n]
        if not t then
            t = grid:CreateTexture(nil, "BACKGROUND")
            grid.lines[n] = t
        end
        t:ClearAllPoints()
        if vertical then
            t:SetPoint("TOP", grid, "TOP", offset, 0)
            t:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
            t:SetWidth(px * thickness)
        else
            t:SetPoint("LEFT", grid, "LEFT", 0, offset)
            t:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
            t:SetHeight(px * thickness)
        end
        t:SetColorTexture(colour[1], colour[2], colour[3], colour[4])
        t:Show()
        return t
    end
    for x = SPACING, w / 2, SPACING do
        Add(true, x, LINE, 1)
        Add(true, -x, LINE, 1)
    end
    for y = SPACING, h / 2, SPACING do
        Add(false, y, LINE, 1)
        Add(false, -y, LINE, 1)
    end
    Add(false, 0, CENTRE, 1)
    grid.centre = Add(true, 0, CENTRE, 2)
    for i = n + 1, #grid.lines do grid.lines[i]:Hide() end
end

function Grid:SetShown(on)
    if not grid then
        if not on then return end
        Build()
    end
    if on then Layout() end
    grid:SetShown(on)
end

function Grid:Track(frame)
    tracked = frame
end

function Grid:Snap(frame)
    if math.abs(OffCentre(frame)) <= SNAP then
        local top = frame:GetTop()
        frame:ClearAllPoints()
        frame:SetPoint("TOP", UIParent, "BOTTOM", 0, top)
        return "TOP", "BOTTOM", 0, top
    end
    local p, _, rp, x, y = frame:GetPoint()
    return p, rp, x, y
end
