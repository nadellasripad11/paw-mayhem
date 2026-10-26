# Game models: blasters and maps

`tools/models/game_meshes.js` builds every model below into one file,
`assets/GameMeshes.glb`. There are no textures: the game tints each piece and
gives it a Roblox material, so gun skins and map colours keep working. Until
the file is imported, everything stays block-built, so nothing breaks.

| Where | What changes |
|---|---|
| All 10 blasters (held, weapons rack, shop and loadout views, displays) | each gun is rebuilt from its design with rounded, bevelled edges, as one smooth mesh per colour slot |
| Duel maps (Meadow, Sakura, Autumn, Frost) | rooted trees with full canopies, layered pines (with snow on Frost), bushes, faceted rocks, framed crates, iron lamps, rock-column cliffs, hanging rocks and a rolled grass lip on every island |
| Toybox | soft rounded toy blocks (crates, towers, arches, rails, platforms, island cliffs, ABC blocks), real balloons, swirl lollipops, crayons, candy canes, a giant rubber duck, rounded dice |
| Rooftops | finned AC units with fans, wooden water tanks on braced legs |
| Sky Islands, Volcano | unchanged |

Solid things a model replaces stay as invisible collision, so cover and
walking work exactly as before.

## Import (once)

1. Studio, in **Edit mode**: **Home → Import 3D** → pick `assets/GameMeshes.glb` → **Import**.
2. **Wait** until the model appears in Workspace and Output stops showing
   "Asset content representation is being generated" (about a minute).
3. **View → Command Bar**: paste all of `tools/models/setup_game.lua` and press **Enter**.
   It should print `Models found: 83 / 83` and `DONE`, with no red lines after it.
4. **File → Save to Roblox**.

## Regenerating / checking

```
node tools/models/game_meshes.js         # the GLB, GameMeshData.lua, setup_game.lua
node tools/models/preview.js             # tools/models/preview_*.png
node tools/lobby/validate.js assets/GameMeshes.glb
node tools/models/test/run.js            # setup + placement against a mock Roblox
```
