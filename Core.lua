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
        -- Templates: words level, name, value, max, percent (percent.1 for a decimal).
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

ns.issecret = issecretvalue or function() return false end

function ns.Print(...)
    print("|cffffd100FrogTarget|r:", ...)
end

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- Text templates: "Lv level name" -> ("Lv %s %s", {level, name}). Same scheme as
-- PersonalResourceTweaks, plus the level and name words. Values may be secret, so they're
-- only ever formatted engine-side by SetFormattedText.
local compiled = {}
function ns.Compile(template)
    local c = compiled[template]
    if c then return c end
    local args = {}
    local pattern = template:gsub("%%", "%%%%")
    pattern = pattern:gsub("||", "|")
    pattern = pattern:gsub("|", "||")
    pattern = pattern:gsub("(%a+)(%.?%d*)", function(word, suffix)
        local w = word:lower()
        if w == "name" or w == "level" then
            args[#args + 1] = w
            return "%s" .. suffix
        elseif w == "value" or w == "max" then
            args[#args + 1] = w
            return "%d" .. suffix
        elseif w == "percent" then
            args[#args + 1] = "percent"
            local places = tonumber(suffix:match("^%.(%d)"))
            if places then return "%." .. math.min(places, 3) .. "f%%" end
            return "%d%%" .. suffix
        end
    end)
    c = { pattern = pattern, args = args }
    compiled[template] = c
    return c
end

-- The level as the game's target frame shows it (text.levelColor): in the colour for how hard
-- the unit is for you (grey, green, yellow, orange, red), or a skull when it's too high to show.
-- The colour codes sit inside the text, so they win over a tinted text colour.
local SKULL = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:0|t"

local function Level(unit)
    local level = UnitLevel(unit)
    if ns.issecret(level) then return level end
    local coloured = ns.db.text.levelColor
    if not level or level < 0 then return coloured and SKULL or "??" end -- skull-level bosses
    if coloured and GetCreatureDifficultyColor then
        local c = GetCreatureDifficultyColor(level)
        if c then
            return string.format("|cff%02x%02x%02x%d|r", c.r * 255, c.g * 255, c.b * 255, level)
        end
    end
    return tostring(level)
end

local function HealthPercent(unit)
    if UnitHealthPercent and CurveConstants then
        return UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    end
    local h, m = UnitHealth(unit), UnitHealthMax(unit)
    if ns.issecret(h) or ns.issecret(m) or m == 0 then return 0 end
    return h / m * 100
end

local function PowerPercent(unit)
    if UnitPowerPercent and CurveConstants then
        local ok, p = pcall(UnitPowerPercent, unit, nil, false, CurveConstants.ScaleTo100)
        if ok and (ns.issecret(p) or p) then return p end
    end
    local v, m = UnitPower(unit), UnitPowerMax(unit)
    if ns.issecret(v) or ns.issecret(m) or m == 0 then return 0 end
    return v / m * 100
end

-- A unit's name as the game's own frames show it: on Forever that includes the surname
-- (GetUnitName's second argument), where UnitName gives only the first name.
local function FullName(unit)
    if GetUnitName then
        local ok, name = pcall(GetUnitName, unit, true)
        if ok and name then return name end
    end
    return UnitName(unit)
end

-- Fills a FontString from a template for a unit. fake = values for the unlocked preview;
-- power = value, max and percent are the unit's power rather than its health.
function ns.SetUnitText(fs, template, unit, fake, power)
    if not template or strtrim(template) == "" then
        fs:Hide()
        return
    end
    fs:Show()
    local vals = fake
    if not vals then
        vals = { name = FullName(unit), level = Level(unit) }
        if power then
            vals.value, vals.max, vals.percent = UnitPower(unit), UnitPowerMax(unit), PowerPercent(unit)
        else
            vals.value, vals.max, vals.percent = UnitHealth(unit), UnitHealthMax(unit), HealthPercent(unit)
        end
    end
    local c = ns.Compile(template)
    local a = c.args
    pcall(fs.SetFormattedText, fs, c.pattern, vals[a[1]], vals[a[2]], vals[a[3]], vals[a[4]], vals[a[5]], vals[a[6]])
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
