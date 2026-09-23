local M = {}

--- Seconds that the local timezone is ahead of UTC at a given instant.
--- Handles DST correctly by clearing isdst so mktime resolves it itself.
function M.offset_at(epoch)
	local utc = os.date("!*t", epoch)
	local loc = os.date("*t", epoch)
	utc.isdst = nil
	loc.isdst = nil
	return os.difftime(os.time(loc), os.time(utc))
end

--- Current local offset (shorthand for the current instant).
function M.local_offset_seconds()
	return M.offset_at(os.time())
end

--- Parse an ISO-style timezone designator ("Z", "+02:00", "+0200", "-05:00").
--- Returns offset in seconds or nil if it cannot be parsed.
function M.parse_offset(s)
	if not s or s == "" then
		return nil
	end
	if s == "Z" or s == "z" then
		return 0
	end
	local sign, h, m = s:match("^([%+%-])(%d%d):?(%d%d)$")
	if not sign then
		return nil
	end
	local off = tonumber(h) * 3600 + tonumber(m) * 60
	if sign == "-" then
		off = -off
	end
	return off
end

function M.pad(n, width)
	local s = tostring(math.floor(n))
	while #s < width do
		s = "0" .. s
	end
	return s
end

function M.format_offset(offset_seconds)
	local sign = offset_seconds < 0 and "-" or "+"
	local abs = math.abs(offset_seconds)
	local h = math.floor(abs / 3600)
	local m = math.floor((abs % 3600) / 60)
	return string.format("%s%02d:%02d", sign, h, m)
end

function M.format_datetime(t, with_ms, ms)
	local s = string.format("%04d-%02d-%02d %02d:%02d:%02d", t.year, t.month, t.day, t.hour, t.min, t.sec)
	if with_ms and ms and ms > 0 then
		s = s .. "." .. M.pad(ms, 3)
	end
	return s
end

function M.notify(msg, level)
	vim.notify("[epic] " .. msg, level or vim.log.levels.WARN)
end

function M.trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Find a datetime-like substring on the current line around the cursor.
--- Returns { text, start_col, end_col } (columns are 1-indexed byte offsets) or nil.
function M.get_text_under_cursor()
	local _, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local cursor = col + 1 -- nvim col is 0-indexed

	local patterns = {
		-- ISO with literal UTC/GMT word suffix first, so the word is not truncated.
		"%d%d%d%d%-%d%d%-%d%d[Tt ]%d%d:%d%d:%d%d[%.%d]* ?[Uu][Tt][Cc]",
		"%d%d%d%d%-%d%d%-%d%d[Tt ]%d%d:%d%d:%d%d[%.%d]* ?[Gg][Mm][Tt]",
		"%d%d%d%d%-%d%d%-%d%d[Tt ]%d%d:%d%d:%d%d[%.%d]*[Zz%+%-%d:]*",
		"@?%d%d%d%d%d%d%d%d%d%d+",
		"%a+,%s+%d%d%s+%a+%s+%d%d%d%d%s+%d%d:%d%d:%d%d%s+[%+%-]?%a+",
		"%d%d%.%d%d%.%d%d%d%d[ Tt]?%d*:?%d*:?%d*",
		"%d%d/%d%d/%d%d%d%d[ Tt]?%d*:?%d*:?%d*",
		"%d%d%d%d%-%d%d%-%d%d",
	}

	for _, pat in ipairs(patterns) do
		local start = 1
		while true do
			local s, e = line:find(pat, start)
			if not s then
				break
			end
			if cursor >= s and cursor <= e then
				return { text = M.trim(line:sub(s, e)), start_col = s, end_col = e }
			end
			start = e + 1
		end
	end
	return nil
end

--- Read the last visual selection (single-line only).
--- Returns { text, row, start_col, end_col } or nil.
function M.get_visual_selection()
	local _, srow, scol = unpack(vim.fn.getpos("'<"))
	local _, erow, ecol = unpack(vim.fn.getpos("'>"))
	if srow == 0 or erow == 0 then
		return nil
	end
	if srow ~= erow then
		return nil
	end
	local line = vim.fn.getline(srow)
	if scol > ecol then
		scol, ecol = ecol, scol
	end
	local text = M.trim(line:sub(scol, ecol))
	if text == "" then
		return nil
	end
	return { text = text, row = srow, start_col = scol, end_col = ecol }
end

--- @param value string
function M.insert_under_cursor(value)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { value })
end

return M
