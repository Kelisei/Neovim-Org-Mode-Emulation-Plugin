local test_modules = {
	"tests.test_parser",
	"tests.test_table",
	"tests.test_todo",
	"tests.test_babel",
	"tests.test_list",
	"tests.test_repeater",
	"tests.test_links",
	"tests.test_agenda",
}

local passed = 0
local failed = 0

for _, mod_name in ipairs(test_modules) do
	local ok, mod = pcall(require, mod_name)
	if not ok then
		io.stderr:write(string.format("FAIL: Could not load %s: %s\n", mod_name, tostring(mod)))
		failed = failed + 1
	else
		local run_ok, success, msg = pcall(mod.run)
		if run_ok and success then
			io.stdout:write(string.format("PASS: %s (%s)\n", mod_name, msg or "ok"))
			passed = passed + 1
		else
			local err = not run_ok and tostring(success) or tostring(msg)
			io.stderr:write(string.format("FAIL: %s: %s\n", mod_name, err))
			failed = failed + 1
		end
	end
end

io.stdout:write(string.format("\nTest Results: %d passed, %d failed\n", passed, failed))
if failed > 0 then
	vim.cmd("cquit 1")
else
	vim.cmd("qall!")
end
