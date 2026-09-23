local Config = require("org.config")

local M = {}

M.SECTIONS = {
	{
		title = "GLOBAL & AGENDA",
		items = {
			{ cmd = ":OrgAgenda", action = "org_agenda", scope = "global", desc = "Open interactive agenda view" },
			{ cmd = ":OrgCapture", action = "org_capture", scope = "global", desc = "Capture note with context and visual selection" },
			{ cmd = ":OrgOpenNotes", action = "org_open_notes", scope = "global", desc = "Open default notes file (refile.org)" },
			{ cmd = ":OrgNotes", action = "org_notes", scope = "global", desc = "Open captured notes interactive viewer" },
			{ cmd = ":OrgShowCheatsheet", action = "org_show_cheatsheet", scope = "global", desc = "Show this commands and keybindings cheatsheet" },
		},
	},
	{
		title = "OUTLINE & FOLDING",
		items = {
			{ cmd = ":OrgCycle", action = "org_cycle", scope = "org", desc = "Cycle fold of current subtree" },
			{ cmd = ":OrgGlobalCycle", action = "org_global_cycle", scope = "org", desc = "Cycle buffer folds (overview/contents/all)" },
		},
	},
	{
		title = "TODO & PRIORITIES",
		items = {
			{ cmd = ":OrgTodo", action = "org_todo", scope = "org", desc = "Cycle TODO state forward" },
			{ cmd = ":OrgTodoPrev", action = "org_todo_prev", scope = "org", desc = "Cycle TODO state backward" },
			{ cmd = ":OrgTodoPrompt", action = "org_todo_prompt", scope = "org", desc = "Interactive fast TODO state picker" },
			{ cmd = ":OrgPriority", action = "org_priority", scope = "org", desc = "Cycle priority level forward" },
			{ cmd = ":OrgPriorityPrompt", action = "org_priority_prompt", scope = "org", desc = "Interactive priority picker" },
		},
	},
	{
		title = "NAVIGATION & LINKS",
		items = {
			{ cmd = ":OrgOpenAtPoint", action = "org_open_at_point", scope = "org", desc = "Follow link under cursor / eval formula" },
			{ cmd = ":OrgBack", action = "org_link_back", scope = "org", desc = "Return to previous location in jump stack" },
			{ cmd = ":OrgToggleCheckbox", action = "org_toggle_checkbox", scope = "org", desc = "Toggle checkbox status / eval formula" },
		},
	},
	{
		title = "DATES, TIMESTAMPS & CLOCKING",
		items = {
			{ cmd = ":OrgSchedule", action = "org_schedule", scope = "org", desc = "Set or update scheduled timestamp" },
			{ cmd = ":OrgDeadline", action = "org_deadline", scope = "org", desc = "Set or update deadline timestamp" },
			{ cmd = ":OrgClockIn", action = "org_clock_in", scope = "org", desc = "Clock in on current headline" },
			{ cmd = ":OrgClockOut", action = "org_clock_out", scope = "org", desc = "Clock out and record duration in LOGBOOK" },
		},
	},
	{
		title = "TABLES & FORMULAS",
		items = {
			{ cmd = ":OrgTableAlign", action = "org_table_align", scope = "org", desc = "Align table columns and jump to next cell" },
			{ cmd = ":OrgTableEval", action = "org_table_eval_formula", scope = "org", desc = "Recalculate table formula (#+TBLFM:)" },
		},
	},
	{
		title = "BABEL (SOURCE CODE & TANGLE)",
		items = {
			{ cmd = ":OrgExecute", action = "org_babel_execute", scope = "org", desc = "Execute source block and capture results" },
			{ cmd = ":OrgTangle", action = "org_babel_tangle", scope = "org", desc = "Tangle source blocks to output files" },
		},
	},
	{
		title = "NOTES & LOGBOOK",
		items = {
			{ cmd = ":OrgAddNote", action = "org_add_note", scope = "org", desc = "Add timestamped note to headline LOGBOOK" },
			{ cmd = ":OrgToggleInlineNotes", action = "org_toggle_inline_notes", scope = "org", desc = "Toggle inline virtual text notes at EOL" },
		},
	},
}

--- Resolve active keybinding representation for given scope and action.
--- @param scope string
--- @param action string
--- @return string
function M.resolve_binding(scope, action)
	local mappings = Config.options.mappings or {}
	local group = mappings[scope] or {}
	local key = group[action]
	if key == false or key == nil or key == "" then
		return "[unmapped]"
	end
	return tostring(key)
end

--- Generate formatted lines for cheatsheet view.
--- @return table<number, string>
function M.generate_cheatsheet_lines()
	local lines = {}
	table.insert(lines, "")
	table.insert(lines, "  ORG MODE CHEATSHEET & KEYMAPS")
	table.insert(lines, "  ================================================================================")

	for _, section in ipairs(M.SECTIONS) do
		table.insert(lines, "")
		table.insert(lines, "  " .. section.title)
		table.insert(lines, "  " .. string.rep("-", 76))
		for _, item in ipairs(section.items) do
			local binding = M.resolve_binding(item.scope, item.action)
			local line = string.format("  %-25s %-16s %s", item.cmd, binding, item.desc)
			table.insert(lines, line)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "  ================================================================================")
	table.insert(lines, "  Press 'q' or '<Esc>' to close this cheatsheet.")
	table.insert(lines, "")
	return lines
end

--- Apply syntax highlights to cheatsheet buffer.
--- @param bufnr number
local function apply_syntax(bufnr)
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd([=[
			syntax match OrgSheetTitle "^\s*ORG MODE CHEATSHEET & KEYMAPS"
			syntax match OrgSheetSection "^\s*[A-Z_ /(),&-]\+$"
			syntax match OrgSheetSeparator "^\s*[=-]\{5,\}$"
			syntax match OrgSheetCmd "^\s*:[A-Za-z0-9_]\+"
			syntax match OrgSheetKey "\s\+\(<[^>]\+>\|\S\+\)\s\+"
			syntax match OrgSheetUnmapped "\[unmapped\]"
			syntax match OrgSheetFooter "^\s*Press 'q' or '<Esc>' to close this cheatsheet\."

			highlight default link OrgSheetTitle Title
			highlight default link OrgSheetSection Identifier
			highlight default link OrgSheetSeparator Comment
			highlight default link OrgSheetCmd Function
			highlight default link OrgSheetKey Special
			highlight default link OrgSheetUnmapped Comment
			highlight default link OrgSheetFooter Comment
		]=])
	end)
end

--- Open interactive cheatsheet in centered floating window.
function M.show_cheatsheet()
	local lines = M.generate_cheatsheet_lines()
	local buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = "orgcheatsheet"

	local width = math.min(84, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 4)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Org Mode Cheatsheet ",
		title_pos = "center",
	})

	apply_syntax(buf)

	local close_fn = function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	vim.keymap.set("n", "q", close_fn, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "<Esc>", close_fn, { buffer = buf, silent = true, nowait = true })
end

return M
