local util = require("epic.util")
local parser = require("epic.parser")
local formats = require("epic.formats")
local config = require("epic.config")
local picker = require("epic.picker")

local M = {}

local function replace_range(sel, replacement)
  local row = sel.row or vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  if not line then
    return false
  end
  local new_line = line:sub(1, sel.start_col - 1) .. replacement .. line:sub(sel.end_col + 1)
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
  return true
end

local function do_replace(value, sel, target)
  local out = formats.format_one(value, target)
  if not out then
    util.notify("unknown format: " .. target)
    return
  end
  replace_range(sel, out)
end

local function pick_format(value, sel)
  local cfg = config.get()
  local items = {}
  for _, name in ipairs(cfg.formats) do
    local f = formats.formatters[name]
    if f then
      local s = formats.format_one(value, name)
      if s then
        table.insert(items, { label = f.label .. "  →  " .. s, value = name })
      end
    end
  end
  picker.open("Select target format", items, function(item)
    if item then
      do_replace(value, sel, item.value)
    end
  end)
end

local function pick_interpretation_then_format(ambiguous, sel)
  local items = {}
  for _, c in ipairs(ambiguous.candidates) do
    table.insert(items, {
      label = c.detected_format .. "  →  " .. formats.format_iso8601(c),
      value = c,
    })
  end
  picker.open("Ambiguous date — pick interpretation", items, function(item)
    if item then
      pick_format(item.value, sel)
    end
  end)
end

--- Convert the value under the cursor (normal mode) or the last visual
--- selection (when use_selection is true) into the target format.
--- target may be nil to open a format picker.
function M.convert(target, use_selection)
  local sel
  if use_selection then
    sel = util.get_visual_selection()
    if not sel then
      util.notify("no visual selection available")
      return
    end
  else
    sel = util.get_text_under_cursor()
    if not sel then
      util.notify("no time value found under cursor")
      return
    end
    sel.row = vim.api.nvim_win_get_cursor(0)[1]
  end

  local value = parser.parse(sel.text)
  if not value then
    util.notify("could not parse: " .. sel.text)
    return
  end

  if value.ambiguous then
    pick_interpretation_then_format(value, sel)
    return
  end

  if target and target ~= "" then
    do_replace(value, sel, target)
  else
    pick_format(value, sel)
  end
end

return M
