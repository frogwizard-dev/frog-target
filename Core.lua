local ADDON, ns = ...

-- FrogTarget: XIVTarget's target bar (the name above a long bar, the cast floating over its
-- right half, auras below, your target's target alongside) drawn in WoW's own art, in three
-- looks: "classic" (1.x), "modern" (plain, a 1px edge) and "forever" (the cooldown manager's
-- bars). Gauge.lua draws the bars; the rest is XIVTarget's. Target.lua makes the same bar for
-- the focus too (off by default).
ns.defaults = {
    locked = true,
    point = { "TOP", "UIParent", "TOP", 0, -140 },
    scale = 1,
    width = 360,
    height = 12,
    -- "classic": the 1.x status bar in the grey stone border; "modern": a plain fill with a 1px
    -- black edge; "forever": the cooldown manager's bar in its own frame. texture "" uses the
    -- look's own bar texture.
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
    -- position: "auras" (under the first row of auras), "below" the health bar (the auras move
    -- down to make room) or "above" it (floating offset pixels up); gap: pixels clear of what's
    -- above it. Its spell name hangs below it either way.
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
    -- The unit's power (mana, rage, energy) on a bar of its own: under the health bar, full width,
    -- or (float) centred on the health bar's bottom edge, drawn over it, `width` per cent as wide
    -- and raised `offset` pixels. text: a template like the ones above (value, max, percent are
    -- the power's); empty hides it.
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

ns.issecret = FrogLib.issecret

ns.Print = FrogLib.Util.Printer("FrogTarget", "ffd100")

local CopyDefaults = FrogLib.Util.CopyDefaults

-- Text templates and their words (name, level, class, value, max, percent, power...):
-- FrogLib.Text and FrogLib.Unit, shared with XIVTarget and FrogFrames. Values may be secret, so
-- they're only ever formatted engine-side by SetFormattedText.
-- Fills a FontString from a template for a unit. fake = values for the unlocked preview;
-- power = value, max and percent are the unit's power rather than its health.
local textOpts = {}
function ns.SetUnitText(fs, template, unit, fake, power)
    textOpts.fake, textOpts.power = fake or nil, power
    textOpts.levelColor = ns.db.text.levelColor -- coloured by difficulty, a skull for bosses
    textOpts.classColor = true
    FrogLib.Unit.SetText(fs, template, unit, textOpts)
end

function ns.Refresh()
    for _, bar in ipairs(ns.Bars or {}) do
        if bar.frame then bar:Apply() end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        FrogTargetDB = FrogTargetDB or {}
        local db = FrogTargetDB
        -- 0.1.0 put the cast bar below the health bar by default; under the auras is the default
        -- now (moved once, for anyone who had the old default).
        -- 0.1 had one row for all of them: its settings go to both rows (buffs only showed with "all").
        if db.auras and db.auras.mode and not db.auras.debuffs then
            local a = db.auras
            a.debuffs = { enabled = true, mode = a.mode, size = a.size, max = a.max, showTimer = a.showTimer }
            a.buffs = { enabled = a.mode == "all", size = a.size, max = a.max, showTimer = a.showTimer }
            a.mode, a.size, a.max, a.showTimer = nil, nil, nil, nil
        end
        if (db.version or 1) < 2 then
            if db.cast and db.cast.position == "below" then db.cast.position = "auras" end
            db.version = 2
        end
        CopyDefaults(ns.defaults, db)
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
