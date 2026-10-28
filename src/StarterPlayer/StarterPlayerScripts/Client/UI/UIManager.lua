--!strict
-- uimanager: builds the screens and switches between them by where your cat
-- is (the player's "context" attribute) and the match phase:
--   * lobby: the menu overlay (icons + play) while you walk round with a free
--     mouse; step into the practice range and you aim and shoot like in a
--     match. once you're queued, the countdown flies over the arena.
--   * match: the in-match hud; at the end your last knockout replays, then
--     the podium and results. then everyone who played is back in the lobby.
--   * duel: the match hud without the team scores.
-- before your cat first spawns, the menu camera shows the 3d lobby scene.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local UIUtil = require(script.Parent.UIUtil)
local ClientState = require(script.Parent.Parent.ClientState)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local MainMenu = require(script.Parent.Screens.MainMenu)
local HUD = require(script.Parent.Screens.HUD)
local Results = require(script.Parent.Screens.Results)
local Intro = require(script.Parent.Screens.Intro)

local CameraController = require(script.Parent.Parent.Controllers.CameraController)
local LobbyLook = require(script.Parent.Parent.Controllers.LobbyLook)
local ReplayController = require(script.Parent.Parent.Controllers.ReplayController)
local CombatController = require(script.Parent.Parent.Controllers.CombatController)
local LobbyScene = require(script.Parent.Parent.Lobby.LobbyScene)

local UIManager = {}
local player = Players.LocalPlayer
local lastPhase = nil
local alive = false
local transitionFrame: Frame? = nil
local fallbackGui: ScreenGui? = nil

-- the practice centre (through the portal behind spawn): a box round the
-- lobby's "range" point the size of its platform.
local RANGE_HALF = 60
-- the countdown flyover stays up until the server has dropped you into the
-- arena (a few seconds at most), so the lobby doesn't flash in between.
local flyoverUntil = 0

-- a real, clickable launch surface kept outside the large decorative menu.
-- if a future art/card change ever fails during startup, players still get
-- the intended landing -> map choice -> countdown flow instead of a blank ui.
local function buildFallbackLanding()
	if fallbackGui then
		fallbackGui.Enabled = true
		return
	end

	fallbackGui = UIUtil.make("ScreenGui", {
		Name = "PawFallbackLanding",
		Parent = player:WaitForChild("PlayerGui"),
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 90,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	local backdrop = UIUtil.make("Frame", {
		Parent = fallbackGui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(74, 164, 224),
		BorderSizePixel = 0,
	}) :: Frame
	UIUtil.gradient(Color3.fromRGB(143, 218, 255), Color3.fromRGB(36, 91, 166), 90, backdrop)

	local card = UIUtil.panel({
		Parent = backdrop,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(650, 430),
		BackgroundColor3 = Theme.Color.PanelDark,
	})
	UIUtil.padding(28, card)
	UIUtil.label({ Parent = card, Text = "PAW", Font = Theme.Font.Title, TextSize = 68, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 82), TextStrokeTransparency = 0.55 })
	UIUtil.label({ Parent = card, Text = "MAYHEM", Font = Theme.Font.Title, TextSize = 34, TextColor3 = Theme.Color.Coin, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 42) })
	UIUtil.label({ Parent = card, Text = "Choose an arena to start the match", TextColor3 = Theme.Color.TextDim, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, 0, 0, 24) })

	local status = UIUtil.label({ Parent = card, Text = "MAP SELECT", Font = Theme.Font.Bold, TextColor3 = Theme.Color.Accent, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 20) })
	local maps = {
		{ id = "SkyIslands", name = "SKY ISLANDS", color = Color3.fromRGB(45, 160, 239) },
		{ id = "Volcano", name = "VOLCANO", color = Color3.fromRGB(221, 84, 64) },
		{ id = "Toybox", name = "TOYBOX", color = Color3.fromRGB(216, 99, 176) },
		{ id = "Rooftops", name = "ROOFTOPS", color = Color3.fromRGB(150, 100, 220) },
	}
	local row = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1 }) :: Frame
	UIUtil.listLayout(row, 12, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Center
	for _, map in ipairs(maps) do
		local chosen = map
		local button = UIUtil.button({ Parent = row, Size = UDim2.fromOffset(174, 68), BackgroundColor3 = chosen.color, Text = chosen.name, Font = Theme.Font.Title, TextSize = 15, CornerRadius = Theme.CornerSmall }, function()
			status.Text = "LOADING " .. chosen.name .. "..."
			Remotes.Get("RequestJoinMatch"):FireServer({ mapId = chosen.id })
		end)
		button.TextWrapped = true
	end
	UIUtil.label({ Parent = card, Text = "Team Deathmatch  •  3 maps  •  Pick a map, then drop in", TextColor3 = Theme.Color.TextMuted, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 292), Size = UDim2.new(1, 0, 0, 22) })
