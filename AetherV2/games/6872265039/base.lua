local run = function(func)
	local success, result = xpcall(func, debug and debug.traceback or tostring)
	if not success then
		warn('[AetherV2] Skipped a module during startup: '..tostring(result))
	end
	local yieldBuild = shared.vape and shared.vape.YieldBuild
	if yieldBuild then yieldBuild() end
	return success
end
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local runService = cloneref(game:GetService('RunService')) 
local httpService = cloneref(game:GetService('HttpService'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local bedwars = {}

local function notif(...)
	return vape:CreateNotification(...)
end

run(function()
	local function dumpRemote(tab)
		local ind = table.find(tab, 'Client')
		return ind and tab[ind + 1] or ''
	end
	local KnitInit, Knit
	local knitDeadline = tick() + 45
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit and Knit then break end
		task.wait(0.1)
	until tick() > knitDeadline
	if not (KnitInit and Knit) then
		error('Knit never became available - the game has not finished loading')
	end

	if not debug.getupvalue(Knit.Start, 1) then
		local upvalueDeadline = tick() + 15
		repeat task.wait(0.1) until debug.getupvalue(Knit.Start, 1) or tick() > upvalueDeadline
		if not debug.getupvalue(Knit.Start, 1) then
			error('debug.getupvalue is unavailable on this executor')
		end
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local igniteDeadline = tick() + 45
	repeat
		local ok, ignited = pcall(debug.getupvalue, Flamework.ignite, 1)
		if not ok or type(ignited) ~= 'boolean' or ignited then break end
		task.wait(0.1)
	until tick() > igniteDeadline
	local controllers = {Built = {}, Ids = {
		'@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController',
		'@easy-games/game-core:client/controllers/notification-controller@NotificationController',
		'@easy-games/lobby:client/controllers/party-controller@PartyController'
	}}
	local function findController(id, again)
		if again or not controllers.Scanned then
			controllers.Scanned = true
			local delta = false
			if identifyexecutor then
				local named, executor = pcall(identifyexecutor)
				delta = named and tostring(executor):lower():find('delta', 1, true) ~= nil
			end
			local ok, core = pcall(function()
				return require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out)
			end)
			local known = ok and type(core) == 'table' and type(core.Reflect) == 'table' and core.Reflect.idToObj or nil
			local singletons
			if delta and ok and type(core) == 'table' and type(core.Modding) == 'table' and type(core.Modding.getSingletons) == 'function' then
				local got, map = pcall(core.Modding.getSingletons)
				singletons = got and type(map) == 'table' and map or nil
			end
			local classes, left = {}, 0
			if type(known) == 'table' and (delta or getgc) then
				for _, wanted in again or controllers.Ids do
					local class = known[wanted]
					if type(class) == 'table' and not classes[class] then
						local built = singletons and rawget(singletons, class)
						if type(built) == 'table' and getmetatable(built) == class then
							controllers.Built[wanted] = built
						else
							classes[class] = wanted
							left += 1
						end
					end
				end
			end
			if left > 0 and not delta and getgc then
				for _, v in getgc(true) do
					if type(v) == 'table' then
						local meta = getmetatable(v)
						local wanted = meta ~= nil and classes[meta]
						if wanted then
							controllers.Built[wanted] = v
							classes[meta] = nil
							left -= 1
							if left == 0 then break end
						end
					end
				end
			end
		end
		return id and controllers.Built[id] or nil
	end
	local missingControllers = {}
	local function resolveController(id)
		local found = findController(id)
		if found then return found end
		local ok, result = pcall(Flamework.resolveDependency, id)
		if ok and result ~= nil then return result end
		local name = id:match('@(%w+)$') or id
		warn('[AetherV2] '..name..' is not available in this place: '..tostring(result))
		local stub = setmetatable({}, {
			__index = function()
				return function() end
			end
		})
		missingControllers[name] = {Id = id, Stub = stub, Tries = 0}
		return stub
	end
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get
	local function safeGetProto(func, index)
		if not func or not debug or type(debug.getproto) ~= 'function' then return nil end
		local success, proto = pcall(debug.getproto, func, index)
		if success then
			return proto
		else
			warn("function:", func, "index:", index) 
			return nil
		end
	end

	bedwars = setmetatable({
	 	MatchHistroyApp = require(lplr.PlayerScripts.TS.controllers.global["match-history"].ui["match-history-moderation-app"]).MatchHistoryModerationApp,
	 	MatchHistroyController = Knit.Controllers.MatchHistoryController,
		AbilityController = resolveController('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		MatchHistoryController = require(lplr.PlayerScripts.TS.controllers.global['match-history']['match-history-controller']),
		PlayerProfileUIController = require(lplr.PlayerScripts.TS.controllers.global['player-profile']['player-profile-ui-controller']),
		TitleTypes = require(game.ReplicatedStorage.TS.locker.title['title-type']).TitleType,
		TitleTypesMeta =  require(game.ReplicatedStorage.TS.locker.title['title-meta']).TitleMeta,
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		NotificationController = resolveController('@easy-games/game-core:client/controllers/notification-controller@NotificationController'),
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		MilestoneRewards = require(replicatedStorage.TS.milestones.milestones).MilestoneRewards,
		NametagController = Knit.Controllers.NametagController,
		PartyController = resolveController('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network),
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})
	for name, get in {
		GamePlayerUtil = function() return require(replicatedStorage.TS.player['player-util']).GamePlayerUtil end,
		EmoteDisplayMeta = function() return require(replicatedStorage.TS.locker.emote['emote-display-meta']).EmoteDisplayMeta end,
		EmoteMeta = function() return require(replicatedStorage.TS.locker.emote['emote-meta']).EmoteMeta end
	} do
		if rawget(bedwars, name) == nil then
			local ok, value = pcall(get)
			if ok then rawset(bedwars, name, value) end
		end
	end

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	vape:Clean(function()
		table.clear(bedwars)
	end)
end)

local function activeLobbyKit()
	local values = {
		lplr:GetAttribute('PlayingAsKit'),
		lplr:GetAttribute('PlayingAsKits'),
		lplr:GetAttribute('SelectedKit'),
		lplr:GetAttribute('Kit'),
		lplr:GetAttribute('kit')
	}
	local ready = bedwars.Store ~= nil
	if bedwars.Store then
		local ok, state = pcall(bedwars.Store.getState, bedwars.Store)
		ready = ok and type(state) == 'table'
		if ready then
			local kit = state.Kit or state.kit or {}
			local locker = state.Locker or state.locker or {}
			local bedwarsState = state.Bedwars or state.BedWars or {}
			table.insert(values, 1, kit.kit or kit.equippedKit or kit.selectedKit
				or locker.equippedKit or locker.selectedKit
				or bedwarsState.kit or bedwarsState.equippedKit)
		end
	end
	for _, value in values do
		if value ~= nil and value ~= '' and value ~= 'none' then return tostring(value), true end
	end
	return nil, ready
end

if type(vape.SetGameInfo) == 'function' then
	vape:SetGameInfo({Name = 'BedWars', GetKit = activeLobbyKit})
end


getgenv()._aeroTierReady = true
local function getAccountTier(player)
    return 0
end

getgenv().getAeroTier = function(player)
    return getAccountTier(player)
end  
do
	local remove = {}
	for i, v in vape.Modules do
		if v.Category == 'Combat' then
			table.insert(remove, i)
		end
	end
	for _, i in remove do
		vape:Remove(i)
	end
	for _, v in {'AirWalk', 'AnimationPlayer', 'AntiFling', 'AntiKillParts', 'AutoObby', 'ClickTP', 'DeathSpawn', 'Disabler', 'FastClimb', 'ForceShiftLock', 'Glide',
		'HitBoxes', 'Killaura', 'LongJump', 'NoFallDamage', 'NoSlide', 'Parkour', 'PromptAura', 'StateSpoofer', 'Step', 'TargetStrafe', 'Timer', 'Wallhop'} do
		vape:Remove(v)
	end
end

local spoof = {Fns = {}, Order = {}, Holds = {}}
do
	local function copy(tab)
		local new = {}
		for k, v in tab do
			new[k] = v
		end
		return new
	end
	spoof.copy = copy

	function spoof.edit(tab, keys, fn, index)
		index = index or 1
		if type(tab) ~= 'table' then return tab end
		local key = keys[index]
		local new = copy(tab)
		if index == #keys then
			new[key] = fn(tab[key])
		else
			if type(tab[key]) ~= 'table' then return tab end
			new[key] = spoof.edit(tab[key], keys, fn, index + 1)
		end
		return new
	end

	function spoof.profiles(state, fn)
		state = spoof.edit(state, {'Lobby', 'profileData'}, function(data)
			return type(data) == 'table' and fn(data) or data
		end)
		local viewing = state.Lobby and state.Lobby.currentlyViewingProfileData
		if type(viewing) == 'table' and viewing.userId == lplr.UserId then
			state = spoof.edit(state, {'Lobby', 'currentlyViewingProfileData'}, fn)
		end
		return state
	end

	local function apply(state)
		for _, name in spoof.Order do
			local fn = spoof.Fns[name]
			if fn then
				local ok, result = pcall(fn, state)
				if ok and type(result) == 'table' then
					state = result
				elseif not ok and not spoof.Warned then
					spoof.Warned = true
					warn('[AetherV2] '..name..' could not apply: '..tostring(result))
				end
			end
		end
		return state
	end

	local wrapper
	local function install()
		local store = bedwars.Store
		if spoof.Store then return true end
		if type(store) ~= 'table' or type(rawget(store, '_reducer')) ~= 'function' then return false end
		spoof.Store, spoof.Reducer, spoof.Real = store, store._reducer, store._state
		wrapper = function(_, action)
			spoof.Real = spoof.Reducer(spoof.Real, action)
			if spoof.Watch then
				for _, watcher in spoof.Watch do
					pcall(watcher, action, spoof.Real)
				end
			end
			return apply(spoof.Real)
		end
		store._reducer = wrapper
		return true
	end

	local function uninstall()
		local store = spoof.Store
		if not store then return end
		if store._reducer == wrapper then
			store._reducer = spoof.Reducer
			store._state = spoof.Real
		end
		spoof.Store, spoof.Reducer, spoof.Real, wrapper = nil, nil, nil, nil
		pcall(store.dispatch, store, {type = 'AetherSpoofRefresh'})
	end

	function spoof.Refresh()
		if not spoof.Store or spoof.Queued then return end
		spoof.Queued = true
		task.defer(function()
			spoof.Queued = nil
			if spoof.Store then
				pcall(spoof.Store.dispatch, spoof.Store, {type = 'AetherSpoofRefresh'})
			end
		end)
	end

	function spoof.State()
		if spoof.Store then return spoof.Real end
		local ok, state = pcall(function() return bedwars.Store:getState() end)
		return ok and state or {}
	end

	function spoof.Set(name, fn)
		if not table.find(spoof.Order, name) then
			table.insert(spoof.Order, name)
		end
		spoof.Fns[name] = fn
		if install() then
			spoof.Refresh()
		end
	end

	function spoof.Remove(name)
		local index = table.find(spoof.Order, name)
		if index then
			table.remove(spoof.Order, index)
		end
		spoof.Fns[name] = nil
		if #spoof.Order == 0 and not (spoof.Watch and next(spoof.Watch)) then
			uninstall()
		else
			spoof.Refresh()
		end
	end

	function spoof.OnAction(name, fn)
		spoof.Watch = spoof.Watch or {}
		spoof.Watch[name] = fn
		install()
	end

	function spoof.Hold(name, inst, attribute, value)
		local key = attribute
		local hold = spoof.Holds[key]
		if value == nil then
			if not hold then return end
			local index = table.find(hold.Order, name)
			if index then
				table.remove(hold.Order, index)
			end
			hold.Owners[name] = nil
			local top = hold.Order[#hold.Order]
			if top then
				hold.Value = hold.Owners[top]
			else
				spoof.Holds[key] = nil
				hold.Connection:Disconnect()
				hold.Value = hold.Original
			end
			if inst.Parent and inst:GetAttribute(attribute) ~= hold.Value then
				inst:SetAttribute(attribute, hold.Value)
			end
			return
		end
		if not hold then
			hold = {Original = inst:GetAttribute(attribute), Owners = {}, Order = {}}
			hold.Connection = inst:GetAttributeChangedSignal(attribute):Connect(function()
				local current = inst:GetAttribute(attribute)
				if current ~= hold.Value then
					hold.Original = current
					inst:SetAttribute(attribute, hold.Value)
				end
			end)
			spoof.Holds[key] = hold
		end
		local index = table.find(hold.Order, name)
		if index then
			table.remove(hold.Order, index)
		end
		table.insert(hold.Order, name)
		hold.Owners[name] = value
		hold.Value = value
		if inst:GetAttribute(attribute) ~= value then
			inst:SetAttribute(attribute, value)
		end
	end

	function spoof.HoldValue(name, inst, value)
		local key = name..':'..inst:GetFullName()
		local hold = spoof.Holds[key]
		if value == nil then
			if hold then
				spoof.Holds[key] = nil
				hold.Connection:Disconnect()
				if inst.Parent then
					inst.Value = hold.Original
				end
			end
			return
		end
		if not hold then
			hold = {Original = inst.Value}
			hold.Connection = inst.Changed:Connect(function(current)
				if current ~= hold.Value then
					hold.Original = current
					inst.Value = hold.Value
				end
			end)
			spoof.Holds[key] = hold
		end
		hold.Value = value
		if inst.Value ~= value then
			inst.Value = value
		end
	end

	function spoof.Enum(folder, module, field)
		local values = {}
		local ok, enum = pcall(function()
			local inst = folder and replicatedStorage.TS.locker:FindFirstChild(folder)
			inst = inst and inst:FindFirstChild(module) or replicatedStorage.TS:FindFirstChild(module, true)
			return require(inst)[field]
		end)
		if ok and type(enum) == 'table' then
			for _, v in enum do
				if v ~= 'none' and v ~= 'None' and v ~= '' then
					table.insert(values, v)
				end
			end
		end
		table.sort(values, function(a, b) return tostring(a) < tostring(b) end)
		return values
	end

	vape:Clean(function()
		for key, hold in spoof.Holds do
			pcall(function() hold.Connection:Disconnect() end)
		end
		table.clear(spoof.Holds)
		table.clear(spoof.Order)
		table.clear(spoof.Fns)
		spoof.Watch = nil
		uninstall()
	end)
end
