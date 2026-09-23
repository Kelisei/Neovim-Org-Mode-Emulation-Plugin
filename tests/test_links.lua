local Link = require("org.link")
local DOM = require("org.dom")

local M = {}

--- Execute link detection and target resolution unit tests.
--- @return boolean, string|nil
function M.run()
	local line = "Check [[https://neovim.io][Neovim]] and [[#deliv-a]] now."
	local uri1, desc1, s1, e1 = Link.find_link_at_col(line, 10)
	assert(uri1 == "https://neovim.io", "URI mismatch: " .. tostring(uri1))
	assert(desc1 == "Neovim", "Desc mismatch: " .. tostring(desc1))

	local uri2, desc2 = Link.find_link_at_col(line, 45)
	assert(uri2 == "#deliv-a", "Custom ID link mismatch: " .. tostring(uri2))
	assert(desc2 == nil, "Bare link description should be nil")

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"* Main Heading",
		"  :PROPERTIES:",
		"  :CUSTOM_ID: deliv-a",
		"  :ID: uuid-999",
		"  :END:",
		"  Text here with <<target-anchor>>.",
	})

	local root = DOM.get(bufnr)
	local match_custom = DOM.find_by_custom_id(root, "deliv-a")
	assert(match_custom ~= nil, "DOM find_by_custom_id failed")
	assert(match_custom.range.start_line == 1, "Line mismatch for custom id")

	local match_id = DOM.find_by_id(root, "uuid-999")
	assert(match_id ~= nil, "DOM find_by_id failed")

	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	Link._jump_stack = {}
	Link.push_jump()
	assert(#Link._jump_stack == 1, "Jump stack push failed")
	vim.api.nvim_win_set_cursor(0, { 5, 0 })
	local jumped = Link.jump_back()
	assert(jumped == true, "Jump back failed")
	local cur_pos = vim.api.nvim_win_get_cursor(0)
	assert(cur_pos[1] == 1, "Jump back line mismatch")

	local Format = require("org.format")
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"* Sprint 1",
		"  :LOGBOOK:",
		"  - Note taken on [2026-09-23 Wed 11:52] \\\\",
		"    Investigating memory usage",
		"  :END:",
	})
	Format.render_inline_notes(bufnr)
	local ns = vim.api.nvim_create_namespace("org_inline_notes")
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
	assert(#marks == 1, "Expected 1 extmark for inline note")
	assert(marks[1][2] == 0, "Extmark line mismatch")
	local virt_text = marks[1][4].virt_text[1][1]
	assert(virt_text:find("Investigating memory usage"), "Virt text mismatch: " .. tostring(virt_text))

	Format.clear_inline_notes(bufnr)
	marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
	assert(#marks == 0, "Expected extmarks cleared")

	vim.api.nvim_buf_delete(bufnr, { force = true })
	return true, "Link and inline note tests passed"
end

return M
