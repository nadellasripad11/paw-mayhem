# TOOLBOX_ASSETS.md — Optional assets

**PAW MAYHEM runs with zero Toolbox dependencies.** Every core system — cats,
weapons, arena, VFX, and UI — is generated from Roblox primitives and code, so
the game is fully playable the moment Rojo syncs it. Nothing in this file is
required.

This matters for originality and safety: **never blindly import a Toolbox model
that contains scripts** — free models are a common vector for malicious code and
backdoors. The core game deliberately depends on none.

If you want to *enhance* the look/feel, here are safe, optional additions and the
**exact search terms** to use in the Studio Toolbox (Creator Store). Prefer
assets by Roblox or reputable creators, and **inspect for scripts before
inserting** (delete any Script/LocalScript you didn't write).

---

## Audio (recommended first — biggest polish-per-effort)

Use the Studio **Toolbox → Audio** tab (or the Creator Store audio library).
Search terms and where to wire them:

| Purpose | Search term | Wire into |
|---|---|---|
| Blaster shot | `laser blaster shot` / `sci-fi pew` | `CombatController.tryFire` (play on fire) |
| Hit confirm | `hit marker blip` | `EffectsController` `HitConfirm` handler |
| Launch/whoosh | `whoosh swoosh` | `WeaponService.ApplyLaunch` → broadcast a sound |
| Elimination | `pop cute` / `cartoon pop` | `MatchService.onElimination` |
| Power-up pickup | `power up chime` | `PowerUpService.grant` |
| Menu click | `ui click soft` | `UIUtil.button` |
| Victory jingle | `victory fanfare cute` | `Results.Show` |
| Lobby music | `chill lofi loop` | play on the client, gate by `Settings.MusicVolume` |

To add a sound: create a `Sound` in `SoundService` (or on a part), set its
`SoundId` to `rbxassetid://<id>`, and `:Play()` it from the wire-in point above.
Respect the `Settings.MusicVolume` / `SFXVolume` values in `ClientState`.

---

## Optional environment dressing (the arena is already complete)

The arena is built procedurally, but you may add background flavor:

| Purpose | Search term | Notes |
|---|---|---|
| Distant floating rocks | `floating island low poly` | Place far below/around; set `Anchored`, `CanCollide=false`. |
| Skybox | `anime sky` / `pastel skybox` | Add a `Sky` to `Lighting`. Purely cosmetic. |
| Particle textures | `sparkle particle` | For nicer muzzle/impact `ParticleEmitter`s. |

**Rules if you do import a model:**
1. Insert it into a **temporary** place first.
2. Expand it fully in the Explorer and **delete every Script/LocalScript/ModuleScript**
   you did not author.
3. Confirm it has no `RemoteEvent`/`RemoteFunction` you didn't add.
4. Only then move it into the project (as a static model under `Workspace`,
   ideally referenced by `ArenaBuilder` so it rebuilds cleanly).

---

## Fonts / icons
All UI uses built-in Roblox fonts (`FredokaOne`, `Gotham*`) — no imports needed.
Weapon/cat "icons" are colored swatches generated in code. If you want image
icons later, upload your **own original** images as Decals and reference their
asset ids from the config (add an `IconId` field).

---

## Summary
- **Required Toolbox assets: none.**
- **Recommended: a handful of sound effects** for game feel (table above).
- **Always inspect and strip scripts** from any imported model. The core game
  never trusts external code.
