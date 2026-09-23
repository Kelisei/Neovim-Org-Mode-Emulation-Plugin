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

	vim.api.nvim_buf_delete(bufnr, { force = true })
	return true, "Link tests passed"
end

return M
