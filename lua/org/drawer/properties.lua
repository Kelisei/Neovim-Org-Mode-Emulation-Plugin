local DOM = require("org.dom")

local M = {}

--- Locate or create the PROPERTIES drawer directly under a headline.
--- @param bufnr number
--- @param headline_lnum number
--- @return number, number
local function ensure_properties_drawer(bufnr, headline_lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local total = #lines
	local drawer_start = nil
	local drawer_end = nil

	local i = headline_lnum + 1
	while i <= total do
		local line = lines[i]
		if line:match("^(%*+)%s+") then
			break
		end
		if line:match("^%s*:PROPERTIES:%s*$") then
			drawer_start = i
		elseif line:match("^%s*:END:%s*$") and drawer_start and not drawer_end then
			drawer_end = i
			break
		end
		i = i + 1
	end

	if drawer_start and drawer_end then
		return drawer_start, drawer_end
	end

	local insert_pos = headline_lnum
	if lines[headline_lnum + 1] and (lines[headline_lnum + 1]:match("SCHEDULED:") or lines[headline_lnum + 1]:match("DEADLINE:") or lines[headline_lnum + 1]:match("CLOSED:")) then
		insert_pos = headline_lnum + 1
	end

	local template = {
		"  :PROPERTIES:",
		"  :END:",
	}
	vim.api.nvim_buf_set_lines(bufnr, insert_pos, insert_pos, false, template)
	DOM.invalidate(bufnr)
	return insert_pos + 1, insert_pos + 2
end

--- Set or update a property in the PROPERTIES drawer of a headline.
--- @param bufnr number
--- @param headline_lnum number
--- @param key string
--- @param value string
function M.set_property(bufnr, headline_lnum, key, value)
	local d_start, d_end = ensure_properties_drawer(bufnr, headline_lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, d_start, d_end - 1, false)
	local norm_key = string.upper(key)
	local updated = false

	for idx, l in ipairs(lines) do
		local cur_key = l:match("^%s*:(%S-):")
		if cur_key and string.upper(cur_key) == norm_key then
			lines[idx] = string.format("  :%s: %s", norm_key, value)
			updated = true
			break
		end
	end

	if not updated then
		table.insert(lines, string.format("  :%s: %s", norm_key, value))
	end

	vim.api.nvim_buf_set_lines(bufnr, d_start, d_end - 1, false, lines)
	DOM.invalidate(bufnr)
end

--- Retrieve a property from headline with optional inheritance from ancestors.
--- @param bufnr number
--- @param headline_lnum number
--- @param key string
--- @param inherit boolean|nil
--- @return string|nil
function M.get_property(bufnr, headline_lnum, key, inherit)
	local root = DOM.get(bufnr)
	local node = DOM.find_headline_at_line(root, headline_lnum)
	if not node then
		return nil
	end
	return node:get_property(key, inherit)
end

--- Remove a property from the PROPERTIES drawer.
--- @param bufnr number
--- @param headline_lnum number
--- @param key string
function M.remove_property(bufnr, headline_lnum, key)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local total = #lines
	local d_start = nil
	local d_end = nil

	local i = headline_lnum + 1
	while i <= total do
		local line = lines[i]
		if line:match("^(%*+)%s+") then
			break
		end
		if line:match("^%s*:PROPERTIES:%s*$") then
			d_start = i
		elseif line:match("^%s*:END:%s*$") and d_start and not d_end then
			d_end = i
			break
		end
		i = i + 1
	end

	if not d_start or not d_end then
		return
	end

	local prop_lines = vim.api.nvim_buf_get_lines(bufnr, d_start, d_end - 1, false)
	local norm_key = string.upper(key)
	local new_props = {}

	for _, l in ipairs(prop_lines) do
		local cur_key = l:match("^%s*:(%S-):")
		if not (cur_key and string.upper(cur_key) == norm_key) then
			table.insert(new_props, l)
		end
	end

	vim.api.nvim_buf_set_lines(bufnr, d_start, d_end - 1, false, new_props)
	DOM.invalidate(bufnr)
end

return M
