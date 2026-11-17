local _, ns = ...
local Config = {}
ns.Config = Config

local WIDTH, HEIGHT = 500, 720

-- The controls are FrogLib's (UI.lua); every change calls ns.Refresh().
local UI = FrogLib.UI.Kit({ refresh = function() ns.Refresh() end })
local Label, Checkbox, Stepper, Dropdown, Options, ColorSwatch, TextBox, Placer =
    UI.Label, UI.Checkbox, UI.Stepper, UI.Dropdown, UI.Options, UI.ColorSwatch, UI.TextBox, UI.Placer

local AURA_MODES = Options("mine", "Only mine", "all", "Mine, then everyone else's")
local ICON_ANCHORS = Options("left", "Left of the name", "right", "Past the end of the bar", "above", "Above the name")
local COLOR_MODES = Options("reaction", "Hostile / neutral / friendly (players by class)",
    "xiv", "Fighting / not yet / friendly", "fixed", "Always the bar colour")
local STYLES = Options("classic", "Classic (1.x)", "modern", "Modern", "forever", "Forever")

------------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------------

function Config:BuildBar(page)
    local db = ns.db
    local place = Placer()
    place(Checkbox(page, "Unlock to move (drag the bars; shows previews)",
        function() return not db.locked end, function(value) db.locked = not value end), 28)
    place(Checkbox(page, "Click to target, right-click for the menu", db, "clicks"), 28)
    place(Checkbox(page, "Hide Blizzard's target frame", db, "hideTargetFrame"), 34)
    place(Stepper(page, "Scale", 0.5, 2, 0.05, db, "scale", "%.2f"), 26)
    place(Stepper(page, "Width", 150, 900, 10, db, "width"), 26)
    place(Stepper(page, "Bar height", 2, 20, 1, db, "height"), 32)
    place(Dropdown(page, "Look", STYLES, db, "style"), 30)
    place(Dropdown(page, "Bar texture", function()
        local groups = ns.Media:List("statusbar")
        table.insert(groups, 1, { items = { { name = "The look's own", path = "" } } })
        return groups
    end, db, "texture"), 30)
    place(Stepper(page, "Forever frame thickness", 1, 3, 1, db, "frameThickness"), 26)
    place(ColorSwatch(page, "Classic border tint", db, "borderColor"), 30)
    place(Dropdown(page, "Colouring", COLOR_MODES, db, "colorMode"), 30)
    place(ColorSwatch(page, "Bar colour (fixed mode)", db, "color"), 30)
    place(Checkbox(page, "Show the target's shields (absorbs)", db, "absorb"), 34)

    local cast = db.cast
    place(Label(page, "Cast bar"), 22)
    place(Checkbox(page, "Show the target's casts", cast, "enabled"), 28)
    place(Stepper(page, "Cast bar width", 60, 400, 10, cast, "width"), 26)
    place(Stepper(page, "Cast bar height", 2, 12, 1, cast, "height"), 26)
    place(Dropdown(page, "Cast bar", Options("auras", "Under the buffs and debuffs", "below", "Below the bar",
        "above", "Above the bar"), cast, "position"), 30)
    place(Stepper(page, "Gap above it", 0, 30, 1, cast, "gap"), 26)
    place(Stepper(page, "Raised by (above)", 20, 100, 2, cast, "offset"), 26)
    place(Checkbox(page, "Show remaining cast time", cast, "showTime"), 28)
end

function Config:BuildText(page)
    local text = ns.db.text
    local place = Placer()
    place(TextBox(page, "Above bar, left", text, "left"), 28)
    place(TextBox(page, "Above bar, right", text, "right"), 30)
    place(UI.Help(page, "Words: |cffffd100level|r, |cffffd100name|r, |cffffd100class|r, |cffffd100value|r, "
        .. "|cffffd100max|r, |cffffd100percent|r (|cffffd100percent.1|r for a decimal), |cffffd100power|r, "
        .. "|cffffd100powermax|r, |cffffd100powerpercent|r, |cffffd100powertype|r. Leave empty to hide.",
        WIDTH - 40), 44, 4)
    place(Dropdown(page, "Font", function() return ns.Media:List("font") end, text, "font"), 30)
    place(Dropdown(page, "Font outline", UI.OUTLINES, text, "outline"), 30)
    place(Stepper(page, "Text size", 8, 24, 1, text, "size"), 28)
    place(Checkbox(page, "Tint the text to match the bar", text, "tinted"), 28)
    place(Checkbox(page, "Colour the level by difficulty, with a skull for bosses", text, "levelColor"), 28)
