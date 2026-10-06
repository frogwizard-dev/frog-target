local _, ns = ...
local Config = {}
ns.Config = Config

local W, H = 500, 720

-- The controls are FrogLib's (UI.lua); every change calls ns.Refresh().
local UI = FrogLib.UI.Kit({ refresh = function() ns.Refresh() end })
local Label, Button, Checkbox, Stepper, Dropdown, Options, ColorSwatch, TextBox, Placer =
    UI.Label, UI.Button, UI.Checkbox, UI.Stepper, UI.Dropdown, UI.Options, UI.ColorSwatch, UI.TextBox, UI.Placer

local OUTLINES = Options("", "None", "OUTLINE", "Outline", "THICKOUTLINE", "Thick outline")
local AURA_MODES = Options("mine", "Only mine", "all", "Mine, then everyone else's")
local ICON_ANCHORS = Options("left", "Left of the name", "right", "Past the end of the bar", "above", "Above the name")
local COLOR_MODES = Options("reaction", "Hostile / neutral / friendly (players by class)",
    "xiv", "Fighting / not yet / friendly", "fixed", "Always the bar colour")
local STYLES = Options("classic", "Classic (1.x)", "modern", "Modern", "forever", "Forever")

------------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------------

function Config:BuildBar(p)
    local db = ns.db
    local place = Placer()
    place(Checkbox(p, "Unlock to move (drag the bars; shows previews)",
        function() return not db.locked end, function(v) db.locked = not v end), 28)
    place(Checkbox(p, "Click to target, right-click for the menu",
        function() return db.clicks end, function(v) db.clicks = v end), 28)
    place(Checkbox(p, "Hide Blizzard's target frame",
        function() return db.hideTargetFrame end, function(v) db.hideTargetFrame = v end), 34)
    place(Stepper(p, "Scale", 0.5, 2, 0.05, function() return db.scale end, function(v) db.scale = v end, "%.2f"), 26)
    place(Stepper(p, "Width", 150, 900, 10, function() return db.width end, function(v) db.width = v end), 26)
    place(Stepper(p, "Bar height", 2, 20, 1, function() return db.height end, function(v) db.height = v end), 32)
    place(Dropdown(p, "Look", STYLES, function() return db.style end, function(v) db.style = v end), 30)
    place(Dropdown(p, "Bar texture", function()
        local groups = ns.Media:List("statusbar")
        table.insert(groups, 1, { items = { { name = "The look's own", path = "" } } })
        return groups
    end, function() return db.texture end, function(v) db.texture = v end), 30)
    place(Stepper(p, "Forever frame thickness", 1, 3, 1, function() return db.frameThickness end,
        function(v) db.frameThickness = v end), 26)
    place(ColorSwatch(p, "Classic border tint", function() return db.borderColor end,
        function(r, g, b) db.borderColor = { r = r, g = g, b = b } end), 30)
    place(Dropdown(p, "Colouring", COLOR_MODES, function() return db.colorMode end,
        function(v) db.colorMode = v end), 30)
    place(ColorSwatch(p, "Bar colour (fixed mode)", function() return db.color end,
        function(r, g, b) db.color = { r = r, g = g, b = b } end), 30)
    place(Checkbox(p, "Show the target's shields (absorbs)",
        function() return db.absorb end, function(v) db.absorb = v end), 34)

    place(Label(p, "Cast bar"), 22)
    place(Checkbox(p, "Show the target's casts",
        function() return db.cast.enabled end, function(v) db.cast.enabled = v end), 28)
    place(Stepper(p, "Cast bar width", 60, 400, 10, function() return db.cast.width end, function(v) db.cast.width = v end), 26)
    place(Stepper(p, "Cast bar height", 2, 12, 1, function() return db.cast.height end, function(v) db.cast.height = v end), 26)
    place(Dropdown(p, "Cast bar", Options("auras", "Under the buffs and debuffs", "below", "Below the bar",
        "above", "Above the bar"),
        function() return db.cast.position end, function(v) db.cast.position = v end), 30)
    place(Stepper(p, "Gap above it", 0, 30, 1, function() return db.cast.gap end, function(v) db.cast.gap = v end), 26)
    place(Stepper(p, "Raised by (above)", 20, 100, 2, function() return db.cast.offset end, function(v) db.cast.offset = v end), 26)
    place(Checkbox(p, "Show remaining cast time",
        function() return db.cast.showTime end, function(v) db.cast.showTime = v end), 28)
end

