---@diagnostic disable: need-check-nil
local parser = require("epic.parser")
local formats = require("epic.formats")
local assert_eq = _G.assert_eq

test("formats Unix seconds value to UTC", function()
	local v = parser.parse("1716208200")
	assert_eq(formats.format_unix_seconds(v), "1716208200")
	assert_eq(formats.format_utc(v):match("^(%S+ %S+)"), "2024-05-20 12:30:00")
end)

test("round-trips ISO-8601 with offset back to same instant", function()
	local v = parser.parse("2025-05-20T14:30:00+02:00")
	local again = parser.parse(formats.format_iso8601(v))
	assert_eq(again.epoch_seconds, v.epoch_seconds, "round trip epoch")
end)

test("RFC-3339 uses Z for UTC source", function()
	local v = parser.parse("2025-05-20T12:30:00Z")
	assert_eq(formats.format_iso8601(v):sub(-1), "Z")
end)

test("RFC-2822 formatter includes weekday and offset", function()
	local v = parser.parse("2025-05-20T12:30:00Z")
	local s = formats.format_rfc2822(v)
	assert_eq(s:match("^(%a+),"), "Tue")
	assert_eq(s:match("GMT") ~= nil or s:match("%+%d%d%d%d") ~= nil, true)
end)

test("HTTP-Date formatter ends with GMT", function()
	local v = parser.parse("2025-05-20T12:30:00Z")
	assert_eq(formats.format_http_date(v):sub(-3), "GMT")
end)

test("DE formatter format", function()
	local v = parser.parse("2025-05-20T12:30:00Z")
	-- local representation; just check it looks like dd.mm.yyyy hh:mm:ss
	local s = formats.format_de(v)
	assert_eq(s:match("^%d%d%.%d%d%.%d%d%d%d %d%d:%d%d:%d%d$") ~= nil, true, "de format: " .. s)
end)

test("Unix milliseconds formatter", function()
	local v = parser.parse("1716208200123")
	assert_eq(formats.format_unix_milliseconds(v), "1716208200123")
end)

test("relative formatter is just now near present", function()
	local v = parser.parse(tostring(os.time()))
	assert_eq(formats.format_relative(v), "just now")
end)

test("format_all respects configured order", function()
	local v = parser.parse("2025-05-20T12:30:00Z")
	local all = formats.format_all(v)
	assert_eq(all[1].name, "local")
	assert_eq(all[2].name, "utc")
end)