end

local function playTransition()
	if not transitionFrame then return end
	transitionFrame.BackgroundTransparency = 0.02
	TweenService:Create(transitionFrame, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

local function buildTransitionLayer()
	local fadeGui = Instance.new("ScreenGui")
	fadeGui.Name = "PawTransition"
	fadeGui.IgnoreGuiInset = true
	fadeGui.ResetOnSpawn = false
	fadeGui.DisplayOrder = 100
	fadeGui.Parent = player:WaitForChild("PlayerGui")
	transitionFrame = Instance.new("Frame")
	transitionFrame.Size = UDim2.fromScale(1, 1)
	transitionFrame.BackgroundColor3 = Theme.Color.Bg
	transitionFrame.BackgroundTransparency = 1
	transitionFrame.BorderSizePixel = 0
	transitionFrame.Parent = fadeGui
end

local function context(): string?
	local c = player:GetAttribute("Context")
	return typeof(c) == "string" and c or nil
end

local function queuedCountdown(): boolean
	return context() == "Lobby" and player:GetAttribute("Queued") == true and ClientState.Match.phase == "Countdown"
end

local function inPracticeRange(): boolean
	local lobby = Workspace:FindFirstChild("Lobby")
	local c = lobby and lobby:GetAttribute("Range")
	local root = player.Character and player.Character.PrimaryPart
	if typeof(c) ~= "Vector3" or not root then
		return false
	end
	local d = root.Position - c
	return math.abs(d.X) < RANGE_HALF and math.abs(d.Z) < RANGE_HALF and math.abs(d.Y) < 30
end

-- aim + shoot, or a free mouse: in a match or duel you aim unless a screen
-- (loadout) is open over it; in the lobby only inside the practice range.
-- checked a few times a second.
local aiming: boolean? = nil
local function updateAim(force: boolean?)
	local ctx = context()
	local fighting = ctx == "Match" or ctx == "Duel"
	if not alive or not (fighting or ctx == "Lobby") or queuedCountdown()
		or (ctx == "Match" and ClientState.Match.phase == "Results") then
		aiming = nil
		return
	end
	local busy = MainMenu.Busy()
	CameraController.SetMenuOpen(busy)
	local aim = not busy and (fighting or inPracticeRange())
	if aim == aiming and not force then
		return
	end
	aiming = aim
	CameraController.SetFreeMouse(not aim)
	CombatController.SetEnabled(aim)
	if ctx == "Lobby" then
		HUD.SetMode(aim and "Range" or "Lobby")
		MainMenu.SetRangeMode(aim)
	end
end

-- which screen state we picked last (printed to output when it changes, so a
-- wrong screen can be tracked down from the log).
local lastView = ""
local function trace(view: string)
	local line = string.format("%s (context=%s, alive=%s, phase=%s)", view, tostring(context()), tostring(alive), tostring(ClientState.Match.phase))
	if line ~= lastView then
		lastView = line
		print("[PAW MAYHEM] screen: " .. line)
	end
end

-- put the screen in the right state for where the cat is and the phase.
local function refresh()
	local ctx = context()
	local phase = ClientState.Match.phase
	LobbyLook.Set(ctx == "Lobby")
	if not (ctx == "Lobby" and (queuedCountdown() or os.clock() < flyoverUntil)) then
		CameraController.SetFlyover(false)
	end
	if ctx == "Match" or ctx == "Duel" then
		trace("fighting")
		flyoverUntil = 0
		if fallbackGui then fallbackGui.Enabled = false end
		if not MainMenu.InGameOpen() then
			MainMenu.SetVisible(false)
		end
		if phase == "Results" and ctx == "Match" then
			MainMenu.SetVisible(false)
			return -- the replay and podium have the screen (see onphase)
		end
		CameraController.SetLobbyView(false)
		HUD.SetMode(ctx)
		HUD.SetVisible(alive)
		Results.Hide()
		if alive then
			CameraController.SetEnabled(true)
			updateAim(true)
		end
	elseif ctx == "Lobby" and alive then
		trace("lobby")
		if fallbackGui then fallbackGui.Enabled = false end
		Results.Hide()
		CameraController.SetShowcase(nil)
		CameraController.SetLobbyView(false)
		if queuedCountdown() or os.clock() < flyoverUntil then
			-- queued and about to drop in: fly over the arena.
			if queuedCountdown() then
				flyoverUntil = math.huge
			end
			MainMenu.SetVisible(false)
			CameraController.SetEnabled(false)
			CombatController.SetEnabled(false)
			HUD.SetMode("Lobby")
			HUD.SetVisible(true)
			CameraController.SetFlyover(true)
			return
		end
		flyoverUntil = 0
		CameraController.SetFlyover(false)
		if not Intro.Running then
			MainMenu.SetVisible(true)
		end
		HUD.HideBig()
		HUD.SetVisible(true)
		CameraController.SetEnabled(true)
		updateAim(true)
	else
		-- not spawned yet: the menu over the 3d lobby scene.
		trace("menu backdrop (no cat yet)")
		HUD.SetVisible(false)
		CameraController.SetEnabled(false)
		CombatController.SetEnabled(false)
		CameraController.SetLobbyView(true)
		if not Intro.Running then
			MainMenu.SetVisible(true)
		end
	end
end

local function onCharacter(char)
	alive = true
	CameraController.SetSpectate(nil)
	-- wait a beat for parts (and the context attribute) to settle
	task.wait(0.2)
	if char ~= player.Character then
		return
	end
	if context() == "Match" and ClientState.Match.phase == "Playing" then
		HUD.StartTips()
	end
	refresh()
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			alive = false
			-- stay where you are for the kill-cam (no lobby view while dead).
			CameraController.SetEnabled(false)
			CombatController.SetEnabled(false)
		end)
	end