function Config:BuildText(p)
    local t = ns.db.text
    local place = Placer()
    place(TextBox(p, "Above bar, left", function() return t.left end, function(v) t.left = v end), 28)
    place(TextBox(p, "Above bar, right", function() return t.right end, function(v) t.right = v end), 30)
    local help = Label(p, "Words: |cffffd100level|r, |cffffd100name|r, |cffffd100class|r, |cffffd100value|r, "
        .. "|cffffd100max|r, |cffffd100percent|r (|cffffd100percent.1|r for a decimal), |cffffd100power|r, "
        .. "|cffffd100powermax|r, |cffffd100powerpercent|r, |cffffd100powertype|r. Leave empty to hide.",
        "GameFontDisableSmall")
    help:SetWidth(W - 40)
    help:SetJustifyH("LEFT")
    place(help, 44, 4)
    place(Dropdown(p, "Font", function() return ns.Media:List("font") end,
        function() return t.font end, function(v) t.font = v end), 30)
    place(Dropdown(p, "Font outline", OUTLINES, function() return t.outline end, function(v) t.outline = v end), 30)
    place(Stepper(p, "Text size", 8, 24, 1, function() return t.size end, function(v) t.size = v end), 28)
    place(Checkbox(p, "Tint the text to match the bar",
        function() return t.tinted end, function(v) t.tinted = v end), 28)
    place(Checkbox(p, "Colour the level by difficulty, with a skull for bosses",
        function() return t.levelColor end, function(v) t.levelColor = v end), 28)
end

function Config:BuildPower(p)
    local cfg = ns.db.power
    local place = Placer()
    place(Checkbox(p, "Show the target's power bar (mana, rage, energy)",
        function() return cfg.enabled end, function(v) cfg.enabled = v end), 28)
    place(Checkbox(p, "Float it over the bottom edge of the health bar",
        function() return cfg.float end, function(v) cfg.float = v end), 26)
    place(Checkbox(p, "Hide it while it's empty (an enemy that hasn't built any rage)",
        function() return cfg.hideEmpty end, function(v) cfg.hideEmpty = v end), 30)
    place(Stepper(p, "Width (% of the bar)", 20, 100, 5, function() return cfg.width end,
        function(v) cfg.width = v end, "%d%%"), 26)
    place(Stepper(p, "Move up / down", -20, 20, 1, function() return cfg.offset end,
        function(v) cfg.offset = v end), 26)
    place(Stepper(p, "Move left / right", -200, 200, 2, function() return cfg.x end,
        function(v) cfg.x = v end), 26)
    local help = Label(p, "Width and moving it are for a floating bar; otherwise it runs the full width "
        .. "under the health bar. Shift-click + or - for ten steps at once.", "GameFontDisableSmall")
    help:SetWidth(W - 40)
    help:SetJustifyH("LEFT")
    place(help, 30, 4)
    place(Stepper(p, "Height", 2, 20, 1, function() return cfg.height end, function(v) cfg.height = v end), 32)
    place(TextBox(p, "Text on it", function() return cfg.text end, function(v) cfg.text = v end), 30)
    local words = Label(p, "Words: |cffffd100value|r, |cffffd100max|r, |cffffd100percent|r (the power's), "
        .. "|cffffd100name|r, |cffffd100level|r. Leave empty to hide.", "GameFontDisableSmall")
    words:SetWidth(W - 40)
    words:SetJustifyH("LEFT")
    place(words, 30, 4)
    place(Stepper(p, "Text size", 6, 20, 1, function() return cfg.textSize end, function(v) cfg.textSize = v end), 34)
    local more = Label(p, "The focus bar's power bar is switched on on the Focus page.", "GameFontDisableSmall")
    place(more, 26, 4)

    -- Combo points (rogues, druids in cat form), on the target bar under the power bar.
    local combo = ns.db.combo
    place(Label(p, "Combo points"), 22)
    place(Checkbox(p, "Show your combo points under the target bar (rogues, druids in cat form)",
        function() return combo.enabled end, function(v) combo.enabled = v end), 26)
    place(Checkbox(p, "Hidden until you have one", function() return combo.hideEmpty end,
        function(v) combo.hideEmpty = v end), 26, 16)
    place(Stepper(p, "Height", 2, 20, 1, function() return combo.height end, function(v) combo.height = v end), 26)
    place(Stepper(p, "Extra gap between them", 0, 20, 1, function() return combo.spacing end,
        function(v) combo.spacing = v end), 26)
    place(ColorSwatch(p, "Colour", function() return combo.color end,
        function(r, g, b) combo.color = { r = r, g = g, b = b } end), 28)
end

function Config:BuildFocus(p)
    local cfg = ns.db.focus
    local place = Placer()
    place(Checkbox(p, "Show a bar for your focus",
        function() return cfg.enabled end, function(v) cfg.enabled = v end), 28)
    place(Checkbox(p, "Hide Blizzard's focus frame while it's on",
        function() return cfg.hideBlizzard end, function(v) cfg.hideBlizzard = v end), 34)
    place(Stepper(p, "Scale", 0.5, 2, 0.05, function() return cfg.scale end, function(v) cfg.scale = v end, "%.2f"), 26)
    place(Stepper(p, "Width", 150, 900, 10, function() return cfg.width end, function(v) cfg.width = v end), 34)
    place(Checkbox(p, "Show the focus's casts",
        function() return cfg.cast end, function(v) cfg.cast = v end), 28)
    place(Checkbox(p, "Show the focus's status effects",
        function() return cfg.auras end, function(v) cfg.auras = v end), 28)
    place(Checkbox(p, "Show the focus's power bar",
        function() return cfg.power end, function(v) cfg.power = v end), 28)
    place(Checkbox(p, "Show your focus's target beside it",
        function() return cfg.tot end, function(v) cfg.tot = v end), 34)
    local help = Label(p, "It uses the look, text, icons, and the cast, status, power and ToT settings of the "
        .. "other pages. Unlock on the Bar page to move it: it shows a sample when you have no focus.",
        "GameFontDisableSmall")
    help:SetWidth(W - 40)
    help:SetJustifyH("LEFT")
    place(help, 40, 4)
