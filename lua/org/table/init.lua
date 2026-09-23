local Align = require("org.table.align")
local Formula = require("org.table.formula")

local M = {}

--- Locate table bounds surrounding the given line number.
--- @param bufnr number
--- @param lnum number
--- @return number|nil, number|nil, string|nil, number|nil
function M.find_table_bounds(bufnr, lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local total = #lines
	if lnum < 1 or lnum > total then
		return nil, nil, nil, nil
	end

	if not lines[lnum]:match("^%s*|") and not lines[lnum]:match("^%s*#%+TBLFM:") then
		return nil, nil, nil, nil
	end

	local start_line = lnum
	while start_line > 1 and lines[start_line - 1]:match("^%s*|") do
		start_line = start_line - 1
	end

	local end_line = lnum
	while end_line < total and lines[end_line + 1]:match("^%s*|") do
		end_line = end_line + 1
	end

	local tblfm_line = nil
	local tblfm_lnum = nil
	if end_line < total and lines[end_line + 1]:match("^%s*#%+TBLFM:%s*(.*)$") then
		tblfm_line = lines[end_line + 1]:match("^%s*#%+TBLFM:%s*(.*)$")
		tblfm_lnum = end_line + 1
	end

	return start_line, end_line, tblfm_line, tblfm_lnum
end

--- Re-align table under cursor.
--- @param bufnr number|nil
--- @param lnum number|nil
function M.align(bufnr, lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	lnum = lnum or vim.fn.line(".")

	local s, e, _, _ = M.find_table_bounds(bufnr, lnum)
	if not s or not e then
		return
	end

	local raw_lines = vim.api.nvim_buf_get_lines(bufnr, s - 1, e, false)
	local aligned, _ = Align.align_table(raw_lines)
	vim.api.nvim_buf_set_lines(bufnr, s - 1, e, false, aligned)
end

--- Recalculate formulas for table under cursor and format.
--- @param bufnr number|nil
--- @param lnum number|nil
function M.recalculate(bufnr, lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	lnum = lnum or vim.fn.line(".")

	local s, e, tblfm, _ = M.find_table_bounds(bufnr, lnum)
	if not s or not e then
		return
	end

	local raw_lines = vim.api.nvim_buf_get_lines(bufnr, s - 1, e, false)
	if tblfm and tblfm ~= "" then
		local evaluated = Formula.evaluate_tblfm(raw_lines, tblfm)
		vim.api.nvim_buf_set_lines(bufnr, s - 1, e, false, evaluated)
	else
		local aligned, _ = Align.align_table(raw_lines)
		vim.api.nvim_buf_set_lines(bufnr, s - 1, e, false, aligned)
	end
end

--- Move cursor to next cell in table, expanding or creating row if necessary.
function M.next_cell()
	local bufnr = vim.api.nvim_get_current_buf()
	local lnum = vim.fn.line(".")
	local s, e, _, _ = M.find_table_bounds(bufnr, lnum)
	if not s or not e then
		return
	end

	M.recalculate(bufnr, lnum)
	local line = vim.api.nvim_get_current_line()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local col = cursor[2] + 1
	local next_pipe = line:find("|", col + 1)

	if next_pipe and next_pipe < #line then
		vim.api.nvim_win_set_cursor(0, { lnum, next_pipe + 1 })
	else
		if lnum < e then
			local next_line = vim.fn.getline(lnum + 1)
			local first_pipe = next_line:find("|")
			if first_pipe then
				vim.api.nvim_win_set_cursor(0, { lnum + 1, first_pipe + 1 })
			end
		end
	end
end

M.align_table = Align.align_table
M.evaluate_tblfm = Formula.evaluate_tblfm

return M
