local util = require("epic.util")
local config = require("epic.config")

local M = {}

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local DAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

local function utc_table(epoch)
	return os.date("!*t", epoch)
end

local function local_table(epoch)
	return os.date("*t", epoch)
end

local function offset_table(epoch, offset)
	-- wall clock at the given offset = utc_clock(epoch) + offset
	return os.date("!*t", epoch + offset)
end

local function effective_offset(v)
	if v.timezone_source == "local" then
		return util.offset_at(v.epoch_seconds)
	end
	return v.timezone_offset_seconds
end

function M.format_local(v)
	local t = local_table(v.epoch_seconds)
	return util.format_datetime(t, v.milliseconds > 0, v.milliseconds)
end

function M.format_utc(v)
	local t = utc_table(v.epoch_seconds)
	return util.format_datetime(t, v.milliseconds > 0, v.milliseconds) .. " UTC"
end

function M.format_iso8601(v)
	local offset = effective_offset(v)
	local t = offset_table(v.epoch_seconds, offset)
	local s = string.format("%04d-%02d-%02dT%02d:%02d:%02d", t.year, t.month, t.day, t.hour, t.min, t.sec)
	if v.milliseconds > 0 then
		s = s .. "." .. util.pad(v.milliseconds, 3)
	end
	if offset == 0 then
		s = s .. "Z"
	else
		s = s .. util.format_offset(offset)
	end
	return s
end

function M.format_rfc3339(v)
	return M.format_iso8601(v)
end

function M.format_unix_seconds(v)
	return tostring(v.epoch_seconds)
end

function M.format_unix_milliseconds(v)
	return tostring(v.epoch_seconds * 1000 + v.milliseconds)
end

function M.format_rfc2822(v)
	local offset = effective_offset(v)
	local t = offset_table(v.epoch_seconds, offset)
	local off = util.format_offset(offset):gsub(":", "")
	return string.format(
		"%s, %02d %s %04d %02d:%02d:%02d %s",
		DAYS[t.wday],
		t.day,
		MONTHS[t.month],
		t.year,
		t.hour,
		t.min,
		t.sec,
		off
	)
end

function M.format_http_date(v)
	local t = utc_table(v.epoch_seconds)
	return string.format(
		"%s, %02d %s %04d %02d:%02d:%02d GMT",
		DAYS[t.wday],
		t.day,
		MONTHS[t.month],
		t.year,
		t.hour,
		t.min,
		t.sec
	)
end

function M.format_de(v)
	local offset = util.offset_at(v.epoch_seconds)
	local t = offset_table(v.epoch_seconds, offset)
	return string.format("%02d.%02d.%04d %02d:%02d:%02d", t.day, t.month, t.year, t.hour, t.min, t.sec)
end

function M.format_relative(v)
	local now = os.time()
	local diff = v.epoch_seconds - now
	local abs = math.abs(diff)
	local future = diff > 0
	local function phrase(n, unit)
		return string.format("%d %s%s", n, unit, n == 1 and "" or "s")
	end
	local p
	if abs < 60 then
		return "just now"
	elseif abs < 3600 then
		p = phrase(math.floor(abs / 60), "minute")
	elseif abs < 86400 then
		p = phrase(math.floor(abs / 3600), "hour")
	elseif abs < 2592000 then
		p = phrase(math.floor(abs / 86400), "day")
	elseif abs < 31536000 then
		p = phrase(math.floor(abs / 2592000), "month")
	else
		p = phrase(math.floor(abs / 31536000), "year")
	end
	return future and ("in " .. p) or (p .. " ago")
end

M.formatters = {
	["local"] = { label = "Local", fn = M.format_local },
	utc = { label = "UTC", fn = M.format_utc },
	iso8601 = { label = "ISO-8601", fn = M.format_iso8601 },
	rfc3339 = { label = "RFC-3339", fn = M.format_rfc3339 },
	unix_seconds = { label = "Unix", fn = M.format_unix_seconds },
	unix_milliseconds = { label = "Unix (ms)", fn = M.format_unix_milliseconds },
	rfc2822 = { label = "RFC-2822", fn = M.format_rfc2822 },
	http_date = { label = "HTTP-Date", fn = M.format_http_date },
	de = { label = "DE", fn = M.format_de },
	relative = { label = "Relative", fn = M.format_relative },
}

--- List of { name, label, value } for every configured format.
function M.format_all(v)
	local cfg = config.get()
	local out = {}
	for _, name in ipairs(cfg.formats) do
		local f = M.formatters[name]
		if f then
			local ok, s = pcall(f.fn, v)
			if ok then
				table.insert(out, { name = name, label = f.label, value = s })
			end
		end
	end
	return out
end

--- Format a value into a single target format name.
--- @param v types.Date
--- @return string|nil
function M.format_one(v, name)
	local f = M.formatters[name]
	if not f then
		return nil
	end
	local ok, s = pcall(f.fn, v)
	if ok then
		return s
	end
	return nil
end

return M
