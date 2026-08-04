-- Test runner for epic. Run with:
--   nvim --headless -c "luafile tests/run.lua" -c "qa"
-- Exits with code 1 if any test fails (prints summary to stdout).

local passed = 0
local failed = 0
local failures = {}

local function eq(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) == "table" then
		for k, v in pairs(a) do
			if not eq(v, b[k]) then
				return false
			end
		end
		for k, _ in pairs(b) do
			if a[k] == nil then
				return false
			end
		end
		return true
	end
	return a == b
end

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print(("PASS  %s"):format(name))
	else
		failed = failed + 1
		table.insert(failures, name .. "\n  " .. tostring(err))
		print(("FAIL  %s\n        %s"):format(name, tostring(err)))
	end
end

_G.assert_eq = function(actual, expected, msg)
	if not eq(actual, expected) then
		error(
			string.format(
				"%s\n  expected: %s\n  got:      %s",
				msg or "assertion failed",
				vim.inspect(expected),
				vim.inspect(actual)
			)
		)
	end
end

_G.test = test

-- Load test files in the runtime path
vim.cmd("set rtp+=.")
require("epic.config").setup({ ambiguous_date_order = "reject" })

dofile("tests/test_parser.lua")
dofile("tests/test_formats.lua")

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	print("\nFailures:")
	for _, f in ipairs(failures) do
		print("  " .. f)
	end
	vim.cmd("cquit 1")
end
