# TESTING.md — How to test PAW MAYHEM

The project ships with **offline sanity checkers** (no Studio needed) plus a
full in-Studio test matrix.

---

## 0. Offline checks (run before opening Studio)

These use Node (already available if you ran the build). From the project root:

```bash
node tools/luacheck.js       # block/keyword balance across every .lua file
node tools/requirecheck.js   # simulates the Rojo tree, resolves every require()
```

Expected output:
```
OK: 40 files balanced
OK: all requires resolve (40 modules)
```

These catch missing `end`s and wrong module paths — the two most common reasons
a Rojo project fails to load. They do **not** replace running the game (they
can't check runtime behavior), but a green result means the tree will load.

---

## 1. Smoke test (single player)

1. `rojo serve` → connect Studio → Play.
2. Output shows `[PAW MAYHEM] Server started.` and `[PAW MAYHEM] Client started.`
3. Lobby menu appears. Wait for the intermission → countdown → you spawn.
4. Confirm:
   - [ ] You control a cat (WASD/arrows, Space jumps, Shift sprints).
   - [ ] Third-person camera follows and aims with the mouse.
   - [ ] Left-click fires bolts with a muzzle flash + tracer.
   - [ ] HUD shows scores, timer, crosshair, health, weapon name.

## 2. Knockback + elimination (needs 2 clients)

1. Test tab → **Clients and Servers** → Players = 2 → Start.
2. On client A, shoot client B repeatedly.
   - [ ] B's "fluff" accumulates (each hit launches farther — visible after a few hits).
   - [ ] A sustained hit near an edge launches B **off the island**.
   - [ ] When B falls below the map, B is **eliminated** (ringout) and the kill
         feed shows it.
   - [ ] A's team score + elimination count go up; B respawns after ~3s.
3. Confirm friendly fire is off (same-team shots do nothing) and spawn
   protection prevents instant re-kills.

## 3. Match flow

- [ ] Timer counts down from 3:00.
- [ ] Reaching the score cap (40 default) ends the match early.
- [ ] Results overlay shows VICTORY/DEFEAT + final score.
- [ ] After results, everyone returns to the lobby and a new match cycles.

## 4. Progression + economy

- [ ] Eliminations grant XP + coins (watch the top-right counters).
- [ ] Leveling up shows a "Level Up!" toast and grants bonus coins.
- [ ] Open **Shop** → buy a cheap skin → it deducts coins and unlocks.
- [ ] Open **Loadout** → equip a different weapon → HUD weapon name updates next life.
- [ ] Open **Customize** → change fur/hat → your next spawned cat reflects it.
- [ ] Open **Quests** → progress advances during play → claim gives coins.

## 5. Power-ups

- [ ] During a match, a glowing orb spawns on a pad every ~18s.
- [ ] Touch it → the HUD shows the active power-up.
- [ ] Verify each effect: Rapid Fire (faster shots), Mega Knockback (bigger
      launches), Shield (you take less damage/knockback), Speed Boost (faster
      movement), Multi Shot (extra pellets).

## 6. Persistence (published place or Studio API access)

1. Enable Studio API access (see GAME_SETUP step 7) **or** test in a published place.
2. Earn coins / buy an item / gain XP.
3. Leave and rejoin.
   - [ ] Coins, XP/level, unlocks, and equipped loadout persist.

> Without API access, `DataService` uses an in-memory profile — everything works
> in-session but resets on rejoin. This is expected and by design.

## 7. Mobile

1. Studio → **Test** tab → **Device** → pick a phone (e.g. iPhone) → Play.
2. Confirm:
   - [ ] Left thumbstick moves; right-side drag rotates the camera.
   - [ ] On-screen **FIRE / JUMP / RUN** buttons appear and work.
   - [ ] UI is readable at phone resolution.

## 8. Controller

1. Connect a gamepad. In Studio, gamepad input works in Play mode.
2. Confirm:
   - [ ] Left stick moves, right stick aims the camera.
   - [ ] **R2** fires, **A** jumps, **L3 (left stick click)** toggles sprint.

---

## Known limitations to verify against (not bugs)

- The "Leaderboard → Live Ranking" shows the **current server's** players. A true
  cross-server global board would use `OrderedDataStore` (see CONFIG.md → Global
  leaderboard).
- Cat leg placement may hover slightly depending on `HIP_HEIGHT`
  (`CatBuilder.lua`); tune if desired.
- Emotes are wired through the UI/data but play as simple client tweens; extend
  in `EmoteController` if you add more.
