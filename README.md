# 🐾 PAW MAYHEM

**Small cats. Big knockback. Endless fun.**

PAW MAYHEM is an original Roblox multiplayer game where adorable customizable
cats battle across colorful floating arenas using futuristic blasters and
physics-based knockback. Shoot opponents, launch them across the islands, and
knock them off the map. Combines chaotic multiplayer combat, collectible cats,
weapons, customization, power-ups, progression, quests, and social features.

The defining loop: **SHOOT → KNOCK BACK → LAUNCH → FALL OFF → ELIMINATION.**
Damage builds up "fluff" on a target — the more they've been hit this life, the
farther your next shot launches them. Positioning and aim beat health-trading.

> This is a **real, buildable Roblox project**, not a design document. Every
> system below is implemented in code under `src/`.

---

## What's in the box

| System | Where | Notes |
|---|---|---|
| Custom cat characters | `src/ReplicatedStorage/Shared/Character/CatBuilder.lua` | Built from Roblox parts — no Toolbox models |
| Knockback physics | `Shared/Character/Knockback.lua` + `Server/Services/WeaponService.lua` | Server-authoritative, network-owned launches |
| Server-authoritative combat | `Server/Services/WeaponService.lua` | Raycast hit detection, fire-rate gating, rate limiting |
| Match flow (TDM) | `Server/Services/MatchService.lua` | Intermission → Countdown → Playing → Results |
| Player lifecycle | `Server/Services/PlayerService.lua` | Spawns, teams, respawns, kill-floor ringouts |
| Persistent data | `Server/Services/DataService.lua` | DataStore with autosave + safe fallback |
| Economy / XP / unlocks | `Server/Services/EconomyService.lua` | Coins, XP, levels, purchases, quests |
| Daily quests | `Server/Services/QuestService.lua` | 3 rolled per UTC day |
| Power-ups | `Server/Services/PowerUpService.lua` | Rapid Fire, Mega Knockback, Shield, Speed, Multi Shot |
| Arena | `Server/World/ArenaBuilder.lua` | Procedural floating islands, bridges, windmills, waterfalls |
| Third-person camera | `Client/Controllers/CameraController.lua` | Mouse / touch / gamepad |
| HUD | `Client/UI/Screens/HUD.lua` | Scores, timer, kill feed, crosshair, health, power-up |
| Lobby + menus | `Client/UI/Screens/*` | Play, Loadout, Shop, Customize, Leaderboard, Quests, Settings, Results |

Config is centralized in `src/ReplicatedStorage/Shared/Config/` — retune weapons,
cats, progression, and match rules without touching gameplay code. See
[CONFIG.md](CONFIG.md).

---

## Quick start (5 steps)

You do **not** need to know Rojo already — [GAME_SETUP.md](GAME_SETUP.md) walks
through everything from zero. The short version:

1. **Install Rojo** (via [Aftman](https://github.com/LPGhatguy/aftman) or the
   VS Code extension).
2. In this folder, run `rojo serve`.
3. In Roblox Studio, open a new **Baseplate**, install the **Rojo** plugin, and
   click **Connect**.
4. Press **Play**. You'll spawn into the lobby; the match starts automatically.
5. To test knockback, use two clients (see [TESTING.md](TESTING.md)).

Full instructions, screenshots of the workflow, publishing, and multi-player
testing are in **[GAME_SETUP.md](GAME_SETUP.md)**.

---

## Documentation index

- **[GAME_SETUP.md](GAME_SETUP.md)** — install tools, open in Studio, run, publish, update.
- **[TESTING.md](TESTING.md)** — how to test everything, including multi-player and mobile.
- **[CONFIG.md](CONFIG.md)** — every tunable value and where to change it.
- **[TOOLBOX_ASSETS.md](TOOLBOX_ASSETS.md)** — optional assets to fetch manually (the game runs without any).
- **[FINAL_CHECKLIST.md](FINAL_CHECKLIST.md)** — pre-publish checklist.

---

## Design principles

- **Server authority** over shooting, hit detection, knockback, eliminations,
  rewards, XP, currency, and ownership. The client only sends aim intent.
- **Not pay-to-win**: every purchasable item is cosmetic or sidegrade; weapons
  unlock by level or coins earned in play, and skins never change stats.
- **Original assets**: characters, arena, VFX, and UI are all generated from
  Roblox primitives and code. No copyrighted content, no other game's assets.
- **Cross-platform**: PC (mouse + keyboard), mobile (touch controls), and
  controller are all supported and adapt automatically.

---

## Project layout

```
paw-mayhem/
├── default.project.json      # Rojo project definition
├── aftman.toml               # toolchain (Rojo version)
├── src/
│   ├── ReplicatedStorage/Shared/   # config, net, util, character (shared code)
│   ├── ServerScriptService/Server/ # services + world (server code)
│   └── StarterPlayer/.../Client/   # controllers + UI (client code)
├── tools/                    # offline sanity checkers (Node)
└── docs, README, CONFIG, ...
```

Built for [Hack Club Stardance](https://stardance.hackclub.com/projects/64622)
by [@sripin](https://stardance.hackclub.com/@sripin).
