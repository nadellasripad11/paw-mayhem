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
