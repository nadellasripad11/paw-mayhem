# CONFIG.md — Tuning PAW MAYHEM

Everything gameplay-facing is data-driven from
`src/ReplicatedStorage/Shared/Config/`. Edit these modules and re-sync (Rojo
live-updates them). No gameplay logic lives in the config files.

---

## GameConfig.lua — match, movement, knockback, camera

### Match flow (`GameConfig.Match`)
| Key | Default | Meaning |
|---|---|---|
| `MinPlayersToStart` | `1` | Set to `2`+ for real lobbies; `1` allows solo Studio testing. |
| `IntermissionSeconds` | `12` | Lobby wait before a match. |
| `CountdownSeconds` | `3` | "Get Ready" countdown. |
| `MatchSeconds` | `180` | Match length (3:00). |
| `ResultsSeconds` | `10` | Results screen duration. |
| `ScoreToWin` | `40` | Team score that ends the match early. |
| `Teams` | Blue / Red | Team ids, names, colors. |

### Movement (`GameConfig.Character`)
`WalkSpeed`, `SprintSpeed`, `JumpPower`, `Health`, `RespawnDelay`, and
`KillFloorY` (the Y below which a launched cat is eliminated — the arena floats
around Y≈0, kill floor is `-120`).

### Knockback (`GameConfig.Knockback`) — the defining mechanic
| Key | Default | Effect |
|---|---|---|
| `BaseImpulse` | `45` | Base launch velocity (studs/s) on a fresh target. |
| `DamageScale` | `1.6` | How much accumulated "fluff" damage amplifies launches. |
| `MaxDamageForScale` | `180` | Damage at which scaling maxes out. |
| `UpwardBias` | `0.35` | Fraction of the push redirected upward (the "pop"). |

Knockback velocity ≈ `BaseImpulse × (1 + dmgFrac × DamageScale) × weaponMult ×
powerupMult`. Increase `BaseImpulse`/`DamageScale` for a floatier, more chaotic
game; decrease for a grounded one. `Workspace.Gravity` is set to `120` in
`default.project.json` (lower than default 196) for longer, readable arcs.

### Camera (`GameConfig.Camera`)
`ThirdPersonDistance`, `FieldOfView`, `Sensitivity`, `ShoulderOffset`.

---

## Weapons.lua — blasters + skins

`Weapons.List` is an array of weapon defs. Key fields:
- `Damage` — fluff added per hit (drives knockback scaling **and** ticks HP at 50%).
- `FireRate` — shots/sec (server-enforced).
- `Knockback` — multiplier on the base impulse (weapon "identity").
- `Range`, `Spread` (degrees, lower = tighter), `Pellets` (shotgun-style).
- `Bars` — the 0..1 values shown on the Loadout stat bars (cosmetic display).
- `UnlockLevel`, `CoinCost` — how it's obtained.
- Optional `SlowFactor`/`SlowSeconds` — status slow (Frost Blaster).

`Weapons.Skins` are **cosmetic tints only** — they never touch stats. Add a new
weapon by appending to `List`; it appears in Loadout/Shop automatically.

> Balance note: keep `Damage × FireRate` (DPS-of-fluff) in a sane band so no
> weapon trivializes ringouts. Heavy weapons trade fire rate for knockback.

---

## Cats.lua — cat cosmetics

`Fur`, `Outfits`, `Hats`, `Accessories`, `Emotes` — each an array of
`{ Id, Name, ... , UnlockLevel, CoinCost }`. `CatBuilder.lua` reads these to
recolor/attach parts. `Cats.Default` is the starting look. Add an entry and it
shows up in Customize/Shop automatically; extend `CatBuilder` if a new hat/accessory
needs a new procedural shape.

---

## Progression.lua — XP, quests, power-ups

- `XpForLevel(level)` — the level curve. Edit the formula to make leveling
  faster/slower.
- `LevelUpCoins(level)` — coin bonus per level.
- `QuestPool` — daily quest templates; `DailyQuestCount` (default 3) are rolled
  per UTC day per player. Each has a `Metric` matched to a tracked stat.
- `PowerUps` — the 5 power-ups and their multipliers/effects. `GameConfig.PowerUps`
  controls spawn interval / duration.

---

## Scoring (`GameConfig.Scoring`)
XP/coin values for eliminations, assists, matches played, and win bonuses.

---

## DataStore (`GameConfig.DataStore`)
`Name` (bump the version suffix to wipe/migrate data), `AutoSaveSeconds`,
`MaxRetries`.

---

## Extending: a true global leaderboard

The in-game "Live Ranking" is per-server (accurate + safe). For a cross-server
all-time board:

1. In `EconomyService`, after a match, write the player's score to an
   `OrderedDataStore` (e.g. `DataStoreService:GetOrderedDataStore("Elims_v1")`).
2. Read the top N with `GetSortedAsync(false, 10)` on a timer.
3. Push the result over a new remote to the Leaderboard screen.

Kept out of v1 to avoid DataStore write-rate pitfalls; the hook points are all in
`EconomyService`.

---

## Networking (`Shared/Net/Remotes.lua`)
All RemoteEvents/RemoteFunctions are declared in one table. Add a remote by
adding a name → `"Event"`/`"Function"` entry; it's created server-side on boot
and waited-for client-side. Never create ad-hoc remotes elsewhere.
