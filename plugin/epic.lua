if vim.g.loaded_epic then
	return
end
vim.g.loaded_epic = true

-- Ensure config defaults exist even before the user calls setup().
require("epic.config").get()

vim.api.nvim_create_user_command("EpicHover", function()
	require("epic.hover").hover_cursor()
end, {
	desc = "Show all time formats for the value under the cursor",
})

vim.api.nvim_create_user_command("EpicConvert", function(opts)
	require("epic.convert").convert(opts.args, opts.range ~= 0)
end, {
	nargs = "?",
	range = true,
	desc = "Convert the time value under the cursor (or selection) into another format",
	complete = function()
		return {
			"local",
			"utc",
			"iso8601",
			"rfc3339",
			"unix_seconds",
			"unix_milliseconds",
			"rfc2822",
			"http_date",
			"de",
			"de_date",
			"relative",
		}
	end,
})
