--[[
	Util
	----
	Small pure helpers shared by server and client (formatting, tables).
]]

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 1500000 -> "1.5M"
function Util.FormatNumber(n)
	n = tonumber(n) or 0
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = tostring(math.floor(n))
		return negative and ("-" .. s) or s
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local formatted
	if n >= 100 then
		formatted = string.format("%d", math.floor(n))
	elseif n >= 10 then
		formatted = string.format("%.1f", math.floor(n * 10) / 10)
	else
		formatted = string.format("%.2f", math.floor(n * 100) / 100)
	end
	if formatted:find("%.") then
		formatted = (formatted:gsub("0+$", ""))
		formatted = (formatted:gsub("%.$", ""))
	end
	return (negative and "-" or "") .. formatted .. SUFFIXES[index]
end

function Util.FormatCash(n)
	return "$" .. Util.FormatNumber(n)
end

-- 3725 -> "1h 2m", 95 -> "1m 35s"
function Util.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	end
	return string.format("%ds", s)
end

function Util.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[Util.DeepCopy(k)] = Util.DeepCopy(v)
	end
	return copy
end

-- Fills missing keys in `target` from `template` (recursively). Used to
-- migrate old saves when new fields are added to the data template.
function Util.Reconcile(target, template)
	for key, value in pairs(template) do
		if target[key] == nil then
			target[key] = Util.DeepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			Util.Reconcile(target[key], value)
		end
	end
	return target
end

function Util.CountKeys(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- Day / week numbers in UTC, used for daily/weekly resets.
function Util.GetDayNumber(timestamp)
	return math.floor((timestamp or os.time()) / 86400)
end

function Util.GetWeekNumber(timestamp)
	-- Offset so weeks roll over on Monday 00:00 UTC (epoch was a Thursday).
	return math.floor(((timestamp or os.time()) / 86400 + 3) / 7)
end

return Util