end

function Config:BuildPower(page)
    local power = ns.db.power
    local place = Placer()
    place(Checkbox(page, "Show the target's power bar (mana, rage, energy)", power, "enabled"), 28)
    place(Checkbox(page, "Float it over the bottom edge of the health bar", power, "float"), 26)
    place(Checkbox(page, "Hide it while it's empty (an enemy that hasn't built any rage)", power, "hideEmpty"), 30)
    place(Stepper(page, "Width (% of the bar)", 20, 100, 5, power, "width", "%d%%"), 26)
    place(Stepper(page, "Move up / down", -20, 20, 1, power, "offset"), 26)
    place(Stepper(page, "Move left / right", -200, 200, 2, power, "x"), 26)
    place(UI.Help(page, "Width and moving it are for a floating bar; otherwise it runs the full width "
        .. "under the health bar. Shift-click + or - for ten steps at once.", WIDTH - 40), 30, 4)
    place(Stepper(page, "Height", 2, 20, 1, power, "height"), 32)
    place(TextBox(page, "Text on it", power, "text"), 30)
    place(UI.Help(page, "Words: |cffffd100value|r, |cffffd100max|r, |cffffd100percent|r (the power's), "
        .. "|cffffd100name|r, |cffffd100level|r. Leave empty to hide.", WIDTH - 40), 30, 4)
    place(Stepper(page, "Text size", 6, 20, 1, power, "textSize"), 34)
    place(Label(page, "The focus bar's power bar is switched on on the Focus page.", "GameFontDisableSmall"), 26, 4)

    -- Combo points (rogues, druids in cat form), on the target bar under the power bar.
    local combo = ns.db.combo
    place(Label(page, "Combo points"), 22)
    place(Checkbox(page, "Show your combo points under the target bar (rogues, druids in cat form)",
        combo, "enabled"), 26)
    place(Checkbox(page, "Hidden until you have one", combo, "hideEmpty"), 26, 16)
    place(Stepper(page, "Height", 2, 20, 1, combo, "height"), 26)
    place(Stepper(page, "Extra gap between them", 0, 20, 1, combo, "spacing"), 26)
    place(ColorSwatch(page, "Colour", combo, "color"), 28)
end

function Config:BuildFocus(page)
    local focus = ns.db.focus
    local place = Placer()
    place(Checkbox(page, "Show a bar for your focus", focus, "enabled"), 28)
    place(Checkbox(page, "Hide Blizzard's focus frame while it's on", focus, "hideBlizzard"), 34)
    place(Stepper(page, "Scale", 0.5, 2, 0.05, focus, "scale", "%.2f"), 26)
    place(Stepper(page, "Width", 150, 900, 10, focus, "width"), 34)
    place(Checkbox(page, "Show the focus's casts", focus, "cast"), 28)
    place(Checkbox(page, "Show the focus's status effects", focus, "auras"), 28)
    place(Checkbox(page, "Show the focus's power bar", focus, "power"), 28)
    place(Checkbox(page, "Show your focus's target beside it", focus, "tot"), 34)
    place(UI.Help(page, "It uses the look, text, icons, and the cast, status, power and ToT settings of the "
        .. "other pages. Unlock on the Bar page to move it: it shows a sample when you have no focus.",
        WIDTH - 40), 40, 4)
end

