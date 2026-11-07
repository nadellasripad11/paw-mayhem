# paw mayhem

**small cats. big knockback. total chaos.**

a roblox multiplayer shooter where you play as a tiny customizable cat, grab a futuristic blaster, and knock everyone else off floating islands. the more hits a player has taken in a life, the farther your next shot sends them flying — so the game rewards patience, positioning, and knowing when to commit.

the loop: **shoot → knock back → stack damage → launch → fall off → elimination.**

---

## why i built this

i wanted to make something that felt genuinely fun to play — not another obby or tycoon, but a real game with mechanics that reward skill. the knockback-stacking system came from playing smash bros and thinking: what if that was the whole game, stripped to its bones?

i also wanted to prove to myself i could ship something complete. that meant a full match flow, a real economy, persistent progression, a working shop — not just a proof of concept. every system in this game was built from scratch in luau without buying anything from the toolbox, because i wanted to actually understand what i was building.

this was my project for [hack club stardance](https://stardance.hackclub.com/projects/64622), where i had a few weeks to take it from idea to playable. the tight deadline forced a lot of good decisions — scope it down, get the core loop fun first, then layer everything else on top.

---

## what's in it

**combat**
- 8 weapons with distinct feel: sniper, bubble blaster, void cannon, rapid fire, and more
- knockback scales with how many times you've been hit in a life — first shot barely moves you, last one sends you flying
- server-authoritative hit detection and knockback — nothing can be faked client-side

**customization**
- 8 cat fur types + outfits, hats, accessories, and emotes
- loadout and customize screens built entirely in code

**maps & match flow**
- 3 maps that rotate each server: sky islands, volcano, toybox
- full match cycle: intermission → countdown → playing → results with confetti

**progression**
- xp + level system, coins economy, daily quests
- mid-match power-ups that drop on the map
- leaderboard, settings, and shop screens — all in-game

**zero toolbox models** — every character, map, ui element, and effect is built from roblox primitives.

---

## how it was made

everything is luau running in roblox studio. the codebase is split the way roblox expects:

```
src/
├── ReplicatedStorage/Shared/   # config, remotes, utilities, character
├── ServerScriptService/Server/ # services, world, maps
└── StarterPlayer/.../Client/   # controllers, ui screens
```

all tunable values — weapon stats, knockback curves, progression tables, match timing — live in `src/ReplicatedStorage/Shared/Config/`. you can retune the whole game feel by touching one folder.

the server owns everything that matters: shooting, hit detection, knockback math, xp rewards. the client asks and renders. this means no exploits can mess with outcomes, which turned out to matter a lot once real people started playing.

the project uses [rojo](https://github.com/rojo-rbx/rojo) to sync files from the filesystem into studio, which made version control actually work. `aftman.toml` pins the toolchain so anyone who clones this gets the same rojo version.

---

## lessons from building it

- **get the core loop fun before adding anything else.** i spent a week just on knockback feel before touching the shop or progression.
- **server authority is worth the extra code.** rewriting client-side systems to be server-authoritative mid-project is painful. start there.
- **scope is a feature.** i cut a crafting system, a spectator mode, and two more maps. the game is better for it.
- **playtesting early is brutal and necessary.** watching someone play and immediately stop told me more than any amount of self-testing.

---

built by [@sripin](https://stardance.hackclub.com/@sripin) for hack club stardance.