end

-- camera shot of the winners' podium, sent by the server at match end.
local podiumShot: CFrame? = nil

local function onPhase(m)
	local phase = m.phase
	if phase == lastPhase then
		-- still update sub-states (e.g. countdown numbers handled by screens)
		if phase == "Countdown" and queuedCountdown() then
			HUD.ShowBig(tostring(m.timeLeft or 0), Theme.Color.Text)
		elseif phase == "Results" and context() == "Match" then
			Results.Update(m)
		end
		return
	end
	lastPhase = phase
	if phase ~= "Results" then
		podiumShot = nil
		CameraController.SetShowcase(nil)
	end
	if phase ~= "Playing" then
		CameraController.SetSpectate(nil)
	else
		ReplayController.Clear() -- a fresh match: only this match's knockouts replay
	end
	if phase == "Playing" and flyoverUntil == math.huge then
		-- dropping in now: hold the flyover until our arena cat arrives.
		flyoverUntil = os.clock() + 4
		task.delay(4.1, refresh)
	elseif phase ~= "Countdown" and phase ~= "Playing" then
		flyoverUntil = 0
	end

	if phase == "Countdown" and queuedCountdown() then
		playTransition()
		refresh()
		HUD.ShowBig("GET READY", Theme.Color.Warn)
	elseif phase == "Playing" and context() == "Match" then
		playTransition()
		HUD.HideBig()
		refresh()
	elseif phase == "Results" and context() == "Match" then
		playTransition()
		HUD.SetVisible(false)
		CameraController.SetEnabled(false)
		CombatController.SetEnabled(false)
		local function showResults()
			if lastPhase ~= "Results" then
				return
			end
			if podiumShot then
				CameraController.SetLobbyView(false)
				CameraController.SetShowcase(podiumShot)
			end
			Results.Show(ClientState.Match)
		end
		-- your last knockout first (if you got one), then the podium.
		if ReplayController.HasClip() then
			CameraController.SetLobbyView(false)
			ReplayController.Play(showResults)
		else
			showResults()
		end
	else
		refresh()
	end
