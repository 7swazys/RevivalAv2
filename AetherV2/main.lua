local license = ... or {}
if type(license) ~= 'table' then license = {} end
local launch = shared.AetherV2Loading
local function superseded()
	return type(launch) == 'table' and launch.Superseded == true
end
local function waitForGame()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
end
local function report(kind, code, message)
	local telemetry = shared.AetherTelemetry
	if telemetry and telemetry.Report then
		pcall(telemetry.Report, kind, code, tostring(message))
	end
end
local trail = type(shared.AetherStartup) == 'table' and shared.AetherStartup or nil
local function mark(stage)
	if trail and trail.Mark then trail.Mark(stage) end
end

local vape
local rawLoadstring = loadstring
local loadstring = function(...)
	local res, err = rawLoadstring(...)
	if err and vape then
		vape:CreateNotification('AetherV2', 'Failed to load : '..err, 30, 'alert')
	end
	return res, err
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local starterGui = cloneref(game:GetService('StarterGui'))

local SOURCE_COMMIT = 'main'
local BEDWARS_UNIVERSE = 2619619496
local PLACE_ALIAS = {
	[6872265039] = 6872265039,
	[16008862571] = 6872265039,
	[6872274481] = 6872274481,
	[8444591321] = 6872274481,
	[8560631822] = 6872274481,
	[132768098780837] = 6872274481,
	[8768229691] = 8768229691,
	[8542275097] = 8768229691,
	[8592115909] = 8768229691,
	[8951451142] = 8768229691,
	[13246639586] = 8768229691,
	[8542259458] = 8768229691,
	[71480482338212] = 71480482338212,
	[71657866091528] = 71480482338212,
	[74441430126650] = 71480482338212,
}
local DOWNLOAD_BATCH = 24

local function toast(title, text, duration)
	pcall(function()
		starterGui:SetCore('SendNotification', {
			Title = title or 'AetherV2',
			Text = text or '',
			Duration = duration or 6
		})
	end)
end

local function ensureParentFolder(path)
	local parent = path:match('^(.*)/[^/]+$')
	if not parent or parent == '' then
		return
	end
	local acc = ''
	for part in string.gmatch(parent, '[^/]+') do
		acc = acc == '' and part or (acc..'/'..part)
		if not isfolder(acc) then
			pcall(makefolder, acc)
		end
	end
end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://api.aetherv2.xyz/raw/'..SOURCE_COMMIT..'/'..select(1, path:gsub('aetherv2/', '')), true)
		end)
		if not suc or res == '404: Not Found' or (type(res) == 'string' and (res:find('^%s*<!doctype html') or res:find('^%s*Too many requests') or res:find('^%s*Retry later'))) then
			error(res)
		end
		ensureParentFolder(path)
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local function fetchRemote(rel, ref)
	local suc, res = pcall(function()
		return game:HttpGet('https://api.aetherv2.xyz/raw/'..(ref or SOURCE_COMMIT)..'/'..rel, true)
	end)
	if not suc or type(res) ~= 'string' then
		return nil
	end
	local head = res:sub(1, 300):lower()
	if res == '404: Not Found' or head:find('^%s*404') or head:find('^%s*<!doctype html') or head:find('^%s*<html')
		or head:find('^%s*too many requests') or head:find('^%s*retry later') then
		return nil
	end
	return res
end

local function parseFileList(list)
	local names, memory = {}, {}
	for line in string.gmatch(list, '[^\r\n]+') do
		line = line:gsub('^%s+', ''):gsub('%s+$', '')
		if line ~= '' and not line:find('^#') then
			local name = line:gsub('^!%s*', '')
			if name ~= line then memory[name] = true end
			table.insert(names, name)
		end
	end
	return names, memory
end
local PACK_HEADER = '--AetherV2 pack'

local function hashString(text)
	local hash = 2166136261
	for index = 1, #text do
		hash = bit32.bxor(hash, text:byte(index))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format('%08x', hash)
end
local function installedCommit()
	if type(shared.AetherV2Commit) == 'string' and shared.AetherV2Commit ~= '' then
		return shared.AetherV2Commit
	end
	if not isfile('aetherv2/profiles/commit.txt') then return 'main' end
	local ok, body = pcall(readfile, 'aetherv2/profiles/commit.txt')
	if ok and type(body) == 'string' then
		local commit = body:gsub('%s+', '')
		if commit ~= '' then return commit end
	end
	return 'main'
