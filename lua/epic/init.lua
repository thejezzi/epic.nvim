local config = require("epic.config")

local M = {}

function M.setup(opts)
  local cfg = config.setup(opts)
  if cfg.create_commands then
    M.create_commands()
  end

  -- Highlight group for the picker selection line.
  vim.api.nvim_set_hl(0, "EpicPickerSel", {
    default = true,
    bold = true,
    fg = "#ffffff",
    bg = "#264f78",
  })

  return M
end

function M.create_commands()
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
        "local", "utc", "iso8601", "rfc3339",
        "unix_seconds", "unix_milliseconds",
        "rfc2822", "http_date", "de", "relative",
      }
    end,
  })
end

return M
