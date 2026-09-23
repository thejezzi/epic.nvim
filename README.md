# epic.nvim

Convert and inspect date/time strings in any format, right from Neovim.

Epic recognizes a date/time value under your cursor, shows the same
instant in every supported format via a hover float, and lets you convert a
value (or visual selection) into any of those formats in place.

## Features

- **Hover** (`:EpicHover`): floating window listing every format for the
  value under the cursor.
- **Insert now**: if `:EpicHover` finds no time value under the cursor, it
  inserts the current time in `primary_format` instead.
- **Convert** (`:EpicConvert [format]`): replace the cursor value or visual
  selection with another format; undo-friendly.
- **Format picker** when no target is given.
- Ambiguous dates (e.g. `05/06/2025`) are not guessed silently — you choose
  the interpretation.
- No required dependencies.

## Supported formats

ISO-8601 / RFC-3339, Unix seconds & milliseconds, RFC-2822, HTTP-Date, German
(`dd.mm.yyyy`) and US slash dates. Strings without a timezone are interpreted
in your local timezone.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "thejezzi/epic.nvim",
  opts = {},
}
```

### Manual / native packages

Clone into `~/.local/share/nvim/site/pack/.../opt/` (or `start/`) and load
with `:packadd epic.nvim` if needed.

## Setup

```lua
require("epic").setup({
  local_timezone = nil,            -- nil = system timezone
  ambiguous_date_order = "reject", -- "reject" | "dmy" | "mdy"
  formats = {
    "local", "utc", "iso8601", "rfc3339",
    "unix_seconds", "unix_milliseconds", "rfc2822", "http_date",
    "relative",
  },
  hover = { border = "rounded", close_on_cursor_move = true },
  picker = { border = "rounded" },
  primary_format = "local",       -- format used when inserting the current time
})
```

## Usage

```vim
:EpicHover                  " show all formats under the cursor;
                            " with no time value there, insert now in
                            " primary_format
:EpicConvert                " pick a target format, then replace
:EpicConvert iso8601        " replace cursor value with ISO-8601
:EpicConvert unix_seconds    " replace with Unix seconds

" Visual mode:
:'<,'>EpicConvert utc
```

Suggested keymaps:

```lua
vim.keymap.set("n", "<leader>eh", "<cmd>EpicHover<cr>")
vim.keymap.set("n", "<leader>ec", "<cmd>EpicConvert<cr>")
vim.keymap.set("v", "<leader>ec", ":EpicConvert<cr>")
```

## Tests

```sh
nvim --headless -c "luafile tests/run.lua" -c "qa"
```

or, if you have `make`:

```sh
make test
```

## License

MIT
