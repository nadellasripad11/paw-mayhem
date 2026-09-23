--!strict
-- Sounds: every sound effect + music track. All ids are audio published by
-- the official Roblox account (free for any experience) or built into the
-- Roblox client (rbxasset://), so nothing needs uploading.

local Sounds = {}

local function rbx(id: number): string
	return "rbxassetid://" .. tostring(id)
end

-- name -> { id, volume, pitch }
Sounds.SFX = {
	Shoot = { id = rbx(11900833), volume = 0.45, pitch = 1.25 }, -- paintball.wav
	Hit = { id = rbx(16480580213), volume = 0.5, pitch = 1.1 }, -- 8-bit blip: you landed a hit
	Hurt = { id = rbx(12222046), volume = 0.55, pitch = 1 }, -- hit.wav: you got hit
	Knockout = { id = rbx(15675043410), volume = 0.7, pitch = 1 }, -- tonal stinger: you KO'd someone
	Eliminated = { id = "rbxasset://sounds/oof.ogg", volume = 0.6, pitch = 1.15 },
	Jump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.35, pitch = 1.2 },
	Land = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.3, pitch = 1.1 },
	Dash = { id = rbx(15675028888), volume = 0.55, pitch = 1.1 }, -- whoosh
	Spring = { id = rbx(12222124), volume = 0.6, pitch = 1 }, -- jump pad
	Explosion = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.6, pitch = 1 },
	Pop = { id = rbx(15675055424), volume = 0.6, pitch = 1 }, -- pickups / power-ups
	Coin = { id = rbx(127645268874265), volume = 0.6, pitch = 1 }, -- rewards + purchases
	Click = { id = rbx(15675059323), volume = 0.4, pitch = 1 },
	Tick = { id = rbx(16480579431), volume = 0.5, pitch = 1 }, -- countdown beep
	Go = { id = rbx(16480578036), volume = 0.6, pitch = 1 }, -- round start riser
	Victory = { id = rbx(12222253), volume = 0.7, pitch = 1 },
	Defeat = { id = rbx(15675081158), volume = 0.6, pitch = 0.9 },
	Alert = { id = rbx(15675085146), volume = 0.5, pitch = 1 }, -- announcements / map events
	Whoosh = { id = rbx(15675024286), volume = 0.4, pitch = 1 }, -- screen transitions
}

Sounds.Music = {
	Lobby = { id = rbx(15675069601), volume = 0.35 }, -- Roblox_UI_Loop_Calm_Music
	Match = { id = rbx(17422163655), volume = 0.3 }, -- Generic - Cloud Blitz
}

return Sounds
