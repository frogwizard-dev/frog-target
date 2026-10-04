local ADDON, ns = ...

-- The bar textures and fonts the settings offer, and setting a font safely: FrogLib's Media
-- (Libs\FrogLib\Media.lua), with this addon's own fonts listed first.
local FONTS = "Interface\\AddOns\\" .. ADDON .. "\\Fonts\\"
-- Fonts\XIV.ttf ships as M PLUS 1p Medium; replace the file (keeping the name) to use another
-- font. WoW can't list a folder's files, so the name has to be fixed. It's also the fallback.
ns.Media = FrogLib.Media.New({
    fonts = {
        { "Michroma (wide)", FONTS .. "Michroma.ttf" }, -- wide, like FFXIV's gauge numbers
        { "Source Sans 3 (Myriad-like)", FONTS .. "SourceSans3.ttf" },
        { "M PLUS 1p", FONTS .. "XIV.ttf" },
    },
    fallbackFont = FONTS .. "XIV.ttf",
})
