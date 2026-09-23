local util = require("epic.util")
local parser = require("epic.parser")
local formats = require("epic.formats")
local config = require("epic.config")

local M = {}

local state = nil

local function build_lines(value)
	local lines = {}
	table.insert(lines, value.original_text)
	if value.detected_format then
		lines[1] = lines[1] .. "  (" .. value.detected_format .. ")"
	end
	table.insert(lines, "")

	if value.ambiguous then
		table.insert(lines, "Ambiguous date — candidate interpretations:")
		for i, c in ipairs(value.candidates) do
			table.insert(lines, string.format("  %d. [%s]  %s", i, c.detected_format, formats.format_iso8601(c)))
		end
		return lines
	end

	local all = formats.format_all(value)
	local width = 0
	for _, e in ipairs(all) do
		if #e.label > width then
			width = #e.label
		end
	end
	for _, e in ipairs(all) do
		table.insert(lines, string.format("%-" .. width .. "s  %s", e.label, e.value))
	end
	return lines
end

function M.open(value)
	M.close()
	local cfg = config.get().hover
	local lines = build_lines(value)

	local width = 0
	for _, l in ipairs(lines) do
		if #l > width then
			width = #l
		end
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = width + 2,
		height = #lines,
		style = "minimal",
		border = cfg.border or "rounded",
	})

	state = { buf = buf, win = win }

	local function close()
		M.close()
	end
	local opts = { buffer = buf, noremap = true, silent = true }
	vim.keymap.set("n", "q", close, opts)
	vim.keymap.set("n", "<Esc>", close, opts)

	if cfg.close_on_cursor_move then
		vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave", "WinLeave" }, {
			callback = function()
				close()
				return true
			end,
			once = true,
		})
	end
end

function M.close()
	if not state then
		return
	end
	local win = state.win
	state = nil
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

--- Hover over whatever is under the cursor.
function M.hover_cursor()
	local sel = util.get_text_under_cursor()
	if not sel then
		-- util.notify("no time value found under cursor")
		M.insert_now()
		return
	end
	local value = parser.parse(sel.text)
	if not value then
		util.notify("could not parse: " .. sel.text)
		return
	end
	M.open(value)
end

function M.insert_now()
	local primary = config.get().primary_format
	local date = os.date("*t")
	local iso8601 =
		string.format("%04d-%02d-%02dT%02d:%02d:%02d", date.year, date.month, date.day, date.hour, date.min, date.sec)
	if not formats.formatters[primary] then
		util.notify("invalid primary formatter: " .. primary, vim.log.levels.ERROR)
		return
	end
	local parsed = parser.parse(iso8601)
	if parsed == nil then
		util.notify("unable to parse now as iso8601", vim.log.levels.ERROR)
		return
	end
	local formatted = formats.format_one(parsed, primary)
	if formatted == nil then
		util.notify("unable to format now to the desired primary format", vim.log.levels.ERROR)
		return
	end
	util.insert_under_cursor(formatted)
end

return M
