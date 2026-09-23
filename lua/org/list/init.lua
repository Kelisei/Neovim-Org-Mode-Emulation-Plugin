local M = {}

--- Check if line contains a checkbox item.
--- @param line string
--- @return string|nil, string|nil, string|nil
local function parse_checkbox_line(line)
	local prefix, state, suffix = line:match("^(%s*[-+*]%s+)%[([ X%-])%](.*)$")
	if prefix then
		return prefix, state, suffix
	end
	prefix, state, suffix = line:match("^(%s*%d+[%.)]%s+)%[([ X%-])%](.*)$")
	if prefix then
		return prefix, state, suffix
	end
	return nil, nil, nil
end

--- Calculate checkbox statistics within a range of lines.
--- @param bufnr number
--- @param start_line number
--- @param end_line number
--- @return number, number
local function count_checkboxes_in_range(bufnr, start_line, end_line)
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
	local total = 0
	local checked = 0
	for _, l in ipairs(lines) do
		local _, st, _ = parse_checkbox_line(l)
		if st then
			total = total + 1
			if st == "X" then
				checked = checked + 1
			end
		end
	end
	return checked, total
end

--- Update cookie statistics on heading or parent list item.
--- @param bufnr number
--- @param lnum number
--- @param checked number
--- @param total number
local function update_cookies_on_line(bufnr, lnum, checked, total)
	local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
	if not line then
		return
	end

	local updated = line
	if line:find("%[%d*/%d*%]") then
		updated = updated:gsub("%[%d*/%d*%]", string.format("[%d/%d]", checked, total))
	end
	if line:find("%[%d*%%%]") then
		local pct = total > 0 and math.floor((checked / total) * 100) or 0
		updated = updated:gsub("%[%d*%%%]", string.format("[%d%%%%]", pct))
	end

	if updated ~= line then
		vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { updated })
	end
end

--- Recalculate and update all statistics cookies for the current subtree or list.
--- @param bufnr number
--- @param lnum number
function M.update_statistics(bufnr, lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	lnum = lnum or vim.fn.line(".")

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local heading_lnum = nil
	for i = lnum, 1, -1 do
		if lines[i]:match("^(%*+)%s+") then
			heading_lnum = i
			break
		end
	end

	if not heading_lnum then
		return
	end

	local heading_level = #(lines[heading_lnum]:match("^(%*+)%s+"))
	local end_lnum = #lines
	for i = heading_lnum + 1, #lines do
		local child_stars = lines[i]:match("^(%*+)%s+")
		if child_stars and #child_stars <= heading_level then
			end_lnum = i - 1
			break
		end
	end

	local checked, total = count_checkboxes_in_range(bufnr, heading_lnum + 1, end_lnum)
	update_cookies_on_line(bufnr, heading_lnum, checked, total)

	for i = heading_lnum + 1, end_lnum do
		if lines[i]:find("%[%d*/%d*%]") or lines[i]:find("%[%d*%%%]") then
			local indent = #(lines[i]:match("^(%s*)") or "")
			local sub_end = end_lnum
			for j = i + 1, end_lnum do
				local sub_indent = #(lines[j]:match("^(%s*)") or "")
				if lines[j]:match("%S") and sub_indent <= indent then
					sub_end = j - 1
					break
				end
			end
			local sub_checked, sub_total = count_checkboxes_in_range(bufnr, i + 1, sub_end)
			update_cookies_on_line(bufnr, i, sub_checked, sub_total)
		end
	end
end

--- Toggle checkbox on current line and refresh cookie statistics.
function M.toggle_checkbox()
	local bufnr = vim.api.nvim_get_current_buf()
	local lnum = vim.fn.line(".")
	local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
	if not line then
		return
	end

	local prefix, state, suffix = parse_checkbox_line(line)
	if not prefix then
		return
	end

	local new_state = (state == "X") and " " or "X"
	local new_line = prefix .. "[" .. new_state .. "]" .. suffix
	vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { new_line })
	M.update_statistics(bufnr, lnum)
end

return M
