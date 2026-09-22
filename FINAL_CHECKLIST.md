# FINAL_CHECKLIST.md — Before you publish PAW MAYHEM

Work top to bottom. Boxes you can tick without Studio are marked **[offline]**.

## Build integrity
- [ ] **[offline]** `node tools/luacheck.js` → `OK: 40 files balanced`
- [ ] **[offline]** `node tools/requirecheck.js` → `OK: all requires resolve (40 modules)`
- [ ] **[offline]** `default.project.json` parses (it does if the above ran).
- [ ] Rojo connects and the tree appears in Studio (Shared / Server / Client).
- [ ] Output shows `[PAW MAYHEM] Server started.` + `[PAW MAYHEM] Client started.`

## Core gameplay
- [ ] Cats spawn and are controllable (move / jump / sprint).
- [ ] Every island (hub + 6 outer) has exactly 6 spawn points, hexagon-arranged
      at half the island's radius — always well inside the grass, never near an
      edge, always directly above solid collidable ground (verify by spawning
      repeatedly and confirming you never fall through or land off-island).
- [ ] Third-person camera works on mouse, and aims where the crosshair points.
- [ ] Firing deals damage server-side; tracers + muzzle flash show.
- [ ] Knockback scales with accumulated fluff (later hits launch farther).
- [ ] Falling below the map = elimination (ringout) with kill-feed entry.
- [ ] Respawn after delay; spawn protection prevents instant re-kills.
- [ ] Friendly fire is off within a team.

## Match flow
- [ ] Intermission → Countdown → Playing → Results → back to lobby, looping.
- [ ] Timer + team scores update live on the HUD.
- [ ] Score cap ends the match early; timer expiry ends it too.
- [ ] Results overlay shows the correct VICTORY/DEFEAT + score.

## Economy / progression
- [ ] Eliminations grant XP + coins; match end grants XP (+win bonus).
- [ ] Level-up toast + bonus coins fire at the right thresholds.
- [ ] Shop purchase deducts coins and unlocks the item (server-validated).
- [ ] Equip in Loadout/Customize updates the next spawned cat / HUD weapon.
- [ ] Daily quests progress during play and pay out on claim.
- [ ] **(Published or API-access)** data persists across rejoin.

## Power-ups
- [ ] Orbs spawn on pads during matches; pickup shows the active power-up.
- [ ] Each of the 5 effects behaves as described in TESTING §5.

## Cross-platform
- [ ] Mobile: thumbstick + right-drag look + FIRE/JUMP/RUN buttons.
- [ ] Controller: sticks + R2 fire + A jump + L3 sprint.
- [ ] UI readable at phone resolution.

## Security review (server authority)
- [ ] Client cannot deal damage directly (only sends aim; server raycasts).
- [ ] Fire rate is enforced **server-side** (client interval is only for feel).
- [ ] A spam/teleport-aim client is bounded by the rate limiter + origin-drift check.
- [ ] Coins/XP/unlocks are only ever mutated in `EconomyService` (server).
- [ ] Purchases/equips validate ownership and cost on the server.
- [ ] Knockback uses server network ownership so it can't be ignored client-side.

## Performance
- [ ] No runaway part creation (tracers/effects use `Debris` cleanup).
- [ ] Arena part count is reasonable; lower `GraphicsQuality` in Settings if needed.
- [ ] `AutoSaveSeconds` isn't too aggressive for your player count.

## Publishing
- [ ] Experience created + named **PAW MAYHEM**.
- [ ] Thumbnail/banner set (see `assets/stardance-banner.svg`).
- [ ] Studio API access enabled for DataStore testing (Game Settings → Security).
- [ ] Republished after the final change (Alt+P).

## Stardance
- [ ] Devlogs reflect **actual** work completed (no fabricated hours).
- [ ] Project description set (see README intro paragraph).
- [ ] Banner uploaded.

---

### Nice-to-have next (post-v1)
- Sound pass (see TOOLBOX_ASSETS.md).
- Cross-server `OrderedDataStore` leaderboard (hook points in `EconomyService`).
- Weapon id in the kill feed (track last damaging weapon per victim).
- Richer emotes / an emote wheel UI.
