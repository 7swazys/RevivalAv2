local band, bor, lshift, rshift = bit32.band, bit32.bor, bit32.lshift, bit32.rshift

local codec = {Prefix = 'AV2:', MaxSize = 4 * 1024 * 1024}

local LEN_BASE = {3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258}
local LEN_EXTRA = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0}
local DIST_BASE = {1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577}
local DIST_EXTRA = {0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13}
local CL_ORDER = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15}
local ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local lenCode, lenOffset = {}, {}
for code = 1, 29 do
	local top = code == 29 and 258 or LEN_BASE[code + 1] - 1
	if code == 28 then top = 257 end
	for length = LEN_BASE[code], top do
		lenCode[length] = code
		lenOffset[length] = length - LEN_BASE[code]
	end
end

local function distCode(dist)
	for code = 30, 1, -1 do
		if dist >= DIST_BASE[code] then return code end
	end
	return 1
end

local resumeAt = 0
local function pause()
	if codec.Yield and os.clock() > resumeAt then
		task.wait()
		resumeAt = os.clock() + 0.012
	end
end

local b64enc, b64dec = {}, {}
for i = 0, 63 do
	b64enc[i] = ALPHABET:sub(i + 1, i + 1)
	b64dec[ALPHABET:byte(i + 1)] = i
end

