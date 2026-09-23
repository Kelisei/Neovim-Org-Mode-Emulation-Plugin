local Execute = require("org.babel.execute")

local M = {}

--- Extract and write code blocks to disk according to their :tangle arguments.
--- @param bufnr number|nil
--- @return table<string, number>
function M.tangle(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local files = {}
	local current_block = nil

	for _, line in ipairs(lines) do
		local lang, b_args = line:match("^%s*#%+BEGIN_SRC%s+(%S+)%s*(.*)$")
		local b_end = line:match("^%s*#%+END_SRC")

		if lang then
			local args = Execute.parse_header_args(b_args or "")
			if args.tangle and args.tangle ~= "no" then
				current_block = {
					target = vim.fn.expand(args.tangle),
					lines = {},
				}
			end
		elseif b_end and current_block then
			if not files[current_block.target] then
				files[current_block.target] = {}
			end
			for _, cl in ipairs(current_block.lines) do
				table.insert(files[current_block.target], cl)
			end
			current_block = nil
		elseif current_block then
			table.insert(current_block.lines, line)
		end
	end

	local results = {}
	for target_path, content_lines in pairs(files) do
		local parent_dir = vim.fn.fnamemodify(target_path, ":h")
		if vim.fn.isdirectory(parent_dir) == 0 then
			vim.fn.mkdir(parent_dir, "p")
		end
		local f = io.open(target_path, "w")
		if f then
			f:write(table.concat(content_lines, "\n") .. "\n")
			f:close()
			results[target_path] = #content_lines
		end
	end

	return results
end

return M