end

function UIManager.Start()
	task.spawn(require(script.Parent.UIJuice).Start)
	-- kill-cam: watch whoever eliminated you.
	Remotes.Get("Eliminated").OnClientEvent:Connect(function(data)
		local by = typeof(data) == "table" and data.by or nil
		local target: Model? = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.DisplayName == by and p.Character then
				target = p.Character
			end
		end
		if not target and typeof(by) == "string" then
			local m = workspace:FindFirstChild(by)
			target = m and m:IsA("Model") and m or nil
		end
		CameraController.SetSpectate(target)
		if target then
			HUD.Announce({ title = "KNOCKED OUT BY " .. string.upper(tostring(by)), sub = "Spectating until you respawn", small = true, color = Color3.fromRGB(255, 120, 120) })
		end
	end)
	Remotes.Get("Podium").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and typeof(data.camera) == "CFrame" then
			podiumShot = data.camera
			if ClientState.Match.phase == "Results" and context() == "Match" and not ReplayController.HasClip() then
				CameraController.SetLobbyView(false)
				CameraController.SetShowcase(podiumShot)
			end
		end
	end)
	local sceneOk, sceneErr = pcall(LobbyScene.Build)
	if not sceneOk then
		warn("[PAW MAYHEM] Lobby scene failed to build: " .. tostring(sceneErr))
	end
	local menuOk, menuErr = pcall(MainMenu.Build)
	if not menuOk then
		warn("[PAW MAYHEM] Main menu failed to build; using launch fallback: " .. tostring(menuErr))
		buildFallbackLanding()
	end
	local hudOk, hudErr = pcall(HUD.Build)
	if not hudOk then
		warn("[PAW MAYHEM] HUD failed to build: " .. tostring(hudErr))
	end
	pcall(require(script.Parent.Screens.EndScreen).Build)
	pcall(require(script.Parent.Celebrate).Build)
	local resultsOk, resultsErr = pcall(Results.Build)
	if not resultsOk then
		warn("[PAW MAYHEM] Results screen failed to build: " .. tostring(resultsErr))
	end
	-- the results screen, the daily calendar and the hud onto the clean look too.
	local playerGui = player:WaitForChild("PlayerGui")
	for _, name in ipairs({ "PawResults", "PawDaily", "PawHUD" }) do
		local g = playerGui:FindFirstChild(name)
		if g then
			UIUtil.restyle(g)
		end
	end
	-- every screen gets the raised, glossy finish (the in-match hud only gets
	-- the finish, nothing added; not the cinematic screens).
	local SKIP_POLISH = { PawEndScreen = true, PawCelebrate = true, PawTutorial = true, PawIntro = true, PawReplay = true }
	local function polishGui(g: Instance)
		if g:IsA("ScreenGui") and string.sub(g.Name, 1, 3) == "Paw" and not SKIP_POLISH[g.Name] then
			UIUtil.polish(g)
		end
	end
	for _, g in ipairs(playerGui:GetChildren()) do
		polishGui(g)
	end
	playerGui.ChildAdded:Connect(polishGui)
	buildTransitionLayer()
	CameraController.SetLobbyView(true)

	ClientState.MatchChanged:Connect(onPhase)
	-- mid-match loadout: the loadout screen over the game.
	HUD.OnLoadout = function()
		MainMenu.OpenInGame("Loadout")
	end

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		task.spawn(onCharacter, char)
	end)
	player.CharacterRemoving:Connect(function()
		alive = false
		CameraController.SetEnabled(false)
		CombatController.SetEnabled(false)
	end)
	-- lobby <-> match <-> duel, and joining / leaving the queue.
	player:GetAttributeChangedSignal("Context"):Connect(function()
		playTransition()
		refresh()
	end)
	player:GetAttributeChangedSignal("Queued"):Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(0.15)
			updateAim()
		end
	end)

	-- apply current state on start
	onPhase(ClientState.Match)

	-- tells the replicatedfirst loading screen the home screen is ready.
	player:SetAttribute("CattoLobbyReady", true)
end

return UIManager
