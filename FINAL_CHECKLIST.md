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
- [ ] Every map has exactly 6 authoritative team spawn points: 3 grounded
      blue points on the Blue island and 3 grounded red points on the Red
      island, arranged in triangles inside the grass and directly above solid
      collidable ground (verify by spawning repeatedly and confirming you never
      fall through or land off-island).
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

## Lobby + duels (test with 2-4 friends)
- [ ] You spawn in the lobby facing the duel pads; practice range behind, armory on the left, boutique on the right, trophy board front-right.
- [ ] You can't get out: railings + invisible wall; fall off the open edge behind the range and you're put back.
- [ ] Walking: cursor free, hold right mouse to turn; inside the practice range you aim and shoot, targets fly off the back.
- [ ] F at a pedestal opens Loadout, F at a boutique stage opens the Shop.
- [ ] PLAY -> pick a mode + map -> QUEUED under the button -> countdown flyover -> you drop in; people who didn't queue stay in the lobby.
- [ ] After the match everyone who played is back in the lobby; the menu comes back.
- [ ] 1v1 pad: two players on the slots -> 3, 2, 1 -> duel on a random map; first to 5; VICTORY / DEFEAT with the trophy change; back to the lobby.
- [ ] 2v2 pad with 4 players; teammates can't hurt each other.
- [ ] Alone on a pad for 15 s -> a bot fills the other slot; bot duels say NO TROPHIES.
- [ ] Leaving mid-duel gives the other side the win.
- [ ] In a match, B (or the top-left button) opens Loadout over the game; a blaster picked in the first 5 s is in your paws at once, later ones from your next respawn.

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

## Friends playtest (Studio: Test → Clients and Servers → 3+ players, or publish and join together)
Copy every red line from the Output window and send it over.
- [ ] Every mode once: Team Deathmatch, Free For All, King of the Hill (someone scores standing in the hill), Ringout, Capture the Flag (grab → carry → capture; knock a carrier off → flag goes home).
- [ ] Every map once: Sky Islands, Volcano (lava rises in the last 30s), Toybox, Neon Rooftops.
- [ ] Shots feel instant; hits register on moving cats; recoil on Boom Paw / Void Cannon.
- [ ] Knockback: launches carry, star twinkle when someone flies off, RING OUT pop.
- [ ] Movement: double jump, wall-jump, dash (Q), pounce (E), coyote jump off ledges.
- [ ] Spawns spread over 3 spots per team; nobody spawns inside a crate.
- [ ] Emotes (B) — friends can see them. Kill feed shows names + weapons.
- [ ] New player (fresh account or reset data): intro cinematic (skippable) → lesson with Mochi on the practice island (ring, jump, double jump, shoot, knock one off, dash, pounce) → menu with START HERE on PLAY. If a match is already running, the lesson is skipped and first-match tips show instead.
- [ ] Menu: Settings and Leaderboard are the round icons at the top right.
- [ ] Phone (Studio device emulator): FIRE / JUMP / DASH / POUNCE / RUN buttons, auto-fire.
- [ ] Results: win streak + trophy change; menu shows tier; TROPHIES leaderboard.
- [ ] Settings → Codes: PAWMAYHEM works once, a second try says already used.
- [ ] PRACTICE (menu): island with 3 target cats, their % climbs, they fly off and reset; P / LEAVE goes back; starting a match pulls you out.
- [ ] Knock someone out, then at match end: slow-mo replay before the podium (click skips).
- [ ] Sounds: hit pitch rises on high-% targets; thump + whoosh on launches; music muffles while you're knocked out.

## Dashboard (you)
- [ ] Import `assets/CatMeshes.glb` (drag the model into ReplicatedStorage → CatMeshes).
- [ ] Import `assets/LobbyMeshes.glb` (Home → Import 3D), then paste `tools/lobby/setup_lobby.lua` into the command bar (docs/LOBBY_ART.md).
- [ ] Lighting → Technology = Future.
- [ ] Game Settings → Communication → Microphone ON (proximity voice).
- [ ] Places → Server Size 12–16. Private servers on (cheap).
- [ ] Create a Roblox group → put its id in `src/ReplicatedStorage/Shared/Config/Community.lua` (GroupId).
- [ ] Season Pass (R$299), Season Tiers (R$99), 8 badges → send the ids.
- [ ] Icon, thumbnails, description, Discord link. Publish.
- [ ] After launch: Analytics → Funnels → onboarding (where new players quit).
