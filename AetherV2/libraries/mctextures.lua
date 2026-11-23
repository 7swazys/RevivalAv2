local band, bor, bxor, lshift, rshift = bit32.band, bit32.bor, bit32.bxor, bit32.lshift, bit32.rshift
local httpService = game:GetService('HttpService')

local mc = {Root = 'aetherv2/assets/minecraft/vanilla/', Build = '4'}
local MANIFEST = 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json'
local SIGNATURE = '\137PNG\r\n\26\n'

local resumeAt = 0
local function pause()
	if os.clock() > resumeAt then
		task.wait()
		resumeAt = os.clock() + 0.02
	end
end

local crcTable = {}
for i = 0, 255 do
	local c = i
	for _ = 1, 8 do
		c = band(c, 1) == 1 and bxor(0xEDB88320, rshift(c, 1)) or rshift(c, 1)
	end
	crcTable[i] = c
end

local function crc32(text)
	local c = 0xFFFFFFFF
	for i = 1, #text do
		c = bxor(crcTable[band(bxor(c, text:byte(i)), 255)], rshift(c, 8))
	end
	return bxor(c, 0xFFFFFFFF)
end

local function fetch(url)
	if request then
		local ok, res = pcall(request, {Url = url, Method = 'GET'})
		if ok and type(res) == 'table' and type(res.Body) == 'string' and (res.StatusCode == 200 or res.Success == true) then
			return res.Body
		end
	end
	return game:HttpGet(url, true)
end

local function findEnd(data, from)
	local eocd
	while true do
		local found = string.find(data, 'PK\5\6', from, true)
		if not found then break end
		eocd, from = found, found + 1
	end
	if not eocd then error('the Minecraft file is not a zip', 0) end
	return string.unpack('<I2I4I4', data, eocd + 10)
end

