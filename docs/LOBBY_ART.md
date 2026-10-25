# Lobby art: 3D models, PBR materials, lighting

The lobby is built by code (`LobbyService`). On top of that come three things:

| What | Where it comes from | Turned on by |
|---|---|---|
| Sculpted 3D models (columns, pilasters, the DUELS arch, spawn dais, chandeliers, trophy, planters, wall mouldings) | `tools/lobby/meshes.js` → `assets/LobbyMeshes.glb` | importing the GLB once |
| PBR materials (stone slabs, stone grain, plaster, brushed metal, marble, fabric), tinted by each part's colour | `tools/lobby/textures.js` → embedded in the same GLB | `tools/lobby/setup_materials.lua`, once |
| Lighting, tuned by eye | `src/ReplicatedStorage/Shared/LobbyLighting.lua` | already on; re-tune any time |

Until the GLB is imported the lobby keeps its block-built look, so nothing breaks.

## Regenerating (only after changing the generators)

```
node tools/lobby/textures.js
node tools/lobby/meshes.js
node tools/lobby/preview.js        # renders tools/lobby/preview_*.png to check shapes
```

## Import (once, at deploy, together with the cat meshes)

1. Studio → **Home → Import 3D** → `assets/LobbyMeshes.glb`. Import as a model.
2. Drag the imported model into **ReplicatedStorage → LobbyMeshes**.
3. **View → Command Bar**, paste all of `tools/lobby/setup_materials.lua`, press Enter.
   Output should say `Lobby materials: 6 of 6 made`.
4. Right-click **ReplicatedStorage → LobbyMeshes** → **Save to File** →
   `assets/LobbyMeshes/Lobby.rbxm`. Rojo keeps it from then on.

## Lighting

**Lighting → Technology** must be **Future** (the project file sets it; check it
once). Without it there are no real shadows and no metal reflections.

To tune by eye:

1. Press **Play**. Walk to the part of the lobby you want to light.
2. **Test → Current: Client** switches to the **Server** view.
3. Select **Lighting**. In Properties → Attributes → **+**, add a boolean
   `LobbyTuning` and tick it. The game stops putting its own values back.
4. Change Lighting's Brightness, Ambient, OutdoorAmbient, ExposureCompensation,
   EnvironmentDiffuseScale and EnvironmentSpecularScale.
5. The room lights are in **Workspace → Lobby → Plaza → LightRig**. Each
   `LightN` is an invisible holder with one light. Move them with the Move tool,
   change Color, Range, Brightness, Angle and Shadows, Ctrl+D to add more, or
   delete them.
6. Switch back to **Client** to see it as a player would.
7. When it looks right, switch to **Server**, paste all of
   `tools/lobby/export_lighting.lua` into the command bar and press Enter.
   Copy everything it prints and send it over, or paste it over
   `src/ReplicatedStorage/Shared/LobbyLighting.lua`.

Stopping the game throws away the changes, so export before you stop.

Tips: keep Ambient low (dark corners give depth). Use SpotLights pointing
down for pools of light. Turn Shadows on for the few lights that matter most;
too many shadowed lights cost performance on phones. Warm (orange-ish) lights
make the gold read as gold.
