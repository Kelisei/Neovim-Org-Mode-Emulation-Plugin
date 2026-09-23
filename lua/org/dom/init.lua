local Parser = require("org.dom.parser")
local Query = require("org.dom.query")
local Config = require("org.config")

local M = {}
local cache = {}

--- Retrieve or parse the DOM tree for a specified buffer.
--- @param bufnr number|nil
--- @return table
function M.get(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
	if cache[bufnr] and cache[bufnr].changedtick == changedtick then
		return cache[bufnr].root
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local root = Parser.parse(lines, Config.options.org_todo_keywords)
	cache[bufnr] = {
		changedtick = changedtick,
		root = root,
	}
	return root
end

--- Clear cached DOM for buffer.
--- @param bufnr number|nil
function M.invalidate(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	cache[bufnr] = nil
end

--- Find headline encompassing current cursor line.
--- @param bufnr number|nil
--- @param cursor_line number|nil
--- @return table|nil
function M.get_current_headline(bufnr, cursor_line)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not cursor_line then
		local cursor = vim.api.nvim_win_get_cursor(0)
		cursor_line = cursor[1]
	end
	local root = M.get(bufnr)
	return Query.find_headline_at_line(root, cursor_line)
end

return setmetatable(M, {
	__index = function(_, key)
		return Query[key]
	end,
})
