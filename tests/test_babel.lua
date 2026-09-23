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
