local State = require("org.todo.state")
local Priority = require("org.todo.priority")

local M = {}

--- Execute todo state and priority unit tests.
--- @return boolean, string|nil
function M.run()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"#+TODO: TODO(t) NEXT(n) | DONE(d!) CANCELED(c)",
		"* TODO [#B] Fix critical memory leak",
		"  Some description",
	})

	Priority.cycle_up(bufnr, 2)
	local line = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1]
	assert(line:find("%[#A%]"), "Priority cycle up failed: " .. line)

	State.cycle(bufnr, 2)
	line = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1]
	assert(line:find("%* NEXT "), "State cycle to NEXT failed: " .. line)

	State.cycle(bufnr, 2)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local found_done = false
	local found_closed = false
	for _, l in ipairs(lines) do
		if l:find("%* DONE ") then
			found_done = true
		end
		if l:find("CLOSED:%s*%[[^%]]+%]") then
			found_closed = true
		end
	end
	assert(found_done, "State transition to DONE failed")
	assert(found_closed, "CLOSED timestamp insertion failed")

	vim.api.nvim_buf_delete(bufnr, { force = true })
	return true, "Todo tests passed"
end

return M
