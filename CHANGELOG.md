# FrogTarget

## 0.2.2

- Settings: a dropdown shows the current choice afresh whenever its page opens. The settings controls and window now come from FrogLib, shared with Frog Wizard's other add-ons.
- Where you drag it is now kept only in its own settings, not also in the game's layout file, so the two can't disagree about where it goes.
- New: your **combo points** under the target bar, as a row of small bars in the bar's look (rogues, and druids in cat form), hidden until you have one. The status effects and a cast bar below make room for them. Its height, spacing and colour are on the Power page, and it shows a sample while unlocked.

## 0.2.1

- Casts whose spell the game hides from add-ons now show on the cast bar instead of causing an error, and after an interrupt the bar shows its sample again while unlocked.
- Hiding Blizzard's target and focus frames now holds through combat and Edit Mode: they go at once, even mid-fight, instead of waiting for the fight to end, and stay gone when the game lays them out again. It also works alongside other add-ons that hide the same frames.
- Names the game hides from add-ons (in some instances) now show, instead of stopping the bar's text from updating; a player whose class the game hides no longer causes an error in the reaction colours.
- Text with more than six words now keeps updating (it stopped).
- New text words, as XIVTarget's: `class` (a player's class in its colour, a creature's type), and `power`, `powermax`, `powerpercent`, `powertype` for the unit's mana, rage or energy (updated as it changes).
- Your own level shows plain rather than in a difficulty colour, as the game's frames show it; a level of 0 shows as "??".
- Under the hood: text, colours, icons and the click buttons are FrogLib's, shared with XIVTarget and FrogFrames.

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
