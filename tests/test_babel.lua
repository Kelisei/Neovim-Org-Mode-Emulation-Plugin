local Execute = require("org.babel.execute")
local Tangle = require("org.babel.tangle")

local M = {}

--- Execute Org Babel execution and tangling unit tests.
--- @return boolean, string|nil
function M.run()
	local python_lines = {
		"print(int(limit) * 10)",
	}
	local ok, out = Execute.run("python", python_lines, {
		results = "output",
		vars = { limit = "5" },
	})
	assert(ok, "Babel python execution failed")
	assert(out[1] == ": 50", "Babel python output mismatch: " .. tostring(out[1]))

	local py_table_lines = {
		'data = [["Item", "Value"], ["Alpha", 1 * int(multiplier)], ["Beta", 2 * int(multiplier)]]',
		"return data",
	}
	local t_ok, t_out = Execute.run("python", py_table_lines, {
		results = "table",
		vars = { multiplier = "10" },
	})
	assert(t_ok, "Babel python table execution failed")
	assert(#t_out == 3, "Expected 3 table rows, got " .. #t_out)
	assert(t_out[1]:find("Item"), "Row 1 mismatch: " .. t_out[1])
	assert(t_out[2]:find("10"), "Row 2 mismatch: " .. t_out[2])
	assert(t_out[3]:find("20"), "Row 3 mismatch: " .. t_out[3])

	local bash_lines = {
		'echo "hello $name"',
	}
	local b_ok, b_out = Execute.run("bash", bash_lines, {
		results = "output",
		vars = { name = "world" },
	})
	assert(b_ok, "Babel bash execution failed")
	assert(b_out[1] == ": hello world", "Babel bash output mismatch: " .. tostring(b_out[1]))

	local target_file = "/tmp/org_tangle_test.py"
	os.remove(target_file)
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"#+BEGIN_SRC python :tangle /tmp/org_tangle_test.py",
		"def greet():",
		'    return "hello"',
		"#+END_SRC",
	})

	local res = Tangle.tangle(bufnr)
	assert(res[target_file] == 2, "Tangle result line count mismatch")
	local f = io.open(target_file, "r")
	assert(f ~= nil, "Tangled file was not created on disk")
	local content = f:read("*a")
	f:close()
	os.remove(target_file)
	vim.api.nvim_buf_delete(bufnr, { force = true })
	assert(content:find("def greet"), "Tangled file content mismatch")

	return true, "Babel and tangle tests passed"
end

return M
