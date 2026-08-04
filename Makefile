.PHONY: test

test:
	nvim --headless -c "luafile tests/run.lua" -c "qa"
