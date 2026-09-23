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
	local line = vim.fn.getline(lnum)
	local is_headline = line:match("^(%*+)%s+")

	if not is_headline then
		local foldlevel = vim.fn.foldlevel(lnum)
		if foldlevel > 0 then
			vim.cmd("normal! za")
		end
		return
	end

	local foldclosed = vim.fn.foldclosed(lnum)
	if foldclosed ~= -1 then
		vim.cmd("normal! zo")
		local root = DOM.get(0)
		local node = DOM.find_headline_at_line(root, lnum)
		if node and #node.children > 0 then
			for _, child in ipairs(node.children) do
				local start = child.range.start_line
				if vim.fn.foldclosed(start) == -1 then
					vim.cmd(string.format("%d,%dfoldclose", start, child.range.end_line))
				end
			end
		end
		return
	end

	local root = DOM.get(0)
	local node = DOM.find_headline_at_line(root, lnum)
	if not node then
		vim.cmd("normal! za")
		return
	end

	local any_child_open = false
	for _, child in ipairs(node.children) do
		if vim.fn.foldclosed(child.range.start_line) == -1 then
			any_child_open = true
			break
		end
	end

	if any_child_open then
		vim.cmd("normal! zc")
	else
		vim.cmd("normal! zO")
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
		vim.b.org_global_fold_state = "overview"
	end)
end

return M
