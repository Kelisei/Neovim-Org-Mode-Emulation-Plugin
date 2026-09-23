local M = {}

--- Check if a table line is a horizontal separator line.
--- @param line string
--- @return boolean
function M.is_separator(line)
	return line:match("^%s*|[%-%+]+|?%s*$") ~= nil and line:find("%-") ~= nil
end

--- Extract cell strings from a table row line.
--- @param line string
--- @return table
function M.parse_row_cells(line)
	local cells = {}
	local content = line:match("^%s*|(.*)|%s*$")
	if not content then
		return cells
	end

	for cell in string.gmatch(content .. "|", "([^|]*)|") do
		table.insert(cells, vim.trim(cell))
	end
	return cells
end

--- Calculate optimal column widths across table rows.
--- @param raw_lines table<number, string>
--- @return table<number, number>
function M.calculate_column_widths(raw_lines)
	local widths = {}
	for _, l in ipairs(raw_lines) do
		if not M.is_separator(l) then
			local cells = M.parse_row_cells(l)
			for col_idx, cell in ipairs(cells) do
				local w = vim.fn.strdisplaywidth(cell)
				widths[col_idx] = math.max(widths[col_idx] or 0, w)
			end
		end
	end
	return widths
end

--- Format a single table row according to calculated column widths.
--- @param cells table<number, string>
--- @param widths table<number, number>
--- @return string
local function format_data_row(cells, widths)
	local parts = {}
	for i = 1, #widths do
		local cell = cells[i] or ""
		local w = widths[i]
		local cell_w = vim.fn.strdisplaywidth(cell)
		local is_number = tonumber(cell) ~= nil
		local pad = string.rep(" ", math.max(0, w - cell_w))
		if is_number then
			table.insert(parts, " " .. pad .. cell .. " ")
		else
			table.insert(parts, " " .. cell .. pad .. " ")
		end
	end
	return "|" .. table.concat(parts, "|") .. "|"
end

--- Format horizontal separator line according to calculated column widths.
--- @param widths table<number, number>
--- @return string
local function format_separator_row(widths)
	local parts = {}
	for i = 1, #widths do
		table.insert(parts, string.rep("-", widths[i] + 2))
	end
	return "|" .. table.concat(parts, "+") .. "|"
end

--- Re-align and format table lines with consistent column widths.
--- @param raw_lines table<number, string>
--- @return table<number, string>, table<number, number>
function M.align_table(raw_lines)
	local widths = M.calculate_column_widths(raw_lines)
	local aligned = {}

	for _, l in ipairs(raw_lines) do
		if M.is_separator(l) then
			table.insert(aligned, format_separator_row(widths))
		else
			local cells = M.parse_row_cells(l)
			table.insert(aligned, format_data_row(cells, widths))
		end
	end

	return aligned, widths
end

return M
