local M = {}

M.defaults = {
	-- nil uses the system local timezone.
	local_timezone = nil,
	-- How to resolve ambiguous slash dates like 05/06/2025.
	-- "reject" shows candidates instead of guessing; "dmy" or "mdy" picks one.
	ambiguous_date_order = "reject",
	-- Formats shown in hover and offered in the convert picker, in this order.
	formats = {
		"local",
		"utc",
		"iso8601",
		"rfc3339",
		"unix_seconds",
		"unix_milliseconds",
		"rfc2822",
		"http_date",
		"relative",
		"de",
		"de_date",
	},
	hover = {
		border = "rounded",
		close_on_cursor_move = true,
	},
	picker = {
		border = "rounded",
	},
	create_commands = true,
	primary_format = "local",
}

M.options = nil

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
	return M.options
end

function M.get()
	if not M.options then
		M.setup({})
	end
	return M.options
end

return M