end

function Config:BuildToT(p)
    local cfg = ns.db.tot
    local place = Placer()
    place(Checkbox(p, "Show your target's target beside the bar",
        function() return cfg.enabled end, function(v) cfg.enabled = v end), 34)
    place(Stepper(p, "Width", 60, 400, 10, function() return cfg.width end, function(v) cfg.width = v end), 26)
    place(Stepper(p, "Gap from target bar", 0, 80, 2, function() return cfg.gap end, function(v) cfg.gap = v end), 32)
    place(TextBox(p, "Text", function() return cfg.template end, function(v) cfg.template = v end), 28)
end

function Config:BuildAuras(p)
    local cfg = ns.db.auras
    local place = Placer()
    place(Checkbox(p, "Show status effects under the target bar",
        function() return cfg.enabled end, function(v) cfg.enabled = v end), 30)
    place(Dropdown(p, "Which row on top", Options("debuffs", "Debuffs, then buffs", "buffs", "Buffs, then debuffs"),
        function() return cfg.order end, function(v) cfg.order = v end), 30)
    place(Checkbox(p, "Close up an empty row (the other moves up)",
        function() return cfg.fold end, function(v) cfg.fold = v end), 28)
    place(Checkbox(p, "Rounded icons, like the action bar buttons",
        function() return cfg.rounded end, function(v) cfg.rounded = v end), 28)
    place(Stepper(p, "Gap between rows", 0, 20, 1, function() return cfg.rowGap end, function(v) cfg.rowGap = v end), 26)
    place(Stepper(p, "Spacing", 0, 12, 1, function() return cfg.spacing end, function(v) cfg.spacing = v end), 26)
    place(Dropdown(p, "Timer & stack font", function() return ns.Media:List("font") end,
        function() return cfg.font end, function(v) cfg.font = v end), 34)

    for _, row in ipairs({ { "debuffs", "Debuffs" }, { "buffs", "Buffs" } }) do
        local r = cfg[row[1]]
        place(Label(p, row[2]), 22)
        place(Checkbox(p, "Show " .. row[2]:lower(), function() return r.enabled end,
            function(v) r.enabled = v end), 26, 12)
        if row[1] == "debuffs" then
            place(Dropdown(p, "Whose", AURA_MODES, function() return r.mode end, function(v) r.mode = v end), 30, 12)
        end
        place(Checkbox(p, "Timers under the icons", function() return r.showTimer end,
            function(v) r.showTimer = v end), 26, 12)
        place(Stepper(p, "Icon size", 14, 48, 2, function() return r.size end, function(v) r.size = v end), 26, 12)
        place(Stepper(p, "Most shown", 1, 40, 1, function() return r.max end, function(v) r.max = v end), 32, 12)
    end
end

function Config:BuildIcons(p)
    local cfg = ns.db.icons
    local place = Placer()
    place(Checkbox(p, "Show icons beside the name",
        function() return cfg.enabled end, function(v) cfg.enabled = v end), 34)
    place(Stepper(p, "Icon size", 10, 64, 2, function() return cfg.size end, function(v) cfg.size = v end), 26)
    place(Dropdown(p, "Position", ICON_ANCHORS, function() return cfg.anchor end, function(v) cfg.anchor = v end), 30)
    place(Stepper(p, "Move left / right", -300, 300, 2, function() return cfg.x end, function(v) cfg.x = v end), 26)
    place(Stepper(p, "Move up / down", -100, 100, 2, function() return cfg.y end, function(v) cfg.y = v end), 34)
    local help = Label(p, "Unlock the bar (Bar page) to see sample icons while you place them.", "GameFontDisableSmall")
    place(help, 24, 4)
    for _, def in ipairs({
        { "raid", "Raid marker" },
        { "leader", "Group leader / assistant" },
        { "role", "Group role (tank, healer, damage)" },
        { "pvp", "PvP flag (players)" },
        { "quest", "Quest target" },
    }) do
        local key = def[1]
        place(Checkbox(p, def[2], function() return cfg[key] end, function(v) cfg[key] = v end), 28, 16)
    end
end

function Config:Build()
    self.frame = UI.Window("FrogTargetConfig", "FrogTarget", W, H, {
        { "bar", "Bar", function(p) self:BuildBar(p) end },
        { "text", "Text", function(p) self:BuildText(p) end },
        { "power", "Power", function(p) self:BuildPower(p) end },
        { "tot", "ToT", function(p) self:BuildToT(p) end },
        { "auras", "Status", function(p) self:BuildAuras(p) end },
        { "icons", "Icons", function(p) self:BuildIcons(p) end },
        { "focus", "Focus", function(p) self:BuildFocus(p) end },
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
