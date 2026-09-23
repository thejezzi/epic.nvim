.PHONY: test

test:
	nvim --headless -u NONE -c "luafile tests/run.lua" -c "qa"
