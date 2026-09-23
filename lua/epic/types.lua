---@meta

---@alias epic.Format
---| "local"
---| "utc"
---| "iso8601"
---| "rfc3339"
---| "unix_seconds"
---| "unix_milliseconds"
---| "rfc2822"
---| "http_date"
---| "de"
---| "de_date"
---| "relative"

---@alias epic.AmbiguousDateOrder "reject" | "dmy" | "mdy"
---@alias epic.Border "none" | "single" | "double" | "rounded" | "solid" | "shadow" | string[]

---@class epic.FloatConfig
---@field border? epic.Border

---@class epic.HoverConfig: epic.FloatConfig
---@field close_on_cursor_move? boolean

---@class epic.PickerConfig: epic.FloatConfig

---@class epic.Config
---@field local_timezone? string
---@field ambiguous_date_order? epic.AmbiguousDateOrder
---@field formats? epic.Format[]
---@field hover? epic.HoverConfig
---@field picker? epic.PickerConfig
---@field create_commands? boolean
---@field primary_format? epic.Format

local M = {}

---@class types.Date
M.Date = {
	epoch_seconds = 0,
	milliseconds = 0,
	timezone_offset_seconds = 0,
	timezone_source = 0,
	original_text = "",
	detected_format = "",
}

return M
