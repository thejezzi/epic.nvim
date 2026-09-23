local util = require("epic.util")
local config = require("epic.config")
local _ = require("epic.types")

local M = {}

-- Normalized time value:
--   epoch_seconds, milliseconds, timezone_offset_seconds,
--   timezone_source ("explicit"|"local"|"utc"), original_text, detected_format
-- Ambiguous result: { ambiguous = true, original_text, candidates = {...} }

--- @return types.Date
local function make_value(epoch, ms, offset, source, text, fmt)
	return {
		epoch_seconds = epoch,
		milliseconds = ms or 0,
		timezone_offset_seconds = offset,
		timezone_source = source,
		original_text = text,
		detected_format = fmt,
	}
end

local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function is_leap(y)
	return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
end

local function valid_time(t)
	if not (t.year and t.month and t.day) then
		return false
	end
	if t.month < 1 or t.month > 12 then
		return false
	end
	local dim = days_in_month[t.month]
	if t.month == 2 and is_leap(t.year) then
		dim = 29
	end
	if t.day < 1 or t.day > dim then
		return false
	end
	if t.hour < 0 or t.hour > 23 then
		return false
	end
	if t.min < 0 or t.min > 59 then
		return false
	end
	if t.sec < 0 or t.sec > 60 then
		return false
	end
	return true
end

--- epoch from a time table interpreted in a given offset.
local function epoch_with_offset(t, offset, source)
	if source == "local" then
		return os.time(t)
	end
	-- os.time(t) treats t as local (with correct DST for date t);
	-- its UTC clock is (t - offset_at_t). We want UTC clock = (t - offset),
	-- so shift by (offset_at_t - offset).
	local ost = os.time(t)
	return ost + util.offset_at(ost) - offset
end

