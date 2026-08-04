local config = require("epic.config")

local M = {}

local state = nil

--- Open a simple float picker.
--- items: list of { label, value } (value is opaque, returned to on_choice)
--- on_choice: function(item) called with the chosen item, or nil if cancelled
function M.open(title, items, on_choice)
  M.close()
  if #items == 0 then
    return
  end

  local selected = 1
  local cfg = config.get().picker
  local ns = vim.api.nvim_create_namespace("epic.picker")

  local function line_for(i)
    local marker = (i == selected) and "› " or "  "
    return marker .. items[i].label
  end

  local function max_width()
    local w = #title
    for _, it in ipairs(items) do
      if #it.label + 2 > w then
        w = #it.label + 2
      end
    end
    return w
  end

  local width = max_width() + 2
  local height = #items + 1 -- title line

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local function render()
    local lines = { title }
    for i, _ in ipairs(items) do
      lines[#lines + 1] = line_for(i)
    end
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns, "EpicPickerSel", selected, 0, -1)
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = cfg.border or "rounded",
    title = " epic ",
    title_pos = "center",
  })

  state = { buf = buf, win = win }

  local function close(cancel)
    if state then
      M.close()
    end
    if not cancel then
      on_choice(items[selected])
    end
  end

  local function move(delta)
    selected = selected + delta
    if selected < 1 then
      selected = #items
    elseif selected > #items then
      selected = 1
    end
    render()
  end

  render()

  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "j", function() move(1) end, opts)
  vim.keymap.set("n", "k", function() move(-1) end, opts)
  vim.keymap.set("n", "<Down>", function() move(1) end, opts)
  vim.keymap.set("n", "<Up>", function() move(-1) end, opts)
  vim.keymap.set("n", "<CR>", function() close(false) end, opts)
  vim.keymap.set("n", "q", function() close(true) end, opts)
  vim.keymap.set("n", "<Esc>", function() close(true) end, opts)

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function() close(true) end,
    once = true,
  })
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

return M
