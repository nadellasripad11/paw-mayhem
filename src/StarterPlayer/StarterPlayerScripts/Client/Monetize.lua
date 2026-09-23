--!strict
-- Monetize: client helpers for Robux purchases. Opens Roblox's own purchase
-- prompt (the server grants the item in MonetizationService); items whose Id
-- isn't set yet show a friendly "coming soon" instead.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local ClientActions = require(script.Parent.ClientActions)

local Monetize = {}

local player = Players.LocalPlayer

Monetize.OnUnavailable = nil :: ((string) -> ())?

local function unavailable(name: string)
	if Monetize.OnUnavailable then
		Monetize.OnUnavailable(name .. " is coming soon!")
	end
end

function Monetize.OwnsPass(key: string): boolean
	return player:GetAttribute(key) == true
end

function Monetize.PromptPass(key: string)
	local pass = Monetization.Passes[key]
	if not pass then
		return
	end
	if pass.Id == 0 then
		unavailable(pass.Name)
		return
	end
	if Monetize.OwnsPass(key) then
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
end

function Monetize.PromptProduct(key: string)
	local product = Monetization.Products[key]
	if not product then
		return
	end
	if product.Id == 0 then
		unavailable(product.Name)
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

-- "Buy with R$" key for an item, if it has one.
function Monetize.UnlockKey(kind: string, id: string): string?
	local key = kind .. "_" .. id
	return Monetization.Products[key] and key or nil
end

-- Price button text + colour for a catalog item (coins, gems or a pass).
function Monetize.PriceTag(item: any): (string, Color3)
	if item.Season then
		return "SEASON PASS", Color3.fromRGB(150, 110, 255)
	end
	if item.PassOnly then
		local pass = Monetization.Passes[item.PassOnly]
		return (pass and string.upper(pass.Name) or "PASS") .. " PASS", Color3.fromRGB(255, 190, 40)
	elseif (item.GemCost or 0) > 0 then
		return tostring(item.GemCost) .. " GEMS", Color3.fromRGB(224, 96, 255)
	end
	return tostring(item.CoinCost or 0) .. " COINS", Color3.fromRGB(255, 207, 72)
end

-- Buy a catalog item: coins/gems first, then fall back to Robux (the pass
-- that unlocks it, or its "Unlock" product when the player is short).
function Monetize.Buy(kind: string, id: string, item: any): boolean
	if item and item.Season then
		if Monetize.OnUnavailable then
			Monetize.OnUnavailable("Earn this in the Season Pass!")
		end
		return false
	end
	if item and item.PassOnly then
		Monetize.PromptPass(item.PassOnly)
		return false
	end
	local res = ClientActions.Purchase(kind, id)
	if res and res.ok then
		return true
	end
	local reason = res and res.reason or ""
	if reason == "not enough coins" or reason == "not enough gems" then
		local key = Monetize.UnlockKey(kind, id)
		if key then
			Monetize.PromptProduct(key)
		elseif Monetize.OnUnavailable then
			Monetize.OnUnavailable(reason == "not enough gems" and "Not enough gems - grab more in the Shop!" or "Not enough coins yet!")
		end
	end
	return false
end

return Monetize
