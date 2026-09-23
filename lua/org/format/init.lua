local M = {}

--- Setup syntax highlights and matches for Org Mode buffers.
function M.setup_syntax()
	vim.api.nvim_set_hl(0, "OrgHeadlineLevel1", { fg = "#89b4fa", bold = true, default = true })
	vim.api.nvim_set_hl(0, "OrgHeadlineLevel2", { fg = "#a6e3a1", bold = true, default = true })
	vim.api.nvim_set_hl(0, "OrgHeadlineLevel3", { fg = "#f9e2af", bold = true, default = true })
	vim.api.nvim_set_hl(0, "OrgHeadlineLevel4", { fg = "#fab387", bold = true, default = true })
	vim.api.nvim_set_hl(0, "OrgTodo", { fg = "#f38ba8", bold = true, default = true })
	vim.api.nvim_set_hl(0, "OrgNext", { fg = "#fab387", bold = true, default = true })
	vim.api.nvim_set_hl(0, "OrgDone", { fg = "#a6e3a1", bold = true, default = true })
	vim.api.nvim_set_hl(0, "OrgTag", { fg = "#94e2d5", italic = true, default = true })
	vim.api.nvim_set_hl(0, "OrgPriority", { fg = "#eba0ac", bold = true, default = true })
	vim.api.nvim_set_hl(0, "OrgDate", { fg = "#cba6f7", underline = true, default = true })
	vim.api.nvim_set_hl(0, "OrgDrawer", { fg = "#6c7086", default = true })
	vim.api.nvim_set_hl(0, "OrgTable", { fg = "#89dceb", default = true })
	vim.api.nvim_set_hl(0, "OrgBold", { bold = true, default = true })
	vim.api.nvim_set_hl(0, "OrgItalic", { italic = true, default = true })
	vim.api.nvim_set_hl(0, "OrgUnderline", { underline = true, default = true })
	vim.api.nvim_set_hl(0, "OrgStrike", { strikethrough = true, default = true })
	vim.api.nvim_set_hl(0, "OrgCode", { fg = "#f5c2e7", default = true })
	vim.api.nvim_set_hl(0, "OrgVerbatim", { fg = "#f5c2e7", default = true })
end

--- Apply syntax match rules for active Org buffer.
--- @param bufnr number
function M.apply_buffer_syntax(bufnr)
	vim.api.nvim_buf_call(bufnr, function()
		M.setup_syntax()

		vim.cmd([=[
			syntax match OrgHeadlineLevel1 "^\*\s\+.*$" contains=OrgTodo,OrgDone,OrgPriority,OrgTag
			syntax match OrgHeadlineLevel2 "^\*\*\{1\}\s\+.*$" contains=OrgTodo,OrgDone,OrgPriority,OrgTag
			syntax match OrgHeadlineLevel3 "^\*\*\{2\}\s\+.*$" contains=OrgTodo,OrgDone,OrgPriority,OrgTag
			syntax match OrgHeadlineLevel4 "^\*\*\{3,\}\s\+.*$" contains=OrgTodo,OrgDone,OrgPriority,OrgTag
			syntax match OrgTodo "\<TODO\>" contained
			syntax match OrgNext "\<NEXT\>" contained
			syntax match OrgDone "\<DONE\>\|\<CANCELED\>" contained
			syntax match OrgPriority "\[#[A-Z]\]" contained
			syntax match OrgTag ":[a-zA-Z0-9_@#%:]\+:\s*$" contained
			syntax match OrgDate "<[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}[^>]*>"
			syntax match OrgDate "\[[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}[^\]]*\]"
			syntax match OrgDrawer "^\s*:[A-Z_]\+:\s*$"
			syntax match OrgDrawer "^\s*:END:\s*$"
			syntax match OrgTable "^\s*|.*|$"
			syntax match OrgBold "\*[^*\t\n\r ]\+[^*]*\*"
			syntax match OrgItalic "/[^/\t\n\r ]\+[^/]*\/"
			syntax match OrgUnderline "_[^_\t\n\r ]\+[^_]*_"
			syntax match OrgStrike "+[^\+\t\n\r ]\+[^\+]*+"
			syntax match OrgCode "\~[^~\t\n\r ]\+[^~]*\~"
			syntax match OrgVerbatim "=[^=\t\n\r ]\+[^=]*="
		]=])
	end)
end

--- Jump between footnote reference and definition.
function M.jump_footnote()
	local line = vim.api.nvim_get_current_line()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local lnum = cursor[1]
	local col = cursor[2] + 1

	local fn_label = line:match("%[fn:([^%]:%s]+)%]")
	if not fn_label then
		fn_label = line:match("^%[fn:([^%]:%s]+)%]")
	end
	if not fn_label then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local is_def = line:match("^%[fn:" .. vim.pesc(fn_label) .. "%]") ~= nil

	if is_def then
		for i, l in ipairs(lines) do
			if i ~= lnum and l:find("%[fn:" .. vim.pesc(fn_label) .. "%]") then
				vim.api.nvim_win_set_cursor(0, { i, 0 })
				return
			end
		end
	else
		for i, l in ipairs(lines) do
			if i ~= lnum and l:match("^%[fn:" .. vim.pesc(fn_label) .. "%]") then
				vim.api.nvim_win_set_cursor(0, { i, 0 })
				return
			end
		end
	end
end

return M
