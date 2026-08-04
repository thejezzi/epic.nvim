---@diagnostic disable: need-check-nil
local parser = require("epic.parser")
local util = require("epic.util")
local assert_eq = _G.assert_eq

local REF_2025_05_20_1230_UTC = 1747744200

local function epoch_of(y, mo, d, h, mi, s)
	return os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s })
end

test("parses RFC-3339 with Z", function()
	local v = parser.parse("2025-05-20T12:30:00Z")
	assert_eq(v.epoch_seconds, REF_2025_05_20_1230_UTC, "epoch Z")
	assert_eq(v.timezone_source, "utc")
	assert_eq(v.detected_format, "iso8601")
end)

test("parses RFC-3339 with explicit offset", function()
	local v = parser.parse("2025-05-20T14:30:00+02:00")
	assert_eq(v.epoch_seconds, REF_2025_05_20_1230_UTC, "epoch offset")
	assert_eq(v.timezone_offset_seconds, 7200)
	assert_eq(v.timezone_source, "explicit")
end)

test("parses ISO with milliseconds", function()
	local v = parser.parse("2025-05-20T12:30:00.123Z")
	assert_eq(v.milliseconds, 123)
	assert_eq(v.timezone_source, "utc")
end)

test("parses date-only ISO as local", function()
	local v = parser.parse("2025-05-20")
	assert_eq(v.timezone_source, "local")
	assert_eq(v.detected_format, "iso8601_date")
end)

test("parses Unix seconds", function()
	local v = parser.parse("1716208200")
	assert_eq(v.epoch_seconds, 1716208200)
	assert_eq(v.detected_format, "unix_seconds")
end)

test("parses Unix milliseconds", function()
	local v = parser.parse("1716208200123")
	assert_eq(v.epoch_seconds, 1716208200)
	assert_eq(v.milliseconds, 123)
	assert_eq(v.detected_format, "unix_milliseconds")
end)

test("parses @-prefixed Unix", function()
	local v = parser.parse("@1716208200")
	assert_eq(v.epoch_seconds, 1716208200)
end)

test("rejects too-short numbers", function()
	assert_eq(parser.parse("12345"), nil)
end)

test("parses RFC-2822", function()
	local v = parser.parse("Tue, 20 May 2025 14:30:00 +0200")
	assert_eq(v.epoch_seconds, REF_2025_05_20_1230_UTC, "epoch rfc2822")
	assert_eq(v.detected_format, "rfc2822")
end)

test("parses HTTP-Date", function()
	local v = parser.parse("Tue, 20 May 2025 12:30:00 GMT")
	assert_eq(v.epoch_seconds, REF_2025_05_20_1230_UTC, "epoch http")
	assert_eq(v.detected_format, "http_date")
end)

test("parses German date with time", function()
	local v = parser.parse("20.05.2025 14:30:00")
	assert_eq(v.timezone_source, "local")
	assert_eq(v.epoch_seconds, epoch_of(2025, 5, 20, 14, 30, 0), "epoch de")
end)

test("parses German date only", function()
	local v = parser.parse("20.05.2025")
	assert_eq(v.detected_format, "de")
	assert_eq(v.epoch_seconds, epoch_of(2025, 5, 20, 0, 0, 0))
end)

test("ambiguous slash date is rejected by default", function()
	local v = parser.parse("05/06/2025")
	assert_eq(v.ambiguous, true)
	assert_eq(#v.candidates, 2)
end)

test("unambiguous slash date (month > 12) resolves to dmy", function()
	local v = parser.parse("20/05/2025")
	assert_eq(v.ambiguous, nil)
	assert_eq(v.detected_format, "slash_dmy")
end)

test("rejects invalid day", function()
	assert_eq(parser.parse("2025-02-30"), nil)
	assert_eq(parser.parse("2025-13-01"), nil)
end)

test("leap day is valid in leap year", function()
	local v = parser.parse("2024-02-29")
	assert_eq(v ~= nil, true)
end)

test("leap day is invalid in non-leap year", function()
	assert_eq(parser.parse("2025-02-29"), nil)
end)

test("round-trips offset equivalence", function()
	local a = parser.parse("2025-05-20T12:30:00Z")
	local b = parser.parse("2025-05-20T14:30:00+02:00")
	assert_eq(a.epoch_seconds, b.epoch_seconds, "same instant")
end)

test("parses literal 'UTC' word suffix as UTC", function()
	for _, t in ipairs({
		"2025-05-20 12:30:00 UTC",
		"2025-05-20T12:30:00 UTC",
		"2025-05-20T12:30:00UTC",
	}) do
		local v = parser.parse(t)
		assert_eq(v ~= nil, true, "should parse: " .. t)
		assert_eq(v.timezone_source, "utc", "source for " .. t)
		assert_eq(v.timezone_offset_seconds, 0, "offset for " .. t)
		assert_eq(v.epoch_seconds, REF_2025_05_20_1230_UTC, "epoch for " .. t)
	end
end)

test("parses literal 'GMT' word suffix as UTC", function()
	local v = parser.parse("2025-05-20 12:30:00 GMT")
	assert_eq(v ~= nil, true)
	assert_eq(v.timezone_source, "utc")
	assert_eq(v.epoch_seconds, REF_2025_05_20_1230_UTC)
end)

test("round-trips the plugin's own format_utc output", function()
	local formats = require("epic.formats")
	local orig = parser.parse("2025-05-20T12:30:00Z")
	local back = parser.parse(formats.format_utc(orig))
	assert_eq(back ~= nil, true, "re-parse of format_utc output")
	assert_eq(back.epoch_seconds, orig.epoch_seconds, "epoch preserved")
end)