local function toBytes(text)
	local bytes, n = table.create(#text), #text
	for i = 1, n, 4096 do
		local chunk = {string.byte(text, i, math.min(i + 4095, n))}
		for k = 1, #chunk do bytes[i + k - 1] = chunk[k] end
	end
	return bytes, n
end

local function fromBytes(bytes, n)
	local parts = {}
	for i = 1, n, 4096 do
		parts[#parts + 1] = string.char(table.unpack(bytes, i, math.min(i + 4095, n)))
	end
	return table.concat(parts)
end

local function adler32(bytes, n)
	local a, b = 1, 0
	for i = 1, n do
		a = (a + bytes[i]) % 65521
		b = (b + a) % 65521
	end
	return b * 65536 + a
end

local function huffLengths(source, n, limit)
	local freq = table.clone(source)
	local lens = table.create(n, 0)
	while true do
		local leaves = {}
		for i = 1, n do
			if freq[i] > 0 then leaves[#leaves + 1] = i end
		end
		if #leaves == 0 then return lens end
		if #leaves == 1 then
			lens[leaves[1]] = 1
			return lens
		end
		table.sort(leaves, function(a, b)
			if freq[a] == freq[b] then return a < b end
			return freq[a] < freq[b]
		end)
		local count = #leaves
		local weight, parent = table.create(count * 2), table.create(count * 2)
		for k = 1, count do weight[k] = freq[leaves[k]] end
		local li, qi, nextNode = 1, count + 1, count + 1
		local function take()
			if li <= count and (qi >= nextNode or weight[li] <= weight[qi]) then
				li += 1
				return li - 1
			end
			qi += 1
			return qi - 1
		end
		for _ = 1, count - 1 do
			local a, b = take(), take()
			weight[nextNode] = weight[a] + weight[b]
			parent[a], parent[b] = nextNode, nextNode
			nextNode += 1
		end
		local depth = {}
		depth[nextNode - 1] = 0
		for node = nextNode - 2, 1, -1 do
			depth[node] = depth[parent[node]] + 1
		end
		local deepest = 0
		for k = 1, count do
			lens[leaves[k]] = depth[k]
			if depth[k] > deepest then deepest = depth[k] end
		end
		if deepest <= limit then return lens end
		for i = 1, n do
			lens[i] = 0
			if freq[i] > 0 then freq[i] = math.floor(freq[i] / 2) + 1 end
		end
	end
end

local function reverseBits(code, length)
	local out = 0
	for _ = 1, length do
		out = out * 2 + band(code, 1)
		code = rshift(code, 1)
	end
	return out
end

local function canonical(lens, n)
	local blCount = {}
	for l = 0, 15 do blCount[l] = 0 end
	for i = 1, n do
		if lens[i] > 0 then blCount[lens[i]] += 1 end
	end
	local nextCode, code = {}, 0
	for bits = 1, 15 do
		code = (code + blCount[bits - 1]) * 2
		nextCode[bits] = code
	end
	local codes = table.create(n, 0)
	for i = 1, n do
		local l = lens[i]
		if l > 0 then
			codes[i] = reverseBits(nextCode[l], l)
			nextCode[l] += 1
		end
	end
	return codes
end

local function deflate(bytes, n)
	local out, outn, acc, nbits = {}, 0, 0, 0
	local function put(value, count)
		acc = bor(acc, lshift(value, nbits))
		nbits += count
		while nbits >= 8 do
			outn += 1
			out[outn] = band(acc, 255)
			acc = rshift(acc, 8)
			nbits -= 8
		end
	end

	local tokSym, tokLen, tokDist, tokens = {}, {}, {}, 0
	local litFreq, distFreq = table.create(286, 0), table.create(30, 0)
	local head, prev = {}, table.create(n, 0)
	local function insert(p)
		if p + 2 <= n then
			local key = bytes[p] * 65536 + bytes[p + 1] * 256 + bytes[p + 2]
			prev[p] = head[key] or 0
			head[key] = p
		end
	end

	local i = 1
	resumeAt = os.clock() + 0.012
	while i <= n do
		if band(tokens, 1023) == 0 then pause() end
		local bestLen, bestDist = 0, 0
		if i + 2 <= n then
			local cand = head[bytes[i] * 65536 + bytes[i + 1] * 256 + bytes[i + 2]]
			local maxl = math.min(258, n - i + 1)
			local chain = 0
			while cand and cand > 0 and i - cand <= 32768 and chain < 96 do
				if bytes[cand + bestLen] == bytes[i + bestLen] then
					local l = 0
					while l < maxl and bytes[cand + l] == bytes[i + l] do l += 1 end
					if l > bestLen then
						bestLen, bestDist = l, i - cand
						if l >= maxl then break end
					end
				end
				cand = prev[cand]
				chain += 1
			end
		end
		tokens += 1
		if bestLen >= 3 then
			local code = lenCode[bestLen]
			tokSym[tokens] = 256 + code
			tokLen[tokens] = bestLen
			tokDist[tokens] = bestDist
			litFreq[257 + code] += 1
			local dcode = distCode(bestDist)
			distFreq[dcode] += 1
			for p = i, i + bestLen - 1 do insert(p) end
			i += bestLen
		else
			tokSym[tokens] = bytes[i]
			litFreq[bytes[i] + 1] += 1
			insert(i)
			i += 1
		end
	end
	litFreq[257] += 1

	local hasDist = false
	for d = 1, 30 do
		if distFreq[d] > 0 then hasDist = true break end
	end
	if not hasDist then distFreq[1] = 1 end

	local litLens = huffLengths(litFreq, 286, 15)
	local distLens = huffLengths(distFreq, 30, 15)
	local litCodes = canonical(litLens, 286)
	local distCodes = canonical(distLens, 30)

	local numLit, numDist = 286, 30
	while numLit > 257 and litLens[numLit] == 0 do numLit -= 1 end
	while numDist > 1 and distLens[numDist] == 0 do numDist -= 1 end

	local seq, total = {}, 0
	for k = 1, numLit do total += 1 seq[total] = litLens[k] end
	for k = 1, numDist do total += 1 seq[total] = distLens[k] end

	local rleSym, rleExtra, rleCount = {}, {}, 0
	local clFreq = table.create(19, 0)
	local k = 1
	while k <= total do
		local v, run = seq[k], 1
		while k + run <= total and seq[k + run] == v and run < 138 do run += 1 end
		rleCount += 1
		if v == 0 and run >= 11 then
			rleSym[rleCount], rleExtra[rleCount] = 18, run - 11
			k += run
		elseif v == 0 and run >= 3 then
			local r = math.min(run, 10)
			rleSym[rleCount], rleExtra[rleCount] = 17, r - 3
			k += r
		elseif v ~= 0 and run >= 4 then
			rleSym[rleCount], rleExtra[rleCount] = v, 0
			local r = math.min(run - 1, 6)
			rleCount += 1
			rleSym[rleCount], rleExtra[rleCount] = 16, r - 3
			k += 1 + r
		else
			rleSym[rleCount], rleExtra[rleCount] = v, 0
			k += 1
		end
	end
	for r = 1, rleCount do clFreq[rleSym[r] + 1] += 1 end

	local clUsed = 0
	for s = 1, 19 do
		if clFreq[s] > 0 then clUsed += 1 end
	end
	if clUsed == 1 then
		clFreq[clFreq[1] > 0 and 2 or 1] += 1
	end
	local clLens = huffLengths(clFreq, 19, 7)
	local clCodes = canonical(clLens, 19)
	local numCl = 19
	while numCl > 4 and clLens[CL_ORDER[numCl] + 1] == 0 do numCl -= 1 end

	put(1, 1)
	put(2, 2)
	put(numLit - 257, 5)
	put(numDist - 1, 5)
	put(numCl - 4, 4)
	for c = 1, numCl do put(clLens[CL_ORDER[c] + 1], 3) end
	for r = 1, rleCount do
		local s = rleSym[r]
		put(clCodes[s + 1], clLens[s + 1])
		if s == 16 then put(rleExtra[r], 2)
		elseif s == 17 then put(rleExtra[r], 3)
		elseif s == 18 then put(rleExtra[r], 7) end
	end

	for t = 1, tokens do
		local s = tokSym[t]
		if s < 256 then
			put(litCodes[s + 1], litLens[s + 1])
		else
			local code = s - 256
			put(litCodes[s + 1], litLens[s + 1])
			if LEN_EXTRA[code] > 0 then put(lenOffset[tokLen[t]], LEN_EXTRA[code]) end
			local dist = tokDist[t]
			local dcode = distCode(dist)
			put(distCodes[dcode], distLens[dcode])
			if DIST_EXTRA[dcode] > 0 then put(dist - DIST_BASE[dcode], DIST_EXTRA[dcode]) end
		end
	end
	put(litCodes[257], litLens[257])
	if nbits > 0 then
		outn += 1
		out[outn] = band(acc, 255)
	end
	return out, outn
end

local function construct(lengths, n)
	local count = {}
	for l = 0, 15 do count[l] = 0 end
	for s = 1, n do count[lengths[s]] += 1 end
	local offs = {[1] = 0}
	for l = 1, 14 do offs[l + 1] = offs[l] + count[l] end
	local symbol = {}
	for s = 1, n do
		local l = lengths[s]
		if l ~= 0 then
			symbol[offs[l] + 1] = s - 1
			offs[l] += 1
		end
	end
	return {count = count, symbol = symbol}
end

local fixedLit, fixedDist
local function fixedTables()
	if not fixedLit then
		local lens = {}
		for s = 0, 287 do
			lens[s + 1] = s < 144 and 8 or s < 256 and 9 or s < 280 and 7 or 8
		end
		fixedLit = construct(lens, 288)
		local d = {}
		for s = 1, 30 do d[s] = 5 end
		fixedDist = construct(d, 30)
	end
	return fixedLit, fixedDist
end

local function inflate(bytes, n, start)
	local pos, bitbuf, bitcnt = start, 0, 0
	local out, outn = {}, 0
	resumeAt = os.clock() + 0.012

	local function bits(count)
		while bitcnt < count do
			local byte = bytes[pos]
			if not byte then error('cut', 0) end
			bitbuf = bor(bitbuf, lshift(byte, bitcnt))
			pos += 1
			bitcnt += 8
		end
		local v = band(bitbuf, lshift(1, count) - 1)
		bitbuf = rshift(bitbuf, count)
		bitcnt -= count
		return v
	end

	local function decode(h)
		local code, first, index = 0, 0, 0
		local count, symbol = h.count, h.symbol
		for l = 1, 15 do
			if bitcnt == 0 then
				local byte = bytes[pos]
				if not byte then error('cut', 0) end
				bitbuf = byte
				pos += 1
				bitcnt = 8
			end
			code = bor(code, band(bitbuf, 1))
			bitbuf = rshift(bitbuf, 1)
			bitcnt -= 1
			local c = count[l]
			if code - c < first then
				return symbol[index + (code - first) + 1]
			end
			index += c
			first = (first + c) * 2
			code *= 2
		end
		error('bad', 0)
	end

	repeat
		local final = bits(1)
		local btype = bits(2)
		if btype == 0 then
			bitbuf, bitcnt = 0, 0
			if pos + 3 > n then error('cut', 0) end
			local len = bytes[pos] + bytes[pos + 1] * 256
			pos += 4
			if pos + len - 1 > n then error('cut', 0) end
			for k = 0, len - 1 do
				outn += 1
				out[outn] = bytes[pos + k]
			end
			pos += len
		elseif btype == 1 or btype == 2 then
			local lit, dist
			if btype == 1 then
				lit, dist = fixedTables()
			else
				local nlen, ndist, ncode = bits(5) + 257, bits(5) + 1, bits(4) + 4
				if nlen > 286 or ndist > 30 then error('bad', 0) end
				local clLens = table.create(19, 0)
				for c = 1, ncode do clLens[CL_ORDER[c] + 1] = bits(3) end
				local clTable = construct(clLens, 19)
				local lengths, idx = {}, 0
				while idx < nlen + ndist do
					local sym = decode(clTable)
					if sym < 16 then
						idx += 1
						lengths[idx] = sym
					else
						local value, rep = 0, 0
						if sym == 16 then
							if idx == 0 then error('bad', 0) end
							value, rep = lengths[idx], 3 + bits(2)
						elseif sym == 17 then
							rep = 3 + bits(3)
						else
							rep = 11 + bits(7)
						end
						if idx + rep > nlen + ndist then error('bad', 0) end
						for _ = 1, rep do
							idx += 1
							lengths[idx] = value
						end
					end
				end
				local litLens, distLens = {}, {}
				for s = 1, nlen do litLens[s] = lengths[s] end
				for s = 1, ndist do distLens[s] = lengths[nlen + s] end
				lit, dist = construct(litLens, nlen), construct(distLens, ndist)
			end
			local ticks = 0
			while true do
				ticks += 1
				if band(ticks, 2047) == 0 then pause() end
				local sym = decode(lit)
				if sym < 256 then
					outn += 1
					out[outn] = sym
				elseif sym == 256 then
					break
				else
					local code = sym - 256
					if code > 29 then error('bad', 0) end
					local length = LEN_BASE[code] + bits(LEN_EXTRA[code])
					local dcode = decode(dist) + 1
					if dcode > 30 then error('bad', 0) end
					local back = DIST_BASE[dcode] + bits(DIST_EXTRA[dcode])
					if back > outn then error('bad', 0) end
					local from = outn - back
					for k = 1, length do out[outn + k] = out[from + k] end
					outn += length
				end
				if outn > codec.MaxSize then error('big', 0) end
			end
		else
			error('bad', 0)
		end
	until final == 1
	return out, outn, pos
end

function codec.InflateRaw(text)
	local bytes, n = toBytes(text)
	local out, outn = inflate(bytes, n, 1)
	return fromBytes(out, outn)
end

function codec.Zlib(text)
	local bytes, n = toBytes(text)
	local body, bodyn = deflate(bytes, n)
	local adler = adler32(bytes, n)
	local stream = table.create(bodyn + 6)
	stream[1], stream[2] = 0x78, 0x9C
	for k = 1, bodyn do stream[k + 2] = body[k] end
	stream[bodyn + 3] = band(rshift(adler, 24), 255)
	stream[bodyn + 4] = band(rshift(adler, 16), 255)
	stream[bodyn + 5] = band(rshift(adler, 8), 255)
	stream[bodyn + 6] = band(adler, 255)
	return fromBytes(stream, bodyn + 6)
end

function codec.Pack(text)
	local bytes, n = toBytes(text)
	local body, bodyn = deflate(bytes, n)
	local adler = adler32(bytes, n)
	local stream = table.create(bodyn + 6)
	stream[1], stream[2] = 0x78, 0x9C
	for k = 1, bodyn do stream[k + 2] = body[k] end
	stream[bodyn + 3] = band(rshift(adler, 24), 255)
	stream[bodyn + 4] = band(rshift(adler, 16), 255)
	stream[bodyn + 5] = band(rshift(adler, 8), 255)
	stream[bodyn + 6] = band(adler, 255)
	local total = bodyn + 6
	local parts, count = table.create(math.ceil(total / 3) * 4), 0
	for k = 1, total, 3 do
		local a, b, c = stream[k], stream[k + 1], stream[k + 2]
		local v = a * 65536 + (b or 0) * 256 + (c or 0)
		parts[count + 1] = b64enc[rshift(v, 18)]
		parts[count + 2] = b64enc[band(rshift(v, 12), 63)]
		parts[count + 3] = b ~= nil and b64enc[band(rshift(v, 6), 63)] or '='
		parts[count + 4] = c ~= nil and b64enc[band(v, 63)] or '='
		count += 4
	end
	return codec.Prefix..table.concat(parts)
end

function codec.IsPacked(text)
	return type(text) == 'string' and text:gsub('^%s+', ''):sub(1, #codec.Prefix):upper() == codec.Prefix
end

function codec.Unpack(text)
	if type(text) ~= 'string' then return nil, 'empty' end
	text = text:gsub('%s+', '')
	if text == '' then return nil, 'empty' end
	if text:sub(1, #codec.Prefix):upper() ~= codec.Prefix then return nil, 'prefix' end
	text = text:sub(#codec.Prefix + 1):gsub('=+$', '')
	local bytes, n, acc, nbits = {}, 0, 0, 0
	for k = 1, #text do
		local v = b64dec[text:byte(k)]
		if not v then return nil, 'damaged' end
		acc = bor(lshift(band(acc, 0xFFFF), 6), v)
		nbits += 6
		if nbits >= 8 then
			nbits -= 8
			n += 1
			bytes[n] = band(rshift(acc, nbits), 255)
		end
	end
	if n < 6 or bytes[1] ~= 0x78 or (bytes[1] * 256 + bytes[2]) % 31 ~= 0 then return nil, 'damaged' end
	local ok, out, outn, pos = pcall(inflate, bytes, n, 3)
	if not ok then
		return nil, out == 'cut' and 'cut' or out == 'big' and 'big' or 'damaged'
	end
	if pos + 3 > n then return nil, 'cut' end
	local want = ((bytes[pos] * 256 + bytes[pos + 1]) * 256 + bytes[pos + 2]) * 256 + bytes[pos + 3]
	if adler32(out, outn) ~= want then return nil, 'damaged' end
	return fromBytes(out, outn)
end

return codec