local function parse_iso(text)
	-- Capture the fixed prefix (date + time) and optional fractional seconds,
	-- then interpret the trailing timezone designator separately so we can
	-- accept "Z", "+HH:MM", "+HHMM" as well as the literal words "UTC"/"GMT"
	-- (e.g. "2025-05-20 12:30:00 UTC" -- which this plugin itself emits).
	local prefix = text:match("^(%d%d%d%d%-%d%d%-%d%d[Tt ]%d%d:%d%d:%d%d)")
	if not prefix then
		return nil
	end
	local y, mo, d, h, mi, s = prefix:match("^(%d+)%-(%d+)%-(%d+)[Tt ](%d+):(%d+):(%d+)$")
	local rest = text:sub(#prefix + 1)
	local frac = rest:match("^(%.%d+)")
	local tail = frac and rest:sub(#frac + 1) or rest

	local t = {
		year = tonumber(y),
		month = tonumber(mo),
		day = tonumber(d),
		hour = tonumber(h),
		min = tonumber(mi),
		sec = tonumber(s),
	}
	if not valid_time(t) then
		return nil
	end
	local ms = 0
	if frac then
		local f = frac:sub(2)
		if #f >= 3 then
			ms = tonumber(f:sub(1, 3))
		else
			ms = tonumber(f) * (10 ^ (3 - #f))
		end
	end

	local offset, source
	if tail == "" then
		offset, source = util.local_offset_seconds(), "local"
	elseif tail == "Z" or tail == "z" then
		offset, source = 0, "utc"
	elseif tail:match("^ ?[Uu][Tt][Cc]$") or tail:match("^ ?[Gg][Mm][Tt]$") then
		-- literal timezone word: treat UTC/GMT as offset 0
		offset, source = 0, "utc"
	else
		local o = util.parse_offset(tail)
		if not o then
			return nil
		end
		offset, source = o, "explicit"
	end
	return make_value(epoch_with_offset(t, offset, source), ms, offset, source, text, "iso8601")
end

local function parse_iso_date(text)
	local y, mo, d = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if not y then
		return nil
	end
	local t = {
		year = tonumber(y),
		month = tonumber(mo),
		day = tonumber(d),
		hour = 0,
		min = 0,
		sec = 0,
	}
	if not valid_time(t) then
		return nil
	end
	local offset = util.offset_at(os.time(t))
	return make_value(os.time(t), 0, offset, "local", text, "iso8601_date")
end

local function parse_unix(text)
	local s = text:match("^@?(%d+)$")
	if not s then
		return nil
	end
	local n = tonumber(s)
	if not n then
		return nil
	end
	if #s >= 13 then
		return make_value(math.floor(n / 1000), n % 1000, 0, "utc", text, "unix_milliseconds")
	end
	if #s < 9 or #s > 12 then
		return nil
	end
	return make_value(n, 0, 0, "utc", text, "unix_seconds")
end

local months = {
	Jan = 1,
	Feb = 2,
	Mar = 3,
	Apr = 4,
	May = 5,
	Jun = 6,
	Jul = 7,
	Aug = 8,
	Sep = 9,
	Oct = 10,
	Nov = 11,
	Dec = 12,
}

local function parse_rfc2822(text)
	local d, mon, y, h, mi, s, off =
		text:match("^%a*,%s*(%d%d)%s+(%a+)%s+(%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)%s+([%+%-]%d%d%d%d)$")
	if not d then
		d, mon, y, h, mi, s, off = text:match("^(%d%d)%s+(%a+)%s+(%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)%s+([%+%-]%d%d%d%d)$")
	end
	if not d then
		return nil
	end
	local mo = months[mon]
	if not mo then
		return nil
	end
	local offset = util.parse_offset(off:sub(1, 3) .. ":" .. off:sub(4, 5))
	if not offset then
		return nil
	end
	local t = {
		year = tonumber(y),
		month = mo,
		day = tonumber(d),
		hour = tonumber(h),
		min = tonumber(mi),
		sec = tonumber(s),
	}
	if not valid_time(t) then
		return nil
	end
	return make_value(epoch_with_offset(t, offset, "explicit"), 0, offset, "explicit", text, "rfc2822")
end

local function parse_http_date(text)
	local d, mon, y, h, mi, s, tz = text:match("^%a*,%s+(%d%d)%s+(%a+)%s+(%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)%s+(%a+)$")
	if not d then
		return nil
	end
	local mo = months[mon]
	if not mo then
		return nil
	end
	if tz ~= "GMT" then
		return nil
	end
	local t = {
		year = tonumber(y),
		month = mo,
		day = tonumber(d),
		hour = tonumber(h),
		min = tonumber(mi),
		sec = tonumber(s),
	}
	if not valid_time(t) then
		return nil
	end
	return make_value(epoch_with_offset(t, 0, "utc"), 0, 0, "utc", text, "http_date")
end

local function parse_de(text)
	local d, mo, y, h, mi, s
	d, mo, y, h, mi, s = text:match("^(%d%d)%.(%d%d)%.(%d%d%d%d)[ Tt](%d%d):(%d%d):(%d%d)$")
	if not d then
		d, mo, y, h, mi = text:match("^(%d%d)%.(%d%d)%.(%d%d%d%d)[ Tt](%d%d):(%d%d)$")
	end
	if not d then
		d, mo, y = text:match("^(%d%d)%.(%d%d)%.(%d%d%d%d)$")
	end
	if not d then
		return nil
	end
	local t = {
		year = tonumber(y),
		month = tonumber(mo),
		day = tonumber(d),
		hour = tonumber(h or 0),
		min = tonumber(mi or 0),
		sec = tonumber(s or 0),
	}
	if not valid_time(t) then
		return nil
	end
	local offset = util.offset_at(os.time(t))
	return make_value(os.time(t), 0, offset, "local", text, "de")
end

local function parse_slash_date(text)
	local a, b, y, h, mi, s
	a, b, y, h, mi, s = text:match("^(%d%d)/(%d%d)/(%d%d%d%d)[ Tt](%d%d):(%d%d):(%d%d)$")
	if not a then
		a, b, y, h, mi = text:match("^(%d%d)/(%d%d)/(%d%d%d%d)[ Tt](%d%d):(%d%d)$")
	end
	if not a then
		a, b, y = text:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
	end
	if not a then
		return nil
	end
	local a_n, b_n = tonumber(a), tonumber(b)
	local year, hour, min_, sec = tonumber(y), tonumber(h or 0), tonumber(mi or 0), tonumber(s or 0)

	local function make(d, m, fmt)
		local t = { year = year, month = m, day = d, hour = hour, min = min_, sec = sec }
		if not valid_time(t) then
			return nil
		end
		local epoch = os.time(t)
		return make_value(epoch, 0, util.offset_at(epoch), "local", text, fmt)
	end

	local dmy = make(a_n, b_n, "slash_dmy")
	local mdy = make(b_n, a_n, "slash_mdy")
	local order = config.get().ambiguous_date_order

	if dmy and mdy then
		if dmy.epoch_seconds == mdy.epoch_seconds then
			return dmy
		end
		if order == "dmy" then
			return dmy
		elseif order == "mdy" then
			return mdy
		else
			return {
				ambiguous = true,
				original_text = text,
				candidates = { dmy, mdy },
			}
		end
	elseif dmy then
		return dmy
	elseif mdy then
		return mdy
	end
	return nil
end

function M.now_local()
	local t = os.date("*t")
	local epoch = os.time(t)
	return make_value(epoch, 0, util.offset_at(epoch), "local", "", "local")
end

M.parsers = {
	parse_iso,
	parse_iso_date,
	parse_unix,
	parse_rfc2822,
	parse_http_date,
	parse_de,
	parse_slash_date,
}

--- Parse a trimmed text. Returns a value, an ambiguous table, or nil.
--- @return types.Date|nil
function M.parse(text)
	text = util.trim(text)
	for _, p in ipairs(M.parsers) do
		local ok, res = pcall(p, text)
		if ok and res then
			return res
		end
	end
	return nil
end

return M
