# paw mayhem ui: global design

Status: approved

## direction

a **cartoon brawler**, not a tactical shooter and not a web dashboard. chunky, readable, warm. the lobby is a light retro 70s room (cream walls, orange and peach stripes, patterned carpet, walnut wood; see `src/ReplicatedStorage/Shared/LobbyPalette.lua`), so the ui borrows its walnut and orange. no gold, no purple, no neon.

rule of thumb: **one thing on the screen is loud (the main action). everything else is quiet.**

## palette (tokens)

| token | colour | used for |
|---|---|---|
| surface | walnut `#4A3428`, solid | every panel. solid enough that the room never shows through text |
| surface-raised | `#5C4233` | rows, cards and tabs inside a panel |
| line | white at 10% | 1px dividers and panel edges only |
| text | cream `#FFF4E6` | main text |
| text-dim | `#D9C3AE` | secondary text, timers, labels |
| orange (the one accent) | `#F2933A` | selected tab, rewards, coin numbers, the current item |
| play green | `#4CC45C` | **only** the Play button and real "buy / claim" actions |
| danger red | `#FF4E5B` | notification dots, errors |
| gem purple | `#C46BFF` | gem amounts only |

no blue buttons any more (blue was a second accent). team blue and red stay in matches.

## type

- **titles**: FredokaOne, ALL CAPS, 28 / 22 px (screen title / panel title)
- **labels and buttons**: FredokaOne, ALL CAPS, 16 px
- **body / task names**: GothamBold, sentence case, 15 px
- **numbers** (coins, timers, progress): FredokaOne 18 px
- every label uses one of these. no other sizes.

## shape and effects

- corners: 10 px panels, 8 px buttons and rows, full circle only for avatar and round icon buttons
- **gloss (gradient + shine) only on the Play button and buy / claim buttons.** everything else is flat
- strokes: 1px `line` on panel edges. no thick outlines
- no drop shadows except under the bottom bar (one soft shadow)

## spacing

4 / 8 / 12 / 16 / 24 px only. panels pad 16, rows gap 8, groups gap 24.

## icons

one style: the 3d viewport icons, all built to the same rules. same camera angle, same lighting, each fills about 80% of its square, nothing clipped. the flat white glyph icons are only used inside rows (task icons, stat icons).

## buttons

| kind | look | example |
|---|---|---|
| primary | play green, gloss, 60 px tall | Play, BUY, CLAIM |
| secondary | surface-raised, orange text, 44 px | TO DUELS, SKINS, NEW TASKS |
| quiet | no background, text-dim, icon | close X, filters |
| owned / disabled | surface-raised, text-dim, a tick icon | OWNED, EQUIPPED |

every button: hover brightens 8%, press scales to 0.95 in 0.08s, back in 0.15s.

## motion

0.12 to 0.30s for ui. panels slide 12px and fade in 0.2s. no bouncing on routine controls (keep the big bouncy moments for the end screen, level up, knockouts).

## responsive

- **phone** (height under 500px): bottom bar icons 56px, tasks collapse to a single pill ("tasks 2/4"), to duels moves into the bottom bar row, play stays centre bottom
- **laptop**: the layouts below
- everything stays inside the safe area; nothing in the top-left roblox buttons or the bottom-right thumb zone in the lobby
