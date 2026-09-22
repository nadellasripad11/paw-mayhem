# paw mayhem

small cats. big knockback. total chaos.

paw mayhem is a roblox multiplayer game where you play as a cute customizable cat, pick up a futuristic blaster, and try to knock everyone else off floating islands. the more hits a player takes in a life, the farther your next shot sends them flying. positioning and aim beat everything else.

the loop: **shoot → knock back → launch → fall off → elimination.**

---

## what's in the game

- 8 weapons, each with a different feel — sniper, bubble blaster, void cannon, rapid fire, and more
- 8 cat fur types + outfits, hats, accessories, and emotes to mix and match
- 3 maps that rotate each server: sky islands, volcano, and toybox
- full match flow: intermission → countdown → playing → results with confetti
- xp + level system, coins economy, daily quests, and mid-match power-ups
- shop, loadout, customize, leaderboard, and settings screens — all built in code
- server-authoritative everything: shooting, hit detection, knockback, and rewards are all validated server-side so nothing can be cheated

all characters, maps, ui, and effects are built from roblox primitives. zero toolbox models.

---

## running it locally

you need rojo. the easiest way is the vs code extension or [aftman](https://github.com/LPGhatguy/aftman).

```
rojo serve
```

then open roblox studio, connect the rojo plugin, and hit play. you will land on the catto pew pew home screen; choose play, select one of the three maps, and press play this map to enter the countdown and arena. for knockback testing you need two studio clients — see [TESTING.md](TESTING.md).

full setup walkthrough is in [GAME_SETUP.md](GAME_SETUP.md).

---

## project layout

```
paw-mayhem/
├── default.project.json         # rojo project definition
├── src/
│   ├── ReplicatedStorage/Shared/   # config, remotes, utilities, character
│   ├── ServerScriptService/Server/ # services + world + maps
│   └── StarterPlayer/.../Client/   # controllers + ui screens
└── tools/                       # static analysis scripts
```

config for weapons, cats, progression, and match rules all lives in `src/ReplicatedStorage/Shared/Config/` — easy to retune without touching gameplay code.

---

built for [hack club stardance](https://stardance.hackclub.com/projects/64622) by [@sripin](https://stardance.hackclub.com/@sripin).
