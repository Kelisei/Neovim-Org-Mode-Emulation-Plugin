local Execute = require("org.babel.execute")
local Tangle = require("org.babel.tangle")

local M = {}

--- Locate the source code block surrounding the current cursor line.
--- @param bufnr number
--- @param lnum number
--- @return number|nil, number|nil, string|nil, table|nil, table<number, string>|nil
local function find_src_block(bufnr, lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local total = #lines
	local start_line = nil
	local end_line = nil
	local lang = nil
	local header_args = nil

	for i = lnum, 1, -1 do
		local l = lines[i]
		local b_lang, b_args = l:match("^%s*#%+BEGIN_SRC%s+(%S+)%s*(.*)$")
		if b_lang then
			start_line = i
			lang = b_lang
			header_args = Execute.parse_header_args(b_args or "")
			break
		end
		if l:match("^%s*#%+END_SRC") and i ~= lnum then
			return nil, nil, nil, nil, nil
		end
	end

	if not start_line then
		return nil, nil, nil, nil, nil
	end

	for i = start_line + 1, total do
		if lines[i]:match("^%s*#%+END_SRC") then
			end_line = i
			break
		end
	end

	if not end_line then
		return nil, nil, nil, nil, nil
	end

	local code_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line - 1, false)
	return start_line, end_line, lang, header_args, code_lines
end

--- Execute the source block under cursor and write #+RESULTS: into the buffer.
--- @param bufnr number|nil
--- @param lnum number|nil
function M.execute_at_point(bufnr, lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	lnum = lnum or vim.fn.line(".")

	local s, e, lang, header_args, code_lines = find_src_block(bufnr, lnum)
	if not s or not e then
		vim.notify("Org: Cursor is not inside a #+BEGIN_SRC block", vim.log.levels.WARN)
		return
	end

	local ok, out_lines = Execute.run(lang, code_lines, header_args)
	if not ok then
		vim.notify("Org Babel Error:\n" .. table.concat(out_lines, "\n"), vim.log.levels.ERROR)
		return
	end

	if header_args.results == "silent" then
		vim.notify("Org: Block executed silently", vim.log.levels.INFO)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local results_start = nil
	local results_end = nil

	local i = e + 1
	while i <= #lines and lines[i]:match("^%s*$") do
		i = i + 1
	end

	if i <= #lines and lines[i]:match("^%s*#%+RESULTS:") then
		results_start = i
		local j = i + 1
		while j <= #lines do
			local cur = lines[j]
			if cur:match("^%s*:") or cur:match("^%s*|") then
				j = j + 1
			else
				break
			end
		end
		results_end = j - 1
	end

	local new_results = { "#+RESULTS:" }
	for _, ol in ipairs(out_lines) do
		table.insert(new_results, ol)
	end

	if results_start and results_end then
		vim.api.nvim_buf_set_lines(bufnr, results_start - 1, results_end, false, new_results)
	else
		table.insert(new_results, 1, "")
		vim.api.nvim_buf_set_lines(bufnr, e, e, false, new_results)
	end

	vim.notify("Org: Block executed successfully", vim.log.levels.INFO)
end

--- Extract and tangle code blocks to source files.
--- @param bufnr number|nil
function M.tangle_file(bufnr)
	local res = Tangle.tangle(bufnr)
	local count = 0
	local msg = {}
	for file, lines_count in pairs(res) do
		count = count + 1
		table.insert(msg, string.format("%s (%d lines)", file, lines_count))
	end
	if count > 0 then
		vim.notify("Org Tangled:\n" .. table.concat(msg, "\n"), vim.log.levels.INFO)
	else
		vim.notify("Org: No tangle targets found", vim.log.levels.INFO)
	end
end

M.run = Execute.run
M.tangle = Tangle.tangle

return M
