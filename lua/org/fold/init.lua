local DOM = require("org.dom")

local M = {}

--- Calculate fold level for a given buffer line.
--- @param lnum number
--- @return string|number
function M.foldexpr(lnum)
	local line = vim.fn.getline(lnum)
	local stars = line:match("^(%*+)%s+")
	if stars then
		return ">" .. #stars
	end
	return "="
end

--- Cycle folding state of the subtree under cursor (FOLDED -> CHILDREN -> SUBTREE).
function M.cycle()
	local lnum = vim.fn.line(".")
	local root = DOM.get(0)
	local node = DOM.find_headline_at_line(root, lnum)

	if not node then
		vim.cmd("silent! normal! za")
		return
	end

	local start_lnum = node.range.start_line
	local end_lnum = node.range.end_line

	if vim.fn.foldclosed(start_lnum) ~= -1 then
		vim.cmd("normal! zo")
		return
	end

	local any_closed = false
	for l = start_lnum + 1, end_lnum do
		if vim.fn.foldclosed(l) ~= -1 then
			any_closed = true
			break
		end
	end

	if any_closed then
		vim.cmd(string.format("silent! %d,%dfoldopen!", start_lnum, end_lnum))
	else
		vim.cmd("normal! zc")
	end
end

--- Cycle global buffer folding (OVERVIEW -> CONTENTS -> SHOW ALL).
function M.global_cycle()
	local current_view = vim.b.org_global_fold_state or "overview"

	if current_view == "overview" then
		vim.cmd("setlocal foldlevel=1")
		vim.b.org_global_fold_state = "contents"
	elseif current_view == "contents" then
		vim.cmd("normal! zR")
		vim.b.org_global_fold_state = "all"
	else
		vim.cmd("normal! zM")
		vim.cmd("setlocal foldlevel=0")
		vim.b.org_global_fold_state = "overview"
	end
end

--- Setup folding for current org buffer.
--- @param bufnr number
function M.attach(bufnr)
	vim.api.nvim_buf_call(bufnr, function()
		vim.opt_local.foldmethod = "expr"
		vim.opt_local.foldexpr = "v:lua.require'org.fold'.foldexpr(v:lnum)"
		vim.opt_local.foldenable = true
		vim.opt_local.foldopen = "search,quickfix"
		vim.b.org_global_fold_state = "overview"
	end)
end

return M
