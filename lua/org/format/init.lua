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
	vim.api.nvim_set_hl(0, "OrgNote", { fg = "#6c7086", italic = true, default = true })
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

local ns_notes = vim.api.nvim_create_namespace("org_inline_notes")
local inline_notes_enabled_map = {}

--- Check if inline notes are enabled for a buffer.
--- @param bufnr number|nil
--- @return boolean
function M.is_inline_notes_enabled(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if inline_notes_enabled_map[bufnr] ~= nil then
		return inline_notes_enabled_map[bufnr]
	end
	local Config = require("org.config")
	return Config.options.org_inline_notes or false
end

--- Clear inline notes virtual text for buffer.
--- @param bufnr number|nil
function M.clear_inline_notes(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, ns_notes, 0, -1)
	end
end

--- Render inline notes as virtual text at end of headline lines.
--- @param bufnr number|nil
function M.render_inline_notes(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	M.clear_inline_notes(bufnr)

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local cur_hl_line = nil
	local in_logbook = false
	local hl_notes = {}

	local i = 1
	while i <= #lines do
		local line = lines[i]
		if line:match("^(%*+)%s+") then
			cur_hl_line = i
			in_logbook = false
		elseif cur_hl_line then
			if line:match("^%s*:LOGBOOK:%s*$") then
				in_logbook = true
			elseif line:match("^%s*:END:%s*$") and in_logbook then
				in_logbook = false
			elseif in_logbook then
				local is_note_header = line:match("^%s*%- Note taken on") or line:match("^%s*%- State%s+")
				if is_note_header then
					local note_text = ""
					local post_slash = line:match("\\\\%s*(.*)$")
					if post_slash and vim.trim(post_slash) ~= "" then
						note_text = vim.trim(post_slash)
					end

					local j = i + 1
					while j <= #lines do
						local next_l = lines[j]
						if next_l:match("^%s*:END:%s*$")
							or next_l:match("^%s*%- Note taken on")
							or next_l:match("^%s*%- State%s+")
							or next_l:match("^(%*+)%s+") then
							break
						end
						local trimmed = vim.trim(next_l)
						if trimmed ~= "" and trimmed ~= "\\\\" then
							trimmed = trimmed:gsub("^\\\\%s*", "")
							if note_text ~= "" then
								note_text = note_text .. " " .. trimmed
							else
								note_text = trimmed
							end
						end
						j = j + 1
					end

					if not hl_notes[cur_hl_line] then
						hl_notes[cur_hl_line] = { count = 0, first_text = note_text }
					end
					hl_notes[cur_hl_line].count = hl_notes[cur_hl_line].count + 1
				end
			end
		end
		i = i + 1
	end

	for hl_line, info in pairs(hl_notes) do
		if info.first_text and info.first_text ~= "" then
			local text = info.first_text
			if #text > 50 then
				text = text:sub(1, 47) .. "..."
			end
			local count_suffix = ""
			if info.count > 1 then
				count_suffix = string.format(" (+%d)", info.count - 1)
			end
			local label = string.format("  [Note: %s%s]", text, count_suffix)
			pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_notes, hl_line - 1, 0, {
				virt_text = { { label, "OrgNote" } },
				virt_text_pos = "eol",
			})
		end
	end
end

--- Toggle inline notes virtual text for buffer.
--- @param bufnr number|nil
--- @return boolean
function M.toggle_inline_notes(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local current = M.is_inline_notes_enabled(bufnr)
	local new_val = not current
	inline_notes_enabled_map[bufnr] = new_val
	if new_val then
		M.render_inline_notes(bufnr)
		vim.notify("Org: Inline notes enabled", vim.log.levels.INFO)
	else
		M.clear_inline_notes(bufnr)
		vim.notify("Org: Inline notes disabled", vim.log.levels.INFO)
	end
	return new_val
end

return M
