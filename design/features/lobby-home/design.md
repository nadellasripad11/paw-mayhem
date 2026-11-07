# lobby home screen

Status: approved

## goal

get the player into a match in one tap, and show their next small goal. the room behind should be visible and look good, not covered.

## layout (laptop)

```
[roblox]                [coin 3,709] [gem 2,855 +]          [emotes][ranks][settings]

[tasks card]


                        [ avatar ]  [    PLAY     ]  [+]
                                   duel 1v1 - 5v5 >          <- small text link
              [weapons] [customize] [tasks] [shop] [pass]    <- bottom bar
```

1. **tasks card** (top left, under the roblox buttons), 260 px wide, solid surface
   - header: clipboard icon, "DAILY TASKS", the reset timer in text-dim ("resets 6h 54m")
   - rows: glyph icon, task name (one line, sentence case), a thin gold progress bar, "2/3" and the coin reward on the right
   - a finished task: the whole row turns into a green CLAIM button
   - collapsed by default after the first visit of the day; tap the header to open
   - NEW TASKS (R$25) becomes a quiet text button inside the card footer, not a full-width bar
2. **play group** (bottom centre, above the bar)
   - avatar circle with your actual cat face (3d, your colours) and the level badge
   - PLAY: the only big glossy green thing on screen
   - **to duels becomes a small secondary link under play** ("duels 1v1 - 5v5 >"), not a second big button
   - the invite + stays, small and quiet
3. **bottom bar**: five icons in one matching 3d style, all the same size, none clipped. the selected one gets a gold underline. labels in caps
4. **top**: coin and gem pills unchanged (they work). top-right buttons get recognisable icons (a trophy for ranks instead of the brown blocks)

## states

- **first visit**: tasks card open, a soft pulse on PLAY
- **queued**: play reads "QUEUED 0:12" with the cancel X, glowing outline (exists)
- **task ready to claim**: the row turns green with CLAIM, and the tasks icon in the bar gets a red count badge
- **all tasks done**: the card shows "all done, new tasks in 6h 54m" with a tick
- **loading profile**: the card shows 3 grey placeholder rows, not an empty box

## phone

- the tasks card shrinks to a pill "TASKS 2/4" top left; tap opens it as a sheet over the screen
- duels link sits under play; bar icons 56 px; nothing in the bottom-right thumb zone except the jump button

## also in this pass (the room, not the ui)

the gold in the room shows as bright lemon yellow. bring it back to warm gold (`#C9963F`-ish) on floor rings, pillar caps and rails, and calm the white ceiling panels, so the screen behind the ui looks rich instead of loud.
