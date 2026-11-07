# weapons (loadout) and shop screens

Status: approved

## weapons

goal: pick a blaster and see why it's different, in a few seconds.

```
[X] WEAPONS                                          [coins][gems]
[blaster list]   [        big 3d gun, slowly turning        ]   [name, rarity chip]
                 [  rarity glow floor under it (no circle)  ]   [stat bars]
                                                               [what it's good at]
                 [ EQUIP (green) ]  [ SKINS (secondary) ]      [price / owned]
```

- **list rows**: gun icon, name, a rarity colour strip on the left edge (common grey, rare blue, epic purple, legendary gold). equipped row: gold outline + "EQUIPPED" tag. locked row: dimmed with a lock glyph and its price
- **centre**: drop the big grey circle. the gun turns slowly on a soft glow in its rarity colour, bigger and closer
- **right panel**: rarity as a coloured chip, the 5 stat bars in gold (not 5 blues), plus one line "best for: long range" so the stats mean something
- **buttons**: owned and not equipped: EQUIP (primary green). already equipped: "EQUIPPED" (owned style, not clickable). locked: BUY 1,200 coins (primary green) or the gem price
- empty space under the stats filled by the "best for" line and the skin preview row (small swatches of owned skins)

## shop

goal: make it obvious what you can buy, and make owned things step back.

- **OWNED buttons become the owned style** (dark, dim text, a tick), never green. only things you can buy keep a green price button
- cards keep their 3d art (it's good). the card title stays caps, the subtitle ("GAME PASS · FOREVER") goes text-dim, and the description wraps to two lines instead of cutting off
- **BEST** tag stays, in gold not red
- left tabs: the selected tab is a gold left edge and gold text, not a big blue pill
- empty tab (for example everything in a tab owned): "you own everything here" with a tick, not a blank grid

## states (both)

default, owned, equipped, locked with price, can't afford (price in red, button disabled), loading (grey placeholder cards), purchase pending (button shows a spinner, can't double-click).
