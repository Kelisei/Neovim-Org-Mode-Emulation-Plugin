local DOM = require("org.dom")

local M = {}

--- Locate inline org link enclosing cursor column on line.
--- @param line string
--- @param col number
--- @return string|nil, string|nil, number|nil, number|nil
function M.find_link_at_col(line, col)
	col = col + 1
	local start_idx = 1
	while true do
		local s, e, uri, desc = line:find("%[%[(.-)%]%[(.-)%]%]", start_idx)
		if s then
			if s <= col and col <= e then
				return uri, desc, s, e
			end
			start_idx = e + 1
		else
			s, e, uri = line:find("%[%[(.-)%]%]", start_idx)
			if s then
				if s <= col and col <= e then
					return uri, nil, s, e
				end
				start_idx = e + 1
			else
				break
			end
		end
	end
	return nil, nil, nil, nil
end

--- Jump to internal anchor target like <<anchor>> in buffer.
--- @param bufnr number
--- @param target string
--- @return boolean
local function jump_to_anchor(bufnr, target)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local pattern = "<<" .. vim.pesc(target) .. ">>"
	for idx, l in ipairs(lines) do
		if l:find(pattern) then
			vim.api.nvim_win_set_cursor(0, { idx, 0 })
			return true
		end
	end
	return false
end

--- Follow the link under the current cursor position.
function M.open_at_point()
	local line = vim.api.nvim_get_current_line()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local col = cursor[2]
	local uri, _, _, _ = M.find_link_at_col(line, col)

	if not uri then
		local anchor = line:match("<<([^>]+)>>")
		if anchor then
			return
		end
		local word = vim.fn.expand("<cfile>")
		if word and word ~= "" then
			uri = word
		else
			return
		end
	end

	if uri:match("^https?://") then
		if vim.ui.open then
			vim.ui.open(uri)
		else
			vim.fn.jobstart({ "xdg-open", uri }, { detach = true })
		end
		return
	end

	if uri:match("^id:") then
		local target_id = uri:sub(4)
		local root = DOM.get(0)
		local match = DOM.find_by_id(root, target_id)
		if match then
			vim.api.nvim_win_set_cursor(0, { match.range.start_line, 0 })
		else
			vim.notify("Org: Target ID not found: " .. target_id, vim.log.levels.WARN)
		end
		return
	end

	if uri:match("^#") then
		local custom_id = uri:sub(2)
		local root = DOM.get(0)
		local match = DOM.find_by_custom_id(root, custom_id) or DOM.find_by_id(root, custom_id)
		if match then
			vim.api.nvim_win_set_cursor(0, { match.range.start_line, 0 })
			return
		end

		if jump_to_anchor(0, custom_id) then
			return
		end

		local headlines = DOM.find_all_headlines(root)
		for _, hl in ipairs(headlines) do
			if hl.title:lower() == custom_id:lower() then
				vim.api.nvim_win_set_cursor(0, { hl.range.start_line, 0 })
				return
			end
		end

		vim.notify("Org: Target not found for link: " .. uri, vim.log.levels.WARN)
		return
	end

	if uri:match("^file:") then
		local path_part = uri:sub(6)
		local file_path, target = path_part:match("^(.-)::(.*)$")
		file_path = file_path or path_part
		file_path = vim.fn.expand(file_path)

		vim.cmd("edit " .. vim.fn.fnameescape(file_path))
		if target then
			local target_lnum = tonumber(target)
			if target_lnum then
				local total = vim.api.nvim_buf_line_count(0)
				vim.api.nvim_win_set_cursor(0, { math.min(math.max(1, target_lnum), total), 0 })
				return
			elseif target:match("^%*(.*)$") then
				local heading = target:match("^%*(.*)$")
				local root = DOM.get(0)
				local headlines = DOM.find_all_headlines(root)
				for _, hl in ipairs(headlines) do
					if hl.title == heading then
						vim.api.nvim_win_set_cursor(0, { hl.range.start_line, 0 })
						return
					end
				end
			else
				jump_to_anchor(0, target)
			end
		end
		return
	end

	if jump_to_anchor(0, uri) then
		return
	end

	local root = DOM.get(0)
	local headlines = DOM.find_all_headlines(root)
	for _, hl in ipairs(headlines) do
		if hl.title == uri then
			vim.api.nvim_win_set_cursor(0, { hl.range.start_line, 0 })
			return
		end
	end

	vim.notify("Org: Unable to resolve link: " .. uri, vim.log.levels.INFO)
end

return M
