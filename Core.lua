local ADDON, ns = ...

-- FrogTarget: XIVTarget's target bar (the name above a long bar, the cast floating over its right
-- half, auras below, your target's target alongside) in WoW's own art, in three looks: "classic"
-- (1.x), "modern" (plain, a 1px edge) and "forever" (the cooldown manager's bars). Gauge.lua draws
-- the bars; Target.lua makes the same bar for the focus too (off by default).
ns.defaults = {
    locked = true,
    point = { "TOP", "UIParent", "TOP", 0, -140 },
    scale = 1,
    width = 360,
    height = 12,
    -- "classic": the 1.x bar in the grey stone border; "modern": a plain fill with a 1px black edge;
    -- "forever": the cooldown manager's bar in its own frame. texture "": the look's own.
    style = "classic",
    texture = "",
    borderColor = { r = 0.75, g = 0.75, b = 0.75 }, -- the classic stone border's tint
    frameThickness = 1, -- the forever frame: screen pixels per pixel of its art (1 to 3)
    -- "reaction": hostile red / neutral yellow / friendly green, players in their class colour;
    -- "xiv": red while it's fighting, gold before, blue for friends; "fixed": always `color`.
    colorMode = "reaction",
    color = { r = 0.25, g = 0.78, b = 0.25 },
    text = {
        font = "Fonts\\FRIZQT__.TTF",
        outline = "OUTLINE",
        size = 12,
        tinted = false, -- text in a light version of the bar's colour
        levelColor = true, -- the level coloured by difficulty, a skull for bosses (as the game's frame)
        -- Templates: words level, name, class, value, max, percent (percent.1 for a decimal),
        -- power, powermax, powerpercent, powertype.
        left = "level  name",
        right = "value / max   percent",
    },
    tot = { enabled = true, width = 150, gap = 40, template = "name" },
    clicks = true, -- left-click the bars to target, right-click for the unit menu
    hideTargetFrame = false, -- hide Blizzard's target frame (its combo points stay)
    absorb = true, -- the target's shields drawn on its bar as a striped fill
    -- Small icons by the name. anchor: "left" of the name, "right" past the bar's end, or
    -- "above" the name; x/y nudge the whole row from there.
    icons = {
        enabled = true, size = 16, anchor = "left", x = 0, y = 0,
        raid = true, leader = true, role = true, pvp = true, quest = true,
    },
    -- position: "auras" (under the first row of auras), "below" the bar or "above" it (offset pixels
    -- up); gap: pixels clear of what's above it. Its spell name hangs below it either way.
    cast = { enabled = true, width = 220, height = 10, position = "auras", gap = 4, offset = 44, showTime = true },
    -- Status effects under the bar, in two rows with their own settings; order: which is on top
    -- ("debuffs" or "buffs"). Debuffs: mode "mine" (only yours) or "all" (yours, then others').
    auras = {
        enabled = true, order = "debuffs", spacing = 3, rowGap = 4,
        rounded = true, -- rounded icons, like FrogUI's action bar buttons (off: square)
        fold = true,    -- an empty row closes up, the rows below moving up
        font = "Interface\\AddOns\\FrogTarget\\Fonts\\SourceSans3.ttf",
        debuffs = { enabled = true, mode = "all", size = 26, max = 12, showTimer = true },
        buffs = { enabled = true, size = 22, max = 8, showTimer = true },
    },
    -- The unit's power under the health bar, or (float) over its bottom edge, `width` per cent as
    -- wide and raised `offset`; text: a template like those above, of the power (empty hides it).
    power = { enabled = false, float = true, width = 60, height = 8, offset = 0, x = 0, hideEmpty = true, text = "", textSize = 10 },
    -- Your combo points on the target (rogues; druids in cat form): a row of small bars in the
    -- look, under the bar and its power bar. spacing: extra room between them.
    combo = { enabled = true, hideEmpty = true, height = 6, spacing = 0, color = { r = 1, g = 0.82, b = 0.3 } },
    -- A second bar, the same as the target's, for your focus. Its own place, scale and width, and
    -- its own switches for the parts; the look, the text and the parts' settings are shared.
    focus = {
        enabled = false,
        hideBlizzard = true, -- hide Blizzard's focus frame while this one is on
        point = { "TOP", "UIParent", "TOP", -380, -300 },
        scale = 1,
        width = 240,
        cast = true, auras = true, power = false,
        tot = false, -- the focus's target beside it
    },
}

ns.Print = FrogLib.Util.Printer("FrogTarget", "ffd100")

-- Fills a FontString from a template for a unit (FrogLib.Unit's words, formatted engine-side, as
-- values may be secret). fake: the unlocked preview's values; power: the unit's power, not health.
local textOptions = {}
function ns.SetUnitText(text, template, unit, fake, power)
    textOptions.fake, textOptions.power = fake or nil, power
    textOptions.levelColor = ns.db.text.levelColor -- coloured by difficulty, a skull for bosses
    textOptions.classColor = true
    FrogLib.Unit.SetText(text, template, unit, textOptions)
end

function ns.Refresh()
    for _, bar in ipairs(ns.Bars or {}) do
        if bar.frame then bar:Apply() end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON then
        FrogTargetDB = FrogTargetDB or {}
        local db = FrogTargetDB
        -- 0.1 had one row for all of them: its settings go to both rows (buffs only showed with "all").
        if db.auras and db.auras.mode and not db.auras.debuffs then
            local auras = db.auras
            auras.debuffs = { enabled = true, mode = auras.mode, size = auras.size, max = auras.max, showTimer = auras.showTimer }
            auras.buffs = { enabled = auras.mode == "all", size = auras.size, max = auras.max, showTimer = auras.showTimer }
            auras.mode, auras.size, auras.max, auras.showTimer = nil, nil, nil, nil
        end
        -- 0.1.0 put the cast bar below the health bar by default; under the auras is the default
        -- now (moved once, for anyone who had the old default).
        if (db.version or 1) < 2 then
            if db.cast and db.cast.position == "below" then db.cast.position = "auras" end
            db.version = 2
        end
        FrogLib.Util.CopyDefaults(ns.defaults, db)
        ns.db = db
    elseif event == "PLAYER_LOGIN" then
        for _, bar in ipairs(ns.Bars) do bar:Init() end
    end
end)

SLASH_FROGTARGET1 = "/ft"
SlashCmdList.FROGTARGET = function() ns.Config:Toggle() end

function FrogTarget_OnCompartmentClick()
    ns.Config:Toggle()
end