end

local function packKey(folder, list)
	return hashString(folder..'\n'..installedCommit()..'\n'..list)
end

local function packHeader(key, count)
	return PACK_HEADER..' key='..key..' count='..count..'\n'
end

local function packKeyOf(body)
	if type(body) ~= 'string' then return nil end
	local line = body:match('^[^\r\n]*')
	if not line or line:sub(1, #PACK_HEADER) ~= PACK_HEADER then return nil end
	return line:match('key=(%x+)')
end

local MEMORY_STUB = '--@aether-memory '

local function memoryBody(folder, name)
	local rel = 'games/'..folder..'/'..name
	if shared.VapeDeveloper and isfile('aetherv2/'..rel) then
		local ok, body = pcall(readfile, 'aetherv2/'..rel)
		if ok and type(body) == 'string' and body ~= '' then return body end
	end
	local ref = installedCommit()
	local body = fetchRemote(rel, ref)
	if not body then
		task.wait(1)
		body = fetchRemote(rel, ref)
	end
	if not body then error('unavailable') end
	return body
end

local function reportMissing(folder, missing)
	if #missing == 0 then return end
	local shown = {}
	for _, name in ipairs(missing) do
		table.insert(shown, name:match('([^/]+)%.lua$') or name)
	end
	warn('[AetherV2] '..folder..': could not load '..table.concat(missing, ', '))
	toast('AetherV2', 'Could not load '..table.concat(shown, ', ')..'. The rest loaded normally.', 10)
end

local function fillMemory(text, folder, names, memory)
	local bodies, pending = {}, 0
	for _, name in ipairs(names) do
		if memory[name] then
			pending += 1
			task.spawn(function()
				local ok, body = pcall(memoryBody, folder, name)
				if ok then bodies[name] = body end
				pending -= 1
			end)
		end
	end
	while pending > 0 do task.wait() end
	local parts, cursor, missing = {}, 1, {}
	for _, name in ipairs(names) do
		if memory[name] then
			local from, to = string.find(text, MEMORY_STUB..name, cursor, true)
			if from then
				table.insert(parts, text:sub(cursor, from - 1))
				table.insert(parts, bodies[name] or '')
				cursor = to + 1
				if not bodies[name] then table.insert(missing, name) end
			end
		end
	end
	table.insert(parts, text:sub(cursor))
	reportMissing(folder, missing)
	return table.concat(parts)
end

local function downloadParallel(folder, names, memory)
	local bodies = table.create(#names)
	local done, cursor = 0, 0
	while cursor < #names do
		cursor += 1
		local idx, name = cursor, names[cursor]
		task.spawn(function()
			local ok, body
			if memory[name] then
				ok, body = pcall(memoryBody, folder, name)
			else
				ok, body = pcall(downloadFile, 'aetherv2/games/'..folder..'/'..name)
			end
			if ok then
				bodies[idx] = body
			elseif not memory[name] then
				warn('[AetherV2] skipped '..folder..'/'..name..': '..tostring(body))
			end
			done += 1
		end)
		if cursor % DOWNLOAD_BATCH == 0 then
			repeat task.wait() until done >= cursor or (cursor - done) < DOWNLOAD_BATCH
		end
	end
	repeat task.wait() until done >= #names
	return bodies
end
local function packLooksValid(body)
	if type(body) ~= 'string' or #body < 4096 then return false end
	local head = body:sub(1, 8192)
	return head:find('run(function', 1, true) ~= nil
		or head:find('CreateModule', 1, true) ~= nil
		or head:find('vape', 1, true) ~= nil
end
local function fileMarker(name)
	return '--@aether-file '..tostring(name)..'\n'
end

local function rememberPackSource(folder, text)
	shared.AetherPackSources = shared.AetherPackSources or {}
	shared.AetherPackSources[folder] = text
end

local compilePack
do
	local keywords = {}
	for word in ('and break do else elseif end false for function if in local nil not or repeat return then true until while continue type export'):gmatch('%S+') do
		keywords[word] = true
	end
	local function packExport(text, folder)
		local seen, names = {}, {}
		for line in ('\n'..text):gmatch('\nlocal%s+([^\n]*)') do
			local fn = line:match('^function%s+([%a_][%w_]*)')
			local list = fn or line:match('^([^=]*)')
			for item in list:gmatch('[^,]+') do
				local name = item:match('^%s*([%a_][%w_]*)')
				if name and not keywords[name] and not seen[name] then
					seen[name] = true
					table.insert(names, name..'='..name)
				end
			end
		end
		return '\ndo shared.AetherPackExports = shared.AetherPackExports or {} shared.AetherPackExports['..string.format('%q', folder)..'] = {'..table.concat(names, ',')..'} end\n'
	end
	compilePack = function(text, folder)
		local chunk = rawLoadstring(text..packExport(text, folder), folder)
		if chunk then return chunk end
		return loadstring(text, folder)
	end
end

local function buildPack(job)
	local folder = job.Folder
	local listPath = 'aetherv2/games/'..folder..'/files.txt'

	local list = isfile(listPath) and select(2, pcall(readfile, listPath)) or nil
	if type(list) ~= 'string' or list == '' then
		list = fetchRemote('games/'..folder..'/files.txt')
		if list then
			ensureParentFolder(listPath)
			pcall(writefile, listPath, list)
		end
	end
	if type(list) ~= 'string' or list == '' then
		job.Error = 'no files.txt'
		return
	end
	local names, memory = parseFileList(list)
	if #names == 0 then
		job.Error = 'empty files.txt'
		return
	end
	job.Names = names
	job.Key = packKey(folder, list)
	local hasMemory = next(memory) ~= nil

	local packPath = 'aetherv2/games/'..folder..'/pack.lua'
	local detail = trail and trail.Detail
	if isfile(packPath) and not detail then
		local cached = select(2, pcall(readfile, packPath))
		if packKeyOf(cached) == job.Key and hasMemory then
			cached = fillMemory(cached, folder, names, memory)
		end
		if packKeyOf(cached) == job.Key and packLooksValid(cached) then
			local chunk, err = compilePack(cached, folder)
			if chunk then
				job.Chunk = chunk
				rememberPackSource(folder, cached)
				return
			end
			warn('[AetherV2] cached pack for '..folder..' does not compile: '..tostring(err))
		elseif packKeyOf(cached) == nil then
			warn('[AetherV2] discarding pack cache '..folder..' written by an older loader')
		else
			warn('[AetherV2] discarding stale pack cache '..folder..' (module list or release changed)')
		end
		pcall(delfile, packPath)
	end

	local bodies = downloadParallel(folder, names, memory)
	local chunks, stored, missing = {}, {}, {}
	local lost = 0
	for index = 1, #names do
		local name, body = names[index], bodies[index]
		if body then
			local crumb = detail and 'if shared.AetherStartup then shared.AetherStartup.Mark('..string.format('%q', 'pack '..folder..'/'..name)..') end\n' or ''
			table.insert(chunks, fileMarker(name)..crumb..body)
		elseif memory[name] then
			table.insert(missing, name)
		else
			lost += 1
		end
		if body or memory[name] then
			table.insert(stored, fileMarker(name)..(memory[name] and MEMORY_STUB..name or body))
		end
	end
	job.Bodies = bodies
	if lost > 0 then
		job.Error = 'incomplete module download ('..(#names - lost)..'/'..#names..')'
		warn('[AetherV2] '..folder..': '..job.Error)
		return
	end
	reportMissing(folder, missing)

	local packed = packHeader(job.Key, #names)..table.concat(chunks, '\n')
	local cacheText = hasMemory and packHeader(job.Key, #names)..table.concat(stored, '\n') or packed
	if not packLooksValid(packed) then
		job.Error = 'assembled pack failed validation'
		return
	end
	local chunk, err = compilePack(packed, folder)
	if not chunk then
		warn('[AetherV2] compile failed '..folder..': '..tostring(err))
		local kept, keptStored = {}, {}
		for index = 1, #names do
			local name, body = names[index], bodies[index]
			if body then
				local ok, oneErr = rawLoadstring(body, folder..'/'..name)
				if ok then
					table.insert(kept, fileMarker(name)..body)
					table.insert(keptStored, fileMarker(name)..(memory[name] and MEMORY_STUB..name or body))
				else
					warn('[AetherV2] skipping '..folder..'/'..name..': '..tostring(oneErr))
				end
			elseif memory[name] then
				table.insert(keptStored, fileMarker(name)..MEMORY_STUB..name)
			end
		end
		if #kept == 0 then return end
		packed = packHeader(job.Key, #kept)..table.concat(kept, '\n')
		cacheText = hasMemory and packHeader(job.Key, #keptStored)..table.concat(keptStored, '\n') or packed
		if not packLooksValid(packed) then return end
		chunk, err = compilePack(packed, folder)
		if not chunk then
			warn('[AetherV2] compile failed '..folder..' after skipping broken modules: '..tostring(err))
			return
		end
	end
	if not detail then
		ensureParentFolder(packPath)
		pcall(writefile, packPath, cacheText)
	end
	job.Chunk = chunk
	rememberPackSource(folder, packed)
end

local function preparePack(folder)
	local job = {Folder = folder, Ready = false}
	task.spawn(function()
		local ok, err = pcall(buildPack, job)
		if not ok then
			job.Error = tostring(err)
			warn('[AetherV2] pack preparation failed '..folder..': '..tostring(err))
		end
		job.Ready = true
	end)
	return job
end

local function runPack(job)
	if not job.Ready then
		repeat task.wait() until job.Ready
	end
	if job.Chunk then
		local ok, result = pcall(job.Chunk, license)
		if ok then
			return true
		end
		warn('[AetherV2] pack run failed '..job.Folder..': '..tostring(result))
		job.Error = job.Error or tostring(result)
		return false, result
	end
	local ran = 0
	if job.Bodies and job.Names then
		for index, name in ipairs(job.Names) do
			local body = job.Bodies[index]
			if body then
				local one, oneErr = loadstring(body, job.Folder..'/'..name)
				if one then
					if pcall(one, license) then
						ran += 1
					end
				else
					warn('[AetherV2] compile failed '..job.Folder..'/'..name..': '..tostring(oneErr))
				end
			end
		end
	else
		local reason = job.Error or 'no module sources'
		warn('[AetherV2] '..job.Folder..' modules unavailable: '..reason)
		return false, reason
	end
	return ran > 0, job.Error
end

local function resolvePlace()
	local id = game.PlaceId
	if PLACE_ALIAS[id] then
		return PLACE_ALIAS[id]
	end
	if game.GameId == BEDWARS_UNIVERSE then
		if id == 6872265039 or id == 16008862571 then
			return 6872265039
		end
		return 6872274481
	end
	if game.GameId == 7534782259 then
		return 71480482338212
	end
	if game.GameId == 3258873704 then
		return 8768229691
	end
	return id
end
local function armMatchHold()
	local env = getgenv and getgenv()
	if not env or env.matchDodgeHold then return end
	local function left(name)
		local ok, value = pcall(function()
			local path = 'aetherv2/profiles/'..name..'.txt'
			return isfile(path) and readfile(path)
		end)
		return ok and value == 'true'
	end
	env.matchDodgeActive = left('matchdodge')
	env.regionLockActive = left('regionlock')
	env.regionLockAllowed = not env.regionLockActive
	if not (env.matchDodgeActive or env.regionLockActive) then return end
	if not (hookmetamethod and newcclosure and checkcaller and getnamecallmethod) then return end
	if identifyexecutor and table.find({'Madium', 'Solara', 'Xeno'}, (identifyexecutor())) then return end
	local player = playersService.LocalPlayer
	if player and player:GetAttribute('PlayerConnected') then return end

	local hold = {Held = true, Claimed = false, Started = os.clock()}
	function hold.Release()
		if not hold.Held then return end
		hold.Held = false
		env.dodged = false
		if hold.Remote then
			pcall(function() hold.Remote:FireServer() end)
			hold.Remote = nil
		end
	end
	local old
	local hooked = pcall(function()
		old = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
			if hold.Held and not checkcaller() and getnamecallmethod() == 'FireServer' and tostring(self) == 'PlayerReady' then
				hold.Remote = self
				env.dodged = true
				return
			end
			return old(self, ...)
		end))
	end)
	if not hooked or not old then return end
	env.matchDodgeHold = hold
	task.delay(45, function()
		if not hold.Claimed then hold.Release() end
	end)
end
if tostring(PLACE_ALIAS[game.PlaceId]) == '6872274481' then
	pcall(armMatchHold)
end

local function finishLoading()
	vape.Init = nil
	mark('config')
	local loaded, loadError = pcall(function()
		vape:Load()
	end)
	if vape.CheckReviews then
		task.delay(3, function()
			pcall(vape.CheckReviews, vape)
		end)
	end
	if not loaded then
		warn('[AetherV2] config load failed: '..tostring(loadError))
		report('startup', 'config_load', loadError)
		pcall(function()
			vape:CreateNotification('AetherV2', 'Your config could not be loaded, so changes will not be saved this session: '..tostring(loadError):sub(1, 120), 20, 'alert')
		end)
	end
	task.spawn(function()
		local ticks = 0
		repeat
			pcall(function()
				ticks += 1
				if ticks % 6 == 0 then
					vape:Save()
				else
					vape:FlushPendingSave()
				end
			end)
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			local autoExecute = vape.AutoExecute
			if (autoExecute ~= nil and autoExecute.Enabled == false) or shared.AetherAutoExecute == false then
				return
			end
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('aetherv2/init.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://api.aetherv2.xyz/init.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			pcall(function()
				vape:Save()
			end)
			queue_on_teleport(teleportScript)
			if type(shared.AetherPremiumKey) == 'string' and shared.AetherPremiumKey:match('^[%w%-]+$') then
				teleportScript = 'shared.AetherPremiumKey = "'..shared.AetherPremiumKey..'"\n'..teleportScript
			end
		end
	end))

	mark('done')
	if trail then trail.Detail = nil end
	local bind = table.concat(vape.GUIBind and vape.GUIBind.Keys or vape.Keybind or {'RightShift'}, ' + '):upper()
	local msg = vape.VapeButton and 'Press the AetherV2 button to open GUI' or 'Press '..bind..' to open GUI'
	if vape.CreateNotification then
		pcall(function()
			vape:CreateNotification('Finished Loading', msg, 4)
		end)
		if shared.AetherTelemetry then
			pcall(shared.AetherTelemetry.ShowBanner, vape)
		end
		local update = type(shared.updated) == 'table' and shared.updated or nil
		if update and not update.Notified then
			update.Notified = true
			task.delay(1, function()
				local files = tonumber(update.Files) or 0
				local text
				if update.From and update.From ~= '' and update.To and update.To ~= '' then
					text = 'Script has updated from v'..update.From..' to v'..update.To..'. '..files..' files changed'
				elseif update.To and update.To ~= '' then
					text = 'Script has updated to v'..update.To..'. '..files..' files changed'
				else
					return
				end
				pcall(function()
					vape:CreateNotification('AetherV2', text, 10, 'info')
				end)
			end)
		end
	end
end

if not isfile('aetherv2/profiles/gui.txt') then
	writefile('aetherv2/profiles/gui.txt', 'new')
end
local gui = 'new'

if not isfolder('aetherv2/assets/'..gui) then
	makefolder('aetherv2/assets/'..gui)
end
local universalJob, placeJob, place
if not shared.VapeIndependent then
	universalJob = preparePack('universal')
	if PLACE_ALIAS[game.PlaceId] or game.GameId ~= 0 then
		place = resolvePlace()
		placeJob = preparePack(tostring(place))
	end
end
if shared.AetherProfiler and type(shared.AetherProfiler.Destroy) == 'function' then
	pcall(shared.AetherProfiler.Destroy)
end
shared.AetherProfiler = nil
pcall(function()
	local chunk = loadstring(downloadFile('aetherv2/libraries/profiler.lua'), 'profiler')
	shared.AetherProfiler = chunk and chunk() or nil
end)
pcall(function()
	local chunk = loadstring(downloadFile('aetherv2/libraries/telemetry.lua'), 'telemetry')
	if chunk then chunk() end
end)
if shared.AetherTelemetry then
	pcall(shared.AetherTelemetry.SetPack, place or resolvePlace())
end
if trail and trail.Crashed and not trail.Reported then
	trail.Reported = true
	report('startup', 'unfinished', 'the last launch stopped at: '..tostring(trail.Crashed))
	toast('AetherV2', 'The last launch did not finish (stopped at '..tostring(trail.Crashed)..'). This launch records each step so the cause can be found.', 12)
end
mark('gui compile')
local guiPath = 'aetherv2/guis/'..gui..'.lua'
local guiChunk, guiErr = loadstring(downloadFile(guiPath), 'gui')
if not guiChunk then
	local fresh = fetchRemote('guis/'..gui..'.lua')
	if fresh then
		guiChunk, guiErr = loadstring(fresh, 'gui')
		if guiChunk then
			pcall(writefile, guiPath, fresh)
		end
	end
	if not guiChunk then
		pcall(delfile, 'aetherv2/profiles/contents.index.json')
		report('gui', 'compile', guiErr)
		error('[AetherV2] The '..tostring(gui)..' frontend failed to compile: '..tostring(guiErr))
	end
end
mark('waiting for game')
waitForGame()
if tostring(resolvePlace()) == '6872274481' then
	pcall(armMatchHold)
end
if superseded() then return end
if type(shared.AetherV2Loading) == 'table' then shared.AetherV2Loading.At = os.clock() end
if shared.vape then
	local ok, err = pcall(shared.vape.Uninject, shared.vape)
	if not ok then
		warn('[AetherV2] the old instance did not uninject cleanly: '..tostring(err))
	end
	shared.vape = nil
end
pcall(function()
	for _, child in game:GetService('Players').LocalPlayer.PlayerGui:GetChildren() do
		if child:GetAttribute('AetherV2') then
			child:Destroy()
		end
	end
end)
pcall(function()
	local chunk = loadstring(downloadFile('aetherv2/libraries/panelagent.lua'), 'panelagent')
	if chunk then chunk() end
end)
mark('gui')
vape = guiChunk(license)
if type(vape) ~= 'table' then
	error('[AetherV2] The '..tostring(gui)..' frontend did not return a controller')
end
if type(vape.Clean) ~= 'function' or type(vape.Remove) ~= 'function' then
	local fallbackConnections = {}
	if type(vape.Clean) ~= 'function' then
		vape.Clean = function(_, ...)
			for index = 1, select('#', ...) do
				local item = select(index, ...)
				if item ~= nil then
					table.insert(fallbackConnections, item)
				end
			end
		end
		vape.CleanFallback = function()
			for _, item in fallbackConnections do
				pcall(function()
					if typeof(item) == 'Instance' then
						item:Destroy()
					elseif type(item) == 'table' and type(item.Disconnect) == 'function' then
						item:Disconnect()
					elseif type(item) == 'thread' then
						task.cancel(item)
					elseif type(item) == 'function' then
						item()
					end
				end)
			end
			table.clear(fallbackConnections)
		end
	end
	if type(vape.Remove) ~= 'function' then
		vape.Remove = function(self, name)
			local module = type(self) == 'table' and self.Modules and self.Modules[name]
			if not module then return end
			if type(module.Toggle) == 'function' and module.Enabled then
				pcall(module.Toggle, module, false)
			end
			if typeof(module.Object) == 'Instance' then
				pcall(function() module.Object:Destroy() end)
			end
		end
	end
end
if superseded() then
	pcall(function()
		vape.gui:Destroy()
	end)
	return
end
shared.vape = vape
_G.vape = vape

if not shared.VapeIndependent then
	universalJob = universalJob or preparePack('universal')
	if not placeJob then
		place = resolvePlace()
		placeJob = preparePack(tostring(place))
	end
	mark('pack universal')
	if not runPack(universalJob) then
		warn('[AetherV2] universal modules are unavailable')
		report('pack', 'universal', universalJob.Error or 'universal modules are unavailable')
	end
	vape.Place = place
	if shared.AetherTelemetry then pcall(shared.AetherTelemetry.SetPack, place) end
	if superseded() then return end
	mark('pack '..tostring(place))
	local placeRan, placeError = runPack(placeJob)
	if not placeRan then
		local reason = tostring(placeError or placeJob.Error or 'unknown error')
		if placeJob.Error == 'no files.txt' then
			warn('[AetherV2] No game module for '..tostring(game.PlaceId)..' -> '..tostring(place))
			toast('AetherV2', 'No game pack for '..tostring(game.PlaceId)..'. Universal only.', 8)
		else
			warn('[AetherV2] game pack '..tostring(place)..' (place '..tostring(game.PlaceId)..') failed: '..reason)
			report('pack', tostring(place), reason)
			toast('AetherV2', 'The game pack for '..tostring(place)..' failed to start: '..(reason:match('^[^\n]*') or reason):sub(1, 140)..'. Universal only.', 15)
		end
	end
	if superseded() then return end
	mark('custom modules')
	pcall(function()
		local folder = 'aetherv2/custommodules'
		if not isfolder(folder) then
			pcall(makefolder, folder)
			pcall(writefile, folder..'/example.lua', [==[gamesLoaded = 0
-- put the place ids this loads in on the line above, like gamesLoaded = 6872274481, 71480482338212
-- 0 means it never loads so this file stays just an example

run(function()
	local Example
	local Amount

	Example = vape.Categories.Utility:CreateModule({
		Name = 'Example',
		Function = function(callback)
			if callback then
				-- runs when you turn it on
				vape:CreateNotification('Example', 'on with amount '..Amount.Value, 3)
				Example:Clean(game:GetService('RunService').Heartbeat:Connect(function()
					-- runs every frame while on, keep it light
				end))
			end
			-- connections passed to Clean get removed when you turn it off
		end,
		Tooltip = 'An example custom module'
	})
	Amount = Example:CreateSlider({
		Name = 'Amount',
		Min = 1,
		Max = 10,
		Default = 5
	})
end)
]==])
			return
		end
		local placeIds = {[tostring(game.PlaceId)] = true, [tostring(game.GameId)] = true, [tostring(place)] = true}
		local exports = shared.AetherPackExports or {}
		local packNames, universalNames = exports[tostring(place)] or {}, exports.universal or {}
		local globals = getfenv()
		local files = {}
		for _, path in listfiles(folder) do
			path = tostring(path):gsub('\\', '/')
			local lower = path:lower()
			if lower:sub(-4) == '.lua' or lower:sub(-5) == '.luau' or lower:sub(-4) == '.txt' then table.insert(files, path) end
		end
		table.sort(files)
		local failed = {}
		local function fail(name, err)
			warn('[AetherV2] custom module '..tostring(name)..' failed: '..tostring(err))
			if not failed[name] then
				failed[name] = true
				toast('AetherV2', 'Custom module '..tostring(name)..' failed to load. See the console.', 8)
			end
		end
		for _, path in files do
			local name = path:match('([^/]+)$') or path
			local okRead, source = pcall(readfile, path)
			source = okRead and tostring(source) or ''
			local header
			for line in (source..'\n'):gmatch('([^\n]*)\n') do
				if line:match('%S') and not line:match('^%s*%-%-') then
					header = line:match('^%s*gamesLoaded%s*=%s*(.-)%s*$')
					break
				end
			end
			if not header then
				fail(name, 'the first line must be gamesLoaded = <place id>, <place id>')
			else
				local wanted = false
				for id in header:gmatch('%d+') do
					if placeIds[id] then wanted = true end
				end
				if wanted then
					local chunk, compileErr = rawLoadstring(source, 'custommodules/'..name)
					if not chunk then
						fail(name, compileErr)
					elseif not setfenv then
						fail(name, 'this executor has no setfenv')
					else
						local base = {
							vape = vape,
							entitylib = vape.Libraries.entity,
							run = function(func)
								local ok, err = xpcall(func, debug and debug.traceback or tostring)
								if not ok then fail(name, err) end
								if vape.YieldBuild then vape.YieldBuild() end
								return ok
							end
						}
						do
							pcall(setfenv, chunk, setmetatable({}, {__index = function(_, key)
								local value = base[key]
								if value == nil then value = packNames[key] end
								if value == nil then value = universalNames[key] end
								if value == nil then value = globals[key] end
								return value
							end}))
						end
						local done = false
						task.spawn(function()
							local ok, err = pcall(chunk)
							if not ok then fail(name, err) end
							done = true
						end)
						local started = os.clock()
						while not done and os.clock() - started < 3 do task.wait() end
					end
				end
			end
		end
	end)
	if superseded() then return end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
