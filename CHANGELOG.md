# FrogTarget

## 0.2.0

- A focus bar: the same bar as the target's, for your focus, with its own place (move it with the same unlock, grid and centre snapping), scale and width, and its own switches for its cast bar, status effects, power bar and your focus's target. It shares the look and text with the target bar. Off by default: switch it on on the new **Focus** page, which can also hide Blizzard's focus frame while it's on.
- A power bar (mana, rage, energy) for the target and the focus, on the new **Power** page. Off by default. It can run the full width under the health bar, or float: a narrower bar centred on the health bar's bottom edge, half over it, drawn on top in its own border in all three looks. Set its width (as a share of the health bar), height and position (up / down and left / right), and put text on it (value, max, percent) the same way as the bar's other text.
- The power bar hides while it's empty, such as an enemy warrior that hasn't built any rage, and comes back as soon as there's some. After it empties, it waits a few seconds before going. Can be turned off.
- The level is coloured by how hard the enemy is for you, and bosses show a skull, as on the game's own target frame. Can be turned off on the Text page.
- Shift-click a setting's + or - to change it ten steps at a time.
- While unlocked, the focus bar, the power bar and its text show samples like the rest.
- The settings window is a little wider to fit the new pages.
- The entry in Options > AddOns lists the right command, /ft.

## 0.1.0

- First version: XIVTarget's target bar (the name and level above a long bar, the enemy's cast floating over its right half, auras below, your target's target alongside, click to target or open the menu) drawn in WoW's own art.
- Three looks, switched on the Bar page: **Classic**, the 1.x status bar texture in the grey stone border; **Modern**, a plain fill with a 1px black edge; and **Forever**, the cooldown manager's bar in a Forever-style frame (a dark outline, a thin metallic rim, cut corners). The bar texture can also be any other, including FrogUI's.
- Bars coloured by reaction (hostile red, neutral yellow, friendly green), players in their class colour and tapped enemies grey; or "fighting / not yet / friendly", or one fixed colour.
- Cast bars with WoW's spark.
- While unlocked: a sample row of buffs and debuffs and a sample cast, so the layout can be judged without a target that has them.
- Names include the surname on Forever, as the game's own frames show them.
- Buffs and debuffs in two rows, each with its own settings (on/off, icon size, how many, timers; for debuffs, only yours or everyone's), and a choice of which row is on top.
- Rounded aura icons, the shape of FrogUI's action bar buttons, with a 2px border and the cooldown sweep following the corners (or square, on the Status page).
- An empty aura row closes up and the other moves up (the cast bar too, when it's under them), opening again when something lands. On by default, on the Status page.