function Config:BuildToT(page)
    local tot = ns.db.tot
    local place = Placer()
    place(Checkbox(page, "Show your target's target beside the bar", tot, "enabled"), 34)
    place(Stepper(page, "Width", 60, 400, 10, tot, "width"), 26)
    place(Stepper(page, "Gap from target bar", 0, 80, 2, tot, "gap"), 32)
    place(TextBox(page, "Text", tot, "template"), 28)
end

function Config:BuildAuras(page)
    local auras = ns.db.auras
    local place = Placer()
    place(Checkbox(page, "Show status effects under the target bar", auras, "enabled"), 30)
    place(Dropdown(page, "Which row on top", Options("debuffs", "Debuffs, then buffs", "buffs", "Buffs, then debuffs"),
        auras, "order"), 30)
    place(Checkbox(page, "Close up an empty row (the other moves up)", auras, "fold"), 28)
    place(Checkbox(page, "Rounded icons, like the action bar buttons", auras, "rounded"), 28)
    place(Stepper(page, "Gap between rows", 0, 20, 1, auras, "rowGap"), 26)
    place(Stepper(page, "Spacing", 0, 12, 1, auras, "spacing"), 26)
    place(Dropdown(page, "Timer & stack font", function() return ns.Media:List("font") end, auras, "font"), 34)

    for _, row in ipairs({ { "debuffs", "Debuffs" }, { "buffs", "Buffs" } }) do
        local settings = auras[row[1]]
        place(Label(page, row[2]), 22)
        place(Checkbox(page, "Show " .. row[2]:lower(), settings, "enabled"), 26, 12)
        if row[1] == "debuffs" then
            place(Dropdown(page, "Whose", AURA_MODES, settings, "mode"), 30, 12)
        end
        place(Checkbox(page, "Timers under the icons", settings, "showTimer"), 26, 12)
        place(Stepper(page, "Icon size", 14, 48, 2, settings, "size"), 26, 12)
        place(Stepper(page, "Most shown", 1, 40, 1, settings, "max"), 32, 12)
    end
end

function Config:BuildIcons(page)
    local icons = ns.db.icons
    local place = Placer()
    place(Checkbox(page, "Show icons beside the name", icons, "enabled"), 34)
    place(Stepper(page, "Icon size", 10, 64, 2, icons, "size"), 26)
    place(Dropdown(page, "Position", ICON_ANCHORS, icons, "anchor"), 30)
    place(Stepper(page, "Move left / right", -300, 300, 2, icons, "x"), 26)
    place(Stepper(page, "Move up / down", -100, 100, 2, icons, "y"), 34)
    place(Label(page, "Unlock the bar (Bar page) to see sample icons while you place them.", "GameFontDisableSmall"), 24, 4)
    for _, icon in ipairs({
        { "raid", "Raid marker" },
        { "leader", "Group leader / assistant" },
        { "role", "Group role (tank, healer, damage)" },
        { "pvp", "PvP flag (players)" },
        { "quest", "Quest target" },
    }) do
        place(Checkbox(page, icon[2], icons, icon[1]), 28, 16)
    end
end

function Config:Build()
    self.frame = UI.Window("FrogTargetConfig", "FrogTarget", WIDTH, HEIGHT, {
        { "bar", "Bar", function(page) self:BuildBar(page) end },
        { "text", "Text", function(page) self:BuildText(page) end },
        { "power", "Power", function(page) self:BuildPower(page) end },
        { "tot", "ToT", function(page) self:BuildToT(page) end },
        { "auras", "Status", function(page) self:BuildAuras(page) end },
        { "icons", "Icons", function(page) self:BuildIcons(page) end },
        { "focus", "Focus", function(page) self:BuildFocus(page) end },
    }, { tabWidth = 64, tabGap = 3 })
end

function Config:Toggle()
    if not self.frame then
        self:Build()
        self.frame:Show()
        return
    end
    self.frame:SetShown(not self.frame:IsShown())
end

-- Its entry in the game's Options > AddOns list (Options.lua).
FrogLib.Options.Add("FrogTarget", ns, {
    open = function()
        if not (Config.frame and Config.frame:IsShown()) then Config:Toggle() end
    end,
    commands = { { "/ft", "open or close the settings" } },
})
