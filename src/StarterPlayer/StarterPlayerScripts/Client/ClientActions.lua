--!strict
-- ClientActions: thin wrappers around the purchase/equip/claim RemoteFunctions.
-- Keeps menu screens free of raw remote plumbing. All results are validated by
-- the server; these just relay the request and return the server's answer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local ClientActions = {}

function ClientActions.Purchase(kind: string, id: string)
	local ok, res = pcall(function()
		return Remotes.Get("PurchaseItem"):InvokeServer({ kind = kind, id = id })
	end)
	if ok then
		return res
	end
	return { ok = false, reason = "network" }
end

function ClientActions.SetEmoteSlot(slot: number, id: string)
	local ok, res = pcall(function()
		return Remotes.Get("SetEmoteSlot"):InvokeServer({ slot = slot, id = id })
	end)
	return ok and res or { ok = false }
end

-- The six emote slots ("" = empty).
function ClientActions.EmoteSlots(): { string }
	local p = require(script.Parent.ClientState).Profile
	local s = p and p.Loadout and p.Loadout.EmoteSlots
	local out = {}
	for i = 1, 6 do
		out[i] = (type(s) == "table" and type(s[i]) == "string") and s[i] or ""
	end
	return out
end

function ClientActions.Equip(kind: string, id: string)
	local ok, res = pcall(function()
		return Remotes.Get("EquipItem"):InvokeServer({ kind = kind, id = id })
	end)
	if ok then
		return res
	end
	return { ok = false }
end

function ClientActions.ClaimQuest(questId: string)
	local ok, res = pcall(function()
		return Remotes.Get("ClaimQuest"):InvokeServer(questId)
	end)
	if ok then
		return res
	end
	return { ok = false }
end

function ClientActions.UseEmote(emoteId: string)
	Remotes.Get("UseEmote"):FireServer(emoteId)
end

function ClientActions.RequestRespawn()
	Remotes.Get("RequestRespawn"):FireServer()
end

return ClientActions
