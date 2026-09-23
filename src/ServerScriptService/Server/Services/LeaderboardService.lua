--!strict
-- LeaderboardService: global and per-country leaderboards (Eliminations and
-- Wins) backed by OrderedDataStores.
--   * each player's country comes from LocalizationService and is published
--     as the "Country" player attribute
--   * stats are written every couple of minutes and when a player leaves
--   * GetLeaderboard(scope, metric) returns the top 50 with usernames; results
--     are cached for a minute. If DataStores are unavailable (e.g. Studio
--     without API access) it falls back to the players in this server.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local METRICS = { Eliminations = true, Wins = true }
local TOP = 50
local CACHE_SECS = 60
local PUBLISH_SECS = 120

local nameCache: { [number]: string } = {}
local cache: { [string]: { at: number, entries: { any } } } = {}

local function storeFor(scope: string, metric: string): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("PawLB_" .. scope .. "_" .. metric)
	end)
	return ok and store or nil
end

local function countryOf(player: Player): string
	local cc = player:GetAttribute("Country")
	return typeof(cc) == "string" and cc or "US"
end

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.Name
		return p.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Player" .. tostring(userId))
	return nameCache[userId]
end

local function publish(player: Player)
	local profile = DataService.Get(player)
	if not profile or not profile.Stats or player.UserId <= 0 then
		return
	end
	local cc = countryOf(player)
	for metric in pairs(METRICS) do
		local value = math.floor(profile.Stats[metric] or 0)
		if value > 0 then
			for _, scope in ipairs({ "Global", cc }) do
				local store = storeFor(scope, metric)
				if store then
					pcall(function()
						store:SetAsync(tostring(player.UserId), value)
					end)
				end
			end
		end
	end
end

-- The players in this server, ranked (fallback + always fresh).
local function serverBoard(metric: string, country: string?): { any }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local profile = DataService.Get(p)
		if profile and (not country or countryOf(p) == country) then
			table.insert(list, { userId = p.UserId, name = p.Name, value = profile.Stats and profile.Stats[metric] or 0 })
		end
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	for i, e in ipairs(list) do
		e.rank = i
	end
	return list
end

local function fetch(scope: string, metric: string): { any }?
	local key = scope .. "|" .. metric
	local hit = cache[key]
	if hit and os.clock() - hit.at < CACHE_SECS then
		return hit.entries
	end
	local store = storeFor(scope, metric)
	if not store then
		return nil
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, TOP):GetCurrentPage()
	end)
	if not ok or typeof(page) ~= "table" then
		return nil
	end
	local entries = {}
	for i, row in ipairs(page) do
		local userId = tonumber(row.key) or 0
		table.insert(entries, { rank = i, userId = userId, name = nameOf(userId), value = row.value })
	end
	cache[key] = { at = os.clock(), entries = entries }
	return entries
end

function LeaderboardService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local ok, cc = pcall(function()
				return LocalizationService:GetCountryRegionForPlayerAsync(player)
			end)
			player:SetAttribute("Country", ok and cc or "US")
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			local ok, cc = pcall(function()
				return LocalizationService:GetCountryRegionForPlayerAsync(p)
			end)
			p:SetAttribute("Country", ok and cc or "US")
		end)
	end
	Players.PlayerRemoving:Connect(publish)

	task.spawn(function()
		while true do
			task.wait(PUBLISH_SECS)
			for _, p in ipairs(Players:GetPlayers()) do
				publish(p)
				task.wait(0.5)
			end
		end
	end)

	Remotes.Get("GetLeaderboard").OnServerInvoke = function(player, payload)
		local metric = typeof(payload) == "table" and payload.metric or "Eliminations"
		if not METRICS[metric] then
			metric = "Eliminations"
		end
		local country = countryOf(player)
		local wantCountry = typeof(payload) == "table" and payload.scope == "Country"
		local scope = wantCountry and country or "Global"
		local entries = fetch(scope, metric)
		local live = false
		if not entries or #entries == 0 then
			entries = serverBoard(metric, wantCountry and country or nil)
			live = true
		end
		return { ok = true, country = country, metric = metric, live = live, entries = entries }
	end
end

return LeaderboardService