local function zipIndex(data, entries, offset)
	if not entries then
		local _
		entries, _, offset = findEnd(data, math.max(1, #data - 65557))
	end
	local index, p = {}, offset + 1
	for _ = 1, entries do
		local sig, _, _, _, method, _, _, _, csize, _, nlen, xlen, clen, _, _, _, loff = string.unpack('<I4I2I2I2I2I2I2I4I4I4I2I2I2I2I2I4I4', data, p)
		if sig ~= 0x02014b50 then break end
		local name = data:sub(p + 46, p + 45 + nlen)
		if name:sub(1, 26) == 'assets/minecraft/textures/' then
			index[name:sub(27)] = {Method = method, Size = csize, Offset = loff}
		end
		p += 46 + nlen + xlen + clen
	end
	return index
end

local function fetchRange(url, from, to)
	local ok, res = pcall(request, {Url = url, Method = 'GET', Headers = {Range = 'bytes='..from..'-'..to}})
	if ok and type(res) == 'table' and res.StatusCode == 206 and type(res.Body) == 'string' and #res.Body == to - from + 1 then
		return res.Body
	end
end

local WANTED_PREFIXES = {'gui/sprites/hud/', 'gui/sprites/container/slot', 'gui/icons.', 'gui/widgets.', 'gui/container/inventory.',
	'font/ascii.', 'items/potion_overlay', 'item/potion_overlay', 'items/empty_armor_slot_'}

local function wantedPath(path, specs)
	if specs[path] then return true end
	for _, prefix in WANTED_PREFIXES do
		if path:sub(1, #prefix) == prefix then return true end
	end
	return false
end

local function openRanged(client, specs)
	if not request then return end
	local url, size = client.url, client.size
	local tailFrom = math.max(0, size - 65557)
	local tail = fetchRange(url, tailFrom, size - 1)
	if not tail then return end
	local entries, cdSize, cdOffset = findEnd(tail, 1)
	local central
	if cdOffset >= tailFrom and cdOffset + cdSize <= size then
		central = tail:sub(cdOffset - tailFrom + 1, cdOffset - tailFrom + cdSize)
	else
		central = fetchRange(url, cdOffset, cdOffset + cdSize - 1)
	end
	if not central or #central ~= cdSize then return end
	local index = zipIndex(central, entries, 0)
	local list = {}
	for path, entry in index do
		if wantedPath(path, specs) then
			entry.Path = path
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b) return a.Offset < b.Offset end)
	local ranges = {}
	for _, entry in list do
		local from = entry.Offset
		local to = math.min(size - 1, from + 30 + 26 + #entry.Path + 1024 + entry.Size)
		local last = ranges[#ranges]
		if last and from - last[2] < 65536 then
			last[2] = math.max(last[2], to)
		else
			table.insert(ranges, {from, to})
		end
	end
	local left, failed = #ranges, false
	for _, range in ranges do
		task.spawn(function()
			local body = fetchRange(url, range[1], range[2])
			if body then range[3] = body else failed = true end
			left -= 1
		end)
	end
	local started = os.clock()
	while left > 0 and os.clock() - started < 60 do task.wait() end
	if left > 0 or failed then return end
	local function read(p, n)
		local at = p - 1
		for _, range in ranges do
			if at >= range[1] and at + n - 1 <= range[2] then
				return range[3]:sub(at - range[1] + 1, at - range[1] + n)
			end
		end
		error('missing range', 0)
	end
	return index, read
end

local function newImage(w, h)
	return {W = w, H = h, P = table.create(w * h * 4, 0)}
end

local function decodePng(text, codec)
	if text:sub(1, 8) ~= SIGNATURE then error('not a png', 0) end
	local p, w, h, depth, ctype, compression, filterMethod, interlace = 9
	local idat, plte, trns = {}, nil, nil
	while p + 8 <= #text do
		local len = string.unpack('>I4', text, p)
		local kind = text:sub(p + 4, p + 7)
		local body = text:sub(p + 8, p + 7 + len)
		if kind == 'IHDR' then
			w, h, depth, ctype, compression, filterMethod, interlace = string.unpack('>I4I4BBBBB', body)
		elseif kind == 'PLTE' then
			plte = body
		elseif kind == 'tRNS' then
			trns = body
		elseif kind == 'IDAT' then
			table.insert(idat, body)
		elseif kind == 'IEND' then
			break
		end
		p += 12 + len
	end
	local channels = ({[0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4})[ctype]
	if not channels or compression ~= 0 or filterMethod ~= 0 or interlace ~= 0 or depth > 8 or (depth < 8 and ctype ~= 0 and ctype ~= 3) then error('unsupported png', 0) end
	local raw = codec.InflateRaw(table.concat(idat):sub(3))
	local bits = channels * depth
	local bpp = math.max(1, bits // 8)
	local stride = (w * bits + 7) // 8
	local prev, rows = table.create(stride, 0), {}
	local pos = 1
	for y = 1, h do
		local filter = raw:byte(pos)
		local cur = {raw:byte(pos + 1, pos + stride)}
		pos += stride + 1
		for i = 1, stride do
			local a = i > bpp and cur[i - bpp] or 0
			local b = prev[i]
			local c = i > bpp and prev[i - bpp] or 0
			local x = cur[i]
			if filter == 1 then
				x += a
			elseif filter == 2 then
				x += b
			elseif filter == 3 then
				x += (a + b) // 2
			elseif filter == 4 then
				local pa, pb, pc = math.abs(b - c), math.abs(a - c), math.abs(a + b - 2 * c)
				x += (pa <= pb and pa <= pc) and a or (pb <= pc and b or c)
			end
			cur[i] = x % 256
		end
		rows[y] = cur
		prev = cur
		pause()
	end
	local keyGray, keyR, keyG, keyB
	if trns and ctype == 0 and #trns >= 2 then
		keyGray = string.unpack('>I2', trns)
	elseif trns and ctype == 2 and #trns >= 6 then
		keyR, keyG, keyB = string.unpack('>I2I2I2', trns)
	end
	local img = newImage(w, h)
	local P = img.P
	for y = 1, h do
		local row = rows[y]
		for x = 0, w - 1 do
			local r, g, b, a
			if depth < 8 then
				local bit = x * depth
				local byte = row[bit // 8 + 1]
				local v = band(rshift(byte, 8 - depth - bit % 8), lshift(1, depth) - 1)
				if ctype == 3 then
					r, g, b = plte:byte(v * 3 + 1, v * 3 + 3)
					a = trns and trns:byte(v + 1) or 255
				else
					a = v == keyGray and 0 or 255
					v = v * 255 // (lshift(1, depth) - 1)
					r, g, b = v, v, v
				end
			else
				local i = x * channels + 1
				if ctype == 6 then
					r, g, b, a = row[i], row[i + 1], row[i + 2], row[i + 3]
				elseif ctype == 2 then
					r, g, b = row[i], row[i + 1], row[i + 2]
					a = (r == keyR and g == keyG and b == keyB) and 0 or 255
				elseif ctype == 4 then
					r, g, b, a = row[i], row[i], row[i], row[i + 1]
				elseif ctype == 0 then
					r, g, b, a = row[i], row[i], row[i], row[i] == keyGray and 0 or 255
				else
					local v = row[i]
					r, g, b = plte:byte(v * 3 + 1, v * 3 + 3)
					a = trns and trns:byte(v + 1) or 255
				end
			end
			local o = ((y - 1) * w + x) * 4
			P[o + 1], P[o + 2], P[o + 3], P[o + 4] = r or 0, g or 0, b or 0, a or 255
		end
	end
	return img
end

local function encodePng(img, codec)
	local w, h, P = img.W, img.H, img.P
	local rows = table.create(h)
	for y = 0, h - 1 do
		local t = table.create(w * 4 + 1)
		t[1] = 0
		local base = y * w * 4
		for i = 1, w * 4 do t[i + 1] = P[base + i] end
		rows[y + 1] = string.char(table.unpack(t))
	end
	local function chunk(kind, body)
		return string.pack('>I4', #body)..kind..body..string.pack('>I4', crc32(kind..body))
	end
	return SIGNATURE..chunk('IHDR', string.pack('>I4I4BBBBB', w, h, 8, 6, 0, 0, 0))..chunk('IDAT', codec.Zlib(table.concat(rows)))..chunk('IEND', '')
end

local function crop(img, x0, y0, w, h)
	local out = newImage(w, h)
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local s, d = ((y0 + y) * img.W + x0 + x) * 4, (y * w + x) * 4
			for k = 1, 4 do out.P[d + k] = img.P[s + k] or 0 end
		end
	end
	return out
end

local function scale(img, k)
	local w, h = img.W * k, img.H * k
	local out = newImage(w, h)
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local s, d = ((y // k) * img.W + x // k) * 4, (y * w + x) * 4
			for c = 1, 4 do out.P[d + c] = img.P[s + c] end
		end
	end
	return out
end

local function over(dst, src, ox, oy, tint)
	for y = 0, src.H - 1 do
		for x = 0, src.W - 1 do
			local dx, dy = ox + x, oy + y
			if dx >= 0 and dy >= 0 and dx < dst.W and dy < dst.H then
				local s, d = (y * src.W + x) * 4, (dy * dst.W + dx) * 4
				local a = src.P[s + 4] / 255
				if a > 0 then
					for c = 1, 3 do
						local v = src.P[s + c] * (tint and tint[c] or 255) / 255
						dst.P[d + c] = math.floor(v * a + dst.P[d + c] * (1 - a) + 0.5)
					end
					dst.P[d + 4] = math.floor(src.P[s + 4] + dst.P[d + 4] * (1 - a) + 0.5)
				end
			end
		end
	end
	return dst
end

local function emerald(img)
	local out = newImage(img.W, img.H)
	for i = 0, img.W * img.H - 1 do
		local o = i * 4
		local r, g, b, a = img.P[o + 1], img.P[o + 2], img.P[o + 3], img.P[o + 4]
		local h, s, v = Color3.fromRGB(r, g, b):ToHSV()
		if a > 0 and h >= 0.38 and h <= 0.62 and s > 0.15 then
			local c = Color3.fromHSV(0.37, math.min(1, s * 1.1), v)
			r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
		end
		out.P[o + 1], out.P[o + 2], out.P[o + 3], out.P[o + 4] = r, g, b, a
	end
	return out
end

local function shade(img, f)
	local out = newImage(img.W, img.H)
	for i = 1, #img.P, 4 do
		out.P[i], out.P[i + 1], out.P[i + 2], out.P[i + 3] = math.floor(img.P[i] * f), math.floor(img.P[i + 1] * f), math.floor(img.P[i + 2] * f), img.P[i + 3]
	end
	return out
end

local function iso(top, side, size)
	local left, right = shade(side, 0.8), shade(side, 0.62)
	local hw = size * 29 / 64
	local q = hw / 2
	local s = hw * 1.155
	local ox, oy = size / 2, (size - (2 * q + s)) / 2
	local T, L, R, C = {ox, oy}, {ox - hw, oy + q}, {ox + hw, oy + q}, {ox, oy + 2 * q}
	local faces = {
		{T, {R[1] - T[1], R[2] - T[2]}, {L[1] - T[1], L[2] - T[2]}, top},
		{L, {C[1] - L[1], C[2] - L[2]}, {0, s}, left},
		{C, {R[1] - C[1], R[2] - C[2]}, {0, s}, right},
	}
	local out = newImage(size, size)
	for _, f in faces do
		local O, A, B, tex = f[1], f[2], f[3], f[4]
		local det = A[1] * B[2] - A[2] * B[1]
		for y = 0, size - 1 do
			for x = 0, size - 1 do
				local px, py = x + 0.5 - O[1], y + 0.5 - O[2]
				local u = (px * B[2] - py * B[1]) / det
				local v = (A[1] * py - A[2] * px) / det
				if u >= 0 and u < 1 and v >= 0 and v < 1 then
					local s0 = (math.floor(v * tex.H) * tex.W + math.floor(u * tex.W)) * 4
					if tex.P[s0 + 4] > 0 then
						local d = (y * size + x) * 4
						for c = 1, 4 do out.P[d + c] = tex.P[s0 + c] end
					end
				end
			end
		end
		pause()
	end
	return out
end

local WOOL = {white = 'white', black = 'black', blue = 'blue', brown = 'brown', cyan = 'cyan', gray = 'gray', green = 'lime',
	orange = 'orange', pink = 'pink', purple = 'purple', red = 'red', yellow = 'yellow'}
local CLAY = {black = 'black', blue = 'blue', dark_brown = 'brown', dark_green = 'green', gray = 'gray', green = 'lime',
	light_brown = false, light_green = 'lime', orange = 'orange', pink = 'pink', purple = 'purple', red = 'red', tan = false,
	white = 'white', yellow = 'yellow'}

local ITEMS = {
	wood_sword = {'items/wood_sword', 'item/wooden_sword'}, stone_sword = {'items/stone_sword', 'item/stone_sword'},
	iron_sword = {'items/iron_sword', 'item/iron_sword'}, diamond_sword = {'items/diamond_sword', 'item/diamond_sword'},
	emerald_sword = {'items/diamond_sword', 'item/diamond_sword', 'emerald'},
	wood_pickaxe = {'items/wood_pickaxe', 'item/wooden_pickaxe'}, stone_pickaxe = {'items/stone_pickaxe', 'item/stone_pickaxe'},
	iron_pickaxe = {'items/iron_pickaxe', 'item/iron_pickaxe'}, diamond_pickaxe = {'items/diamond_pickaxe', 'item/diamond_pickaxe'},
	wood_axe = {'items/wood_axe', 'item/wooden_axe'}, stone_axe = {'items/stone_axe', 'item/stone_axe'},
	iron_axe = {'items/iron_axe', 'item/iron_axe'}, diamond_axe = {'items/diamond_axe', 'item/diamond_axe'},
	shears = {'items/shears', 'item/shears'}, iron = {'items/iron_ingot', 'item/iron_ingot'}, diamond = {'items/diamond', 'item/diamond'},
	emerald = {'items/emerald', 'item/emerald'}, gold = {'items/gold_ingot', 'item/gold_ingot'},
	leather_helmet = {'items/leather_helmet', 'item/leather_helmet', 'leather'}, leather_chestplate = {'items/leather_chestplate', 'item/leather_chestplate', 'leather'},
	leather_boots = {'items/leather_boots', 'item/leather_boots', 'leather'},
	iron_helmet = {'items/iron_helmet', 'item/iron_helmet'}, iron_chestplate = {'items/iron_chestplate', 'item/iron_chestplate'}, iron_boots = {'items/iron_boots', 'item/iron_boots'},
	diamond_helmet = {'items/diamond_helmet', 'item/diamond_helmet'}, diamond_chestplate = {'items/diamond_chestplate', 'item/diamond_chestplate'},
	diamond_boots = {'items/diamond_boots', 'item/diamond_boots'},
	emerald_helmet = {'items/diamond_helmet', 'item/diamond_helmet', 'emerald'}, emerald_chestplate = {'items/diamond_chestplate', 'item/diamond_chestplate', 'emerald'},
	emerald_boots = {'items/diamond_boots', 'item/diamond_boots', 'emerald'},
	wood_bow = {'items/bow_standby', 'item/bow'}, wood_crossbow = {'items/bow_standby', 'item/crossbow_standby'}, arrow = {'items/arrow', 'item/arrow'},
	telepearl = {'items/ender_pearl', 'item/ender_pearl'}, fireball = {'items/fireball', 'item/fire_charge'}, apple = {'items/apple', 'item/apple'},
	golden_apple = {'items/apple_golden', 'item/golden_apple'}, snowball = {'items/snowball', 'item/snowball'},
	speed_potion = {'items/potion_bottle_drinkable', 'item/potion', 'potion'},
}

local BLOCKS = {
	wood_plank_oak = {'blocks/planks_oak', 'block/oak_planks'}, wood_plank_birch = {'blocks/planks_birch', 'block/birch_planks'},
	wood_plank_spruce = {'blocks/planks_spruce', 'block/spruce_planks'}, wood_plank_maple = {'blocks/planks_big_oak', 'block/dark_oak_planks'},
	wood_plank_hickory = {'blocks/planks_jungle', 'block/jungle_planks'}, stone_brick = {'blocks/stonebrick', 'block/stone_bricks'},
	stone = {'blocks/stone', 'block/stone'}, obsidian = {'blocks/obsidian', 'block/obsidian'}, ceramic = {'blocks/end_stone', 'block/end_stone'},
	sandstone = {'blocks/sandstone_normal', 'block/sandstone', 'blocks/sandstone_top', 'block/sandstone_top'},
	slime_block = {'blocks/slime', 'block/slime_block'}, tnt = {'blocks/tnt_side', 'block/tnt_side', 'blocks/tnt_top', 'block/tnt_top'},
	glass = {'blocks/glass', 'block/glass', Icon = true},
}
for team, colour in WOOL do
	BLOCKS['wool_'..team] = {'blocks/wool_colored_'..colour, 'block/'..colour..'_wool'}
end
for team, colour in CLAY do
	BLOCKS['clay_'..team] = colour and {'blocks/hardened_clay_stained_'..(colour == 'gray' and 'gray' or colour), 'block/'..colour..'_terracotta'}
		or {'blocks/hardened_clay', 'block/terracotta'}
end
mc.Items, mc.Blocks = ITEMS, BLOCKS

local function folderFor(id)
	return mc.Root..id:gsub('[^%w%.%-]', '_')..'/'
end

function mc.Image(path, codec)
	if not isfile(path) then return end
	local ok, img = pcall(decodePng, readfile(path), codec)
	return ok and img or nil
end

function mc.Cached(choice)
	local id = '1.8.9'
	if choice == 'Latest' then
		id = isfile(mc.Root..'latest.txt') and readfile(mc.Root..'latest.txt') or nil
	end
	local dir = id and folderFor(id)
	if dir and isfile(dir..'ready.txt') and readfile(dir..'ready.txt') == mc.Build then return dir, id end
end

function mc.Prepare(choice, codec, status)
	resumeAt = os.clock() + 0.02
	local manifest
	local ok, body = pcall(fetch, MANIFEST)
	if ok then ok, manifest = pcall(httpService.JSONDecode, httpService, body) end
	local id = '1.8.9'
	if choice == 'Latest' then
		if not (ok and type(manifest) == 'table') then
			local dir, cached = mc.Cached(choice)
			if dir then return dir, cached end
			error('could not reach Mojang', 0)
		end
		id = manifest.latest.release
	end
	local dir = folderFor(id)
	if isfile(dir..'ready.txt') and readfile(dir..'ready.txt') == mc.Build then
		if choice == 'Latest' then writefile(mc.Root..'latest.txt', id) end
		return dir, id
	end
	if not (ok and type(manifest) == 'table') then error('could not reach Mojang', 0) end
	local entry
	for _, v in manifest.versions do
		if v.id == id then entry = v break end
	end
	if not entry then error('Minecraft '..id..' was not found', 0) end
	local version = httpService:JSONDecode(fetch(entry.url))
	local client = version.downloads.client
	local specs = {}
	for _, list in {ITEMS, BLOCKS} do
		for _, spec in list do
			for i = 1, 4 do
				if type(spec[i]) == 'string' then
					specs[spec[i]..'.png'] = true
					specs[spec[i]..'_overlay.png'] = true
				end
			end
		end
	end
	if status then status('Downloading Minecraft '..id..' textures') end
	local okRanged, index, read = pcall(openRanged, client, specs)
	if not (okRanged and index) then
		if status then status('Downloading Minecraft '..id..' ('..math.floor(client.size / 1048576 + 0.5)..' MB)') end
		local jar = fetch(client.url)
		if #jar ~= client.size then error('the download from Mojang was incomplete', 0) end
		index = zipIndex(jar)
		read = function(p, n) return jar:sub(p, p + n - 1) end
	end
	if status then status('Building textures') end
	local modern = id ~= '1.8.9'
	local cache = {}
	local function load(old, new)
		local path = (modern and new or old)..'.png'
		if cache[path] == nil then
			local entry2 = index[path]
			cache[path] = false
			if entry2 then
				local p = entry2.Offset + 1
				local okRead, raw = pcall(function()
					local nlen, xlen = string.unpack('<I2I2', read(p + 26, 4))
					return read(p + 30 + nlen + xlen, entry2.Size)
				end)
				if okRead and raw then
					local okDecode, img = pcall(function()
						return decodePng(entry2.Method == 0 and raw or codec.InflateRaw(raw), codec)
					end)
					cache[path] = okDecode and img or false
				end
			end
			pause()
		end
		return cache[path] or nil
	end
	for _, folder in {mc.Root, dir} do
		if not isfolder(folder) then makefolder(folder) end
	end
	local function save(name, img)
		if img then
			writefile(dir..name..'.png', encodePng(img, codec))
			pause()
		end
	end

	for item, spec in ITEMS do
		pcall(function()
			local img = load(spec[1], spec[2])
			if not img then return end
			if spec[3] == 'emerald' then
				img = emerald(img)
			elseif spec[3] == 'leather' then
				local base = over(newImage(img.W, img.H), img, 0, 0, {160, 101, 64})
				local overlay = load(spec[1]..'_overlay', spec[2]..'_overlay')
				img = overlay and over(base, overlay, 0, 0) or base
			elseif spec[3] == 'potion' then
				local overlay = load('items/potion_overlay', 'item/potion_overlay')
				local base = newImage(img.W, img.H)
				if overlay then over(base, overlay, 0, 0, {124, 175, 198}) end
				img = over(base, img, 0, 0)
			end
			save('icon_'..item, img)
		end)
	end
	for item, spec in BLOCKS do
		pcall(function()
			local side = load(spec[1], spec[2])
			if not side then return end
			local top = spec[3] and load(spec[3], spec[4]) or side
			save('icon_'..item, iso(top, side, 64))
			if not spec.Icon then
				save('face_'..item..'_side', scale(side, 8))
				save('face_'..item..'_top', top ~= side and scale(top, 8) or nil)
			end
		end)
	end
	pcall(function()
		local full, half, empty
		if modern then
			full, half, empty = load(nil, 'gui/sprites/hud/heart/full'), load(nil, 'gui/sprites/hud/heart/half'), load(nil, 'gui/sprites/hud/heart/container')
		else
			local icons = load('gui/icons')
			full, half, empty = crop(icons, 52, 0, 9, 9), crop(icons, 61, 0, 9, 9), crop(icons, 16, 0, 9, 9)
		end
		save('heart_empty', empty)
		save('heart_full', over(crop(empty, 0, 0, 9, 9), full, 0, 0))
		save('heart_half', over(crop(empty, 0, 0, 9, 9), half, 0, 0))
	end)
	pcall(function()
		local food, foodEmpty, xp
		if modern then
			food, foodEmpty, xp = load(nil, 'gui/sprites/hud/food_full'), load(nil, 'gui/sprites/hud/food_empty'), load(nil, 'gui/sprites/hud/experience_bar_background')
		else
			local icons = load('gui/icons')
			food, foodEmpty, xp = crop(icons, 52, 27, 9, 9), crop(icons, 16, 27, 9, 9), crop(icons, 0, 64, 182, 5)
		end
		save('food_full', over(crop(foodEmpty, 0, 0, 9, 9), food, 0, 0))
		save('xp_bar', xp)
	end)
	pcall(function()
		local bar, selection
		if modern then
			bar, selection = load(nil, 'gui/sprites/hud/hotbar'), load(nil, 'gui/sprites/hud/hotbar_selection')
		else
			local widgets = load('gui/widgets')
			bar, selection = crop(widgets, 0, 0, 182, 22), crop(widgets, 0, 22, 24, 24)
		end
		save('hotbar_bar', bar)
		save('hotbar_selection', over(newImage(24, 24), selection, 0, 0))
		local slot = over(newImage(24, 24), crop(bar, 0, 0, 22, 22), 1, 1)
		save('hotbar_slot', slot)
		save('hotbar_selected', over(over(newImage(24, 24), slot, 0, 0), selection, 0, 0))
	end)
	pcall(function()
		local slot = modern and load(nil, 'gui/sprites/container/slot')
		if not slot then slot = crop(load('gui/container/inventory', 'gui/container/inventory'), 7, 83, 18, 18) end
		save('inventory_slot', slot)
	end)

	pcall(function()
		local font = load('font/ascii', 'font/ascii')
		if not font then return end
		save('font_ascii', font)
		local widths = {}
		local cell = font.W // 16
		for c = 0, 255 do
			local cx, cy = (c % 16) * cell, (c // 16) * cell
			local right = -1
			for x = cell - 1, 0, -1 do
				for y = 0, cell - 1 do
					if font.P[((cy + y) * font.W + cx + x) * 4 + 4] > 0 then right = x break end
				end
				if right >= 0 then break end
			end
			widths[c + 1] = c == 32 and 4 or right >= 0 and math.floor((right + 2) * 8 / cell + 0.5) or 0
		end
		writefile(dir..'font_widths.txt', table.concat(widths, ','))
	end)
	pcall(function()
		local full, half, empty, hcFull, hcHalf, hcEmpty
		if modern then
			full, half, empty = load(nil, 'gui/sprites/hud/armor_full'), load(nil, 'gui/sprites/hud/armor_half'), load(nil, 'gui/sprites/hud/armor_empty')
			hcFull, hcHalf, hcEmpty = load(nil, 'gui/sprites/hud/heart/hardcore_full'), load(nil, 'gui/sprites/hud/heart/hardcore_half'), load(nil, 'gui/sprites/hud/heart/container_hardcore')
		else
			local icons = load('gui/icons')
			full, half, empty = crop(icons, 34, 9, 9, 9), crop(icons, 25, 9, 9, 9), crop(icons, 16, 9, 9, 9)
			hcFull, hcHalf, hcEmpty = crop(icons, 52, 45, 9, 9), crop(icons, 61, 45, 9, 9), crop(icons, 16, 45, 9, 9)
		end
		save('armor_full', full)
		save('armor_half', half)
		save('armor_empty', empty)
		hcEmpty = hcEmpty or load(nil, 'gui/sprites/hud/heart/container')
		if hcEmpty then
			save('heart_hc_empty', hcEmpty)
			if hcFull then save('heart_hc_full', over(crop(hcEmpty, 0, 0, 9, 9), hcFull, 0, 0)) end
			if hcHalf then save('heart_hc_half', over(crop(hcEmpty, 0, 0, 9, 9), hcHalf, 0, 0)) end
		end
	end)
	pcall(function()
		local window = load('gui/container/inventory', 'gui/container/inventory')
		if window then save('inventory_window', crop(window, 0, 0, 176, 166)) end
		for _, piece in {'helmet', 'chestplate', 'leggings', 'boots'} do
			save('slot_'..piece, load('items/empty_armor_slot_'..piece, 'gui/sprites/container/slot/'..piece))
		end
	end)

	writefile(dir..'ready.txt', mc.Build)
	if choice == 'Latest' then writefile(mc.Root..'latest.txt', id) end
	return dir, id
end

return mc
