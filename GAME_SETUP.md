# GAME_SETUP.md — Getting PAW MAYHEM into Roblox Studio

This assumes **no prior Rojo experience**. Follow top to bottom.

---

## 1. Required software

| Tool | Why | Link |
|---|---|---|
| **Roblox Studio** | Build/run/publish the game | https://create.roblox.com/ |
| **Rojo** | Syncs these `.lua` files into Studio | https://rojo.space/ |
| **(Recommended) VS Code** | Edit the code + run Rojo | https://code.visualstudio.com/ |
| **(Optional) Aftman** | Installs the exact Rojo version pinned in `aftman.toml` | https://github.com/LPGhatguy/aftman |

You need **Rojo 7.x** (this project pins `7.4.4` in `aftman.toml`). Two ways to get it:

### Option A — Aftman (matches the pinned version, recommended)
1. Install Aftman (download the release for Windows, unzip, run `aftman self-install`).
2. Open a terminal **in this project folder** (`C:\Users\nadel\paw-mayhem`).
3. Run:
   ```bash
   aftman install
   ```
   This installs Rojo `7.4.4` locally. Verify:
   ```bash
   rojo --version
   ```

### Option B — VS Code extension (easiest)
1. In VS Code, install the **Rojo** extension by *Roblox*.
2. It bundles a Rojo binary and adds a "Rojo" panel. That's enough.

Either way, you also need the **Rojo plugin inside Studio**:
- The VS Code extension can install it for you (command palette → “Rojo: Install Roblox Studio Plugin”), **or**
- Get it from the Studio Plugins/Creator Store (search “Rojo”).

---

## 2. Open the project

1. Open the folder `C:\Users\nadel\paw-mayhem` in VS Code (File → Open Folder).
2. Confirm you can see `default.project.json` and the `src/` tree.

`default.project.json` is the map: it tells Rojo which folders become which
Roblox services (ReplicatedStorage, ServerScriptService, StarterPlayer, etc.).

---

## 3. Start the Rojo server

In a terminal in the project folder:
```bash
rojo serve
```
You should see something like `Rojo server listening on port 34872`. Leave this
running. (In VS Code you can instead click **Rojo → Serve → default.project.json**.)

---

## 4. Connect Studio

1. Open **Roblox Studio**.
2. Create a **New → Baseplate** (or any empty place).
3. **Delete the default Baseplate part** if you want a clean slate — the arena is
   built by code at runtime, so it isn't required. (Leaving it does no harm; the
   arena floats above it.)
4. Open the **Rojo** plugin (Plugins tab → Rojo).
5. Click **Connect**. It should say connected to the running server.

Rojo now injects all the code into the right services. You'll see:
- `ReplicatedStorage → Shared`
- `ServerScriptService → Server` (a Script with `Services` + `World`)
- `StarterPlayer → StarterPlayerScripts → Client` (a LocalScript with `Controllers` + `UI`)

While `rojo serve` runs and Studio is connected, **saving a file re-syncs it
live** — no manual re-import.

---

## 5. Run the game

- Press **Play** (F5) in Studio.
- You spawn into the **lobby menu**. The match auto-starts after the
  intermission countdown (default 12s; `MinPlayersToStart = 1` so solo works).
- When the match begins you spawn as a cat. **Left-click to fire**, **Shift to
  sprint**, **Space to jump**, **Shift-lock style mouse** aims the camera.
- Knock a bot/other player off an island to score. First team to 40 (default) or
  highest score at 3:00 wins.

If nothing spawns: make sure the Rojo tree actually synced (you should see
`Server` under ServerScriptService). Check the **Output** window for
`[PAW MAYHEM] Server started.` and `[PAW MAYHEM] Client started.`

---

## 6. Test multiple players

Studio can simulate several clients locally:

1. Go to the **Test** tab → **Clients and Servers**.
2. Set **Players** to `2` (or more) and click **Start**.
3. Studio launches one server window + N client windows. Each is a separate cat.
4. Shoot each other and test knockback / eliminations / kill feed / scoreboard.

See [TESTING.md](TESTING.md) for a full test matrix (mobile emulation,
controller, power-ups, data persistence).

---

## 7. Publish

1. **File → Publish to Roblox As…**
2. Create a new experience named **PAW MAYHEM**, set genre, thumbnail, etc.
3. After the first publish, **File → Game Settings**:
   - **Security**: enable **“Enable Studio Access to API Services”** so
     DataStores work while testing in Studio. (In a live server they work
     automatically.)
   - **Permissions**: set to Public when you're ready for players.
4. Publish again after any change: **File → Publish to Roblox** (Alt+P).

> DataStores only persist in **published** places (or Studio with API access
> enabled). Without it, PAW MAYHEM still runs — `DataService` falls back to an
> in-memory profile so you can test everything except cross-session saving.

---

## 8. Making future updates

1. Keep `rojo serve` running while you edit in VS Code.
2. Change a file under `src/`, save — Rojo live-syncs it into the connected Studio.
3. Press Play to test.
4. When happy, **Publish to Roblox** (Alt+P) to push to the live game.

For collaborators, commit the whole folder to Git; the `src/` tree + 
`default.project.json` are all that's needed to reproduce the place.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Rojo won't connect | Confirm `rojo serve` is running and the plugin's port matches. |
| No code appears in Studio | Re-click **Connect**; check the terminal for errors in `default.project.json`. |
| “Server started” but no arena | Check Output for a Lua error in `ArenaBuilder`; ensure Workspace isn't locked. |
| Cat spawns but can't move | Ensure you didn't leave another StarterCharacter script; this game manages its own character. |
| DataStore errors in Studio | Enable Studio API access (step 7) or ignore — the in-memory fallback keeps play working. |
| Camera stuck / black in lobby | Expected between matches; the menu covers the screen. It clears when a match starts. |
