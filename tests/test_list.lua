local List = require("org.list")

local M = {}

--- Execute list checkbox and statistics cookie unit tests.
--- @return boolean, string|nil
function M.run()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"* Sprint Planning [0/2] [0%]",
		"  - Tasks [/] [%]",
		"    - [ ] Implement AST parser",
		"    - [ ] Add syntax highlighter",
	})

	vim.api.nvim_win_set_buf(0, bufnr)
	vim.api.nvim_win_set_cursor(0, { 3, 7 })
	List.toggle_checkbox()

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	assert(lines[3]:find("%[X%]"), "Checkbox toggle to [X] failed: " .. lines[3])
	assert(lines[1]:find("%[1/2%]"), "Cookie count [1/2] failed: " .. lines[1])
	assert(lines[1]:find("%[50%%%]"), "Cookie percent [50%] failed: " .. lines[1])

	vim.api.nvim_win_set_cursor(0, { 4, 7 })
	List.toggle_checkbox()

	lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	assert(lines[1]:find("%[2/2%]"), "Cookie count [2/2] failed: " .. lines[1])
	assert(lines[1]:find("%[100%%%]"), "Cookie percent [100%] failed: " .. lines[1])

	vim.api.nvim_buf_delete(bufnr, { force = true })
	return true, "List and checkbox tests passed"
end

return M
