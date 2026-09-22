--!strict
-- ClientState: single shared store for the local client. Holds the latest
-- profile snapshot + match state, and exposes signals so controllers and UI
-- screens stay in sync without tightly coupling to each other.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local ClientState = {}

ClientState.Profile = nil :: any -- {Coins, Gems, Level, XP, Stats, Unlocks, Loadout, Quests}
ClientState.Match = { phase = "Intermission", timeLeft = 0, scores = { Blue = 0, Red = 0 }, board = {} }
ClientState.Settings = {
	MusicVolume = 0.6,
	SFXVolume = 0.8,
	CameraShake = true,
	ShowDamage = true,
	GraphicsQuality = "High",
	MobileSensitivity = 0.5,
}

ClientState.ProfileChanged = Signal.new()
ClientState.MatchChanged = Signal.new()
ClientState.SettingsChanged = Signal.new()

function ClientState.SetProfile(p)
	ClientState.Profile = p
	ClientState.ProfileChanged:Fire(p)
end

function ClientState.SetMatch(m)
	ClientState.Match = m
	ClientState.MatchChanged:Fire(m)
end

function ClientState.UpdateSettings(patch)
	for k, v in pairs(patch) do
		ClientState.Settings[k] = v
	end
	ClientState.SettingsChanged:Fire(ClientState.Settings)
end

-- Ownership + equip helpers used by menus.
function ClientState.Owns(kind: string, id: string): boolean
	local p = ClientState.Profile
	if not p then
		return false
	end
	local map = {
		Weapon = "Weapons", Skin = "Skins", Fur = "Fur",
		Outfit = "Outfits", Hat = "Hats", Accessory = "Accessories", Emote = "Emotes",
	}
	local key = map[kind]
	return key ~= nil and p.Unlocks[key] and p.Unlocks[key][id] == true
end

function ClientState.Equipped(kind: string): string?
	local p = ClientState.Profile
	if not p then
		return nil
	end
	if kind == "Weapon" then
		return p.Loadout.Weapon
	elseif kind == "Skin" then
		return p.Loadout.Skin
	else
		return p.Loadout.Cat[kind]
	end
end

return ClientState
