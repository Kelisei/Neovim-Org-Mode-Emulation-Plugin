local Config = require("org.config")
local Parser = require("org.dom.parser")
local Query = require("org.dom.query")
local Timestamp = require("org.date.timestamp")

local M = {}

--- Expand configured agenda file patterns into absolute file paths.
--- @return table<number, string>
function M.get_agenda_files()
	local files = {}
	for _, pattern in ipairs(Config.options.org_agenda_files) do
		local expanded = vim.fn.expand(pattern)
		local matches = vim.fn.glob(expanded, false, true)
		for _, m in ipairs(matches) do
			if m:match("%.org$") and vim.fn.filereadable(m) == 1 then
				table.insert(files, m)
			end
		end
	end
	return files
end

--- Scan files and collect all planned tasks matching target date string.
--- @param target_date_str string|nil
--- @return table
function M.collect_agenda_items(target_date_str)
	local files = M.get_agenda_files()
	local items = {}
	local target_date = target_date_str or os.date("%Y-%m-%d")

	for _, file in ipairs(files) do
		local f = io.open(file, "r")
		if f then
			local content = f:read("*a")
			f:close()
			local lines = vim.split(content, "\n")
			local root = Parser.parse(lines, Config.options.org_todo_keywords)
			local headlines = Query.find_all_headlines(root)

			for _, hl in ipairs(headlines) do
				local matched = false
				local plan_type = nil
				local plan_ts = nil

				if hl.planning.scheduled then
					local ts = Timestamp.parse(hl.planning.scheduled)
					if ts then
						local ds = string.format("%04d-%02d-%02d", ts.year, ts.month, ts.day)
						if ds <= target_date then
							matched = true
							plan_type = "Scheduled"
							plan_ts = hl.planning.scheduled
						end
					end
				end

				if not matched and hl.planning.deadline then
					local ts = Timestamp.parse(hl.planning.deadline)
					if ts then
						local ds = string.format("%04d-%02d-%02d", ts.year, ts.month, ts.day)
						if ds <= target_date then
							matched = true
							plan_type = "Deadline"
							plan_ts = hl.planning.deadline
						end
					end
				end

				if matched then
					table.insert(items, {
						file = file,
						line = hl.range.start_line,
						title = hl.title,
						todo = hl.todo or "",
						priority = hl.priority,
						plan_type = plan_type,
						plan_ts = plan_ts,
					})
				end
			end
		end
	end

	return items
end

--- Render and display the interactive Agenda window.
function M.open_agenda()
	local today = os.date("%Y-%m-%d")
	local day_name = os.date("%A")
	local items = M.collect_agenda_items(today)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "orgagenda"

	local lines = {
		string.format("  AGENDA: %s (%s)", today, day_name),
		"  " .. string.rep("=", 60),
		"",
	}

	local line_to_item = {}

	if #items == 0 then
		table.insert(lines, "  No scheduled tasks or deadlines for today.")
	else
		for _, it in ipairs(items) do
			local fname = vim.fn.fnamemodify(it.file, ":t")
			local prio_str = it.priority and string.format("[#%s] ", it.priority) or ""
			local display_line = string.format("  %-14s %-8s %s%-30s %s: %s", fname .. ":", it.todo, prio_str, it.title, it.plan_type, it.plan_ts)
			table.insert(lines, display_line)
			line_to_item[#lines] = it
		end
	end

	local note_items = M.collect_notes_items()
	if #note_items > 0 then
		table.insert(lines, "")
		table.insert(lines, "  RECENT NOTES / REFILE:")
		table.insert(lines, "  " .. string.rep("-", 40))
		for _, ni in ipairs(note_items) do
			local todo_str = ni.todo ~= "" and string.format("%-8s ", ni.todo) or ""
			local display_line
			if ni.snippet ~= "" then
				display_line = string.format("  * %s%-30s  %s", todo_str, ni.title, ni.snippet)
			else
				display_line = string.format("  * %s%s", todo_str, ni.title)
			end
			table.insert(lines, display_line)
			line_to_item[#lines] = ni
		end
	end

	table.insert(lines, "")
	table.insert(lines, "  [Enter] Jump to item   [q] Close agenda")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	vim.cmd("botright split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_win_set_height(win, math.min(18, math.max(6, #lines + 1)))

	local function jump()
		local cur = vim.api.nvim_win_get_cursor(0)
		local item = line_to_item[cur[1]]
		if item then
			vim.cmd("edit " .. vim.fn.fnameescape(item.file))
			vim.api.nvim_win_set_cursor(0, { item.line, 0 })
		end
	end

	vim.keymap.set("n", "<CR>", jump, { buffer = buf, silent = true })
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, silent = true })
end

--- Scan default notes file and collect captured note entries.
--- @return table<number, table>
function M.collect_notes_items()
	local notes_file = vim.fn.expand(Config.options.org_default_notes_file)
	local items = {}
	if vim.fn.filereadable(notes_file) == 0 then
		return items
	end

	local f = io.open(notes_file, "r")
	if not f then
		return items
	end
	local content = f:read("*a")
	f:close()

	local lines = vim.split(content, "\n")
	local root = Parser.parse(lines, Config.options.org_todo_keywords)
	local headlines = Query.find_all_headlines(root)

	for _, hl in ipairs(headlines) do
		local snippet = ""
		for idx = hl.range.start_line + 1, math.min(#lines, hl.range.end_line) do
			local cl = vim.trim(lines[idx])
			if cl ~= "" and not cl:match("^:PROPERTIES:") and not cl:match("^:END:") then
				snippet = cl
				break
			end
		end

		table.insert(items, {
			file = notes_file,
			line = hl.range.start_line,
			title = hl.title,
			todo = hl.todo or "",
			snippet = snippet,
		})
	end

	return items
end

--- Open the default notes file directly in a buffer.
function M.open_notes_file()
	local notes_file = vim.fn.expand(Config.options.org_default_notes_file)
	local parent_dir = vim.fn.fnamemodify(notes_file, ":h")
	if vim.fn.isdirectory(parent_dir) == 0 then
		vim.fn.mkdir(parent_dir, "p")
	end
	if vim.fn.filereadable(notes_file) == 0 then
		local f = io.open(notes_file, "w")
		if f then
			f:write("#+TITLE: Refile & Quick Notes\n\n")
			f:close()
		end
	end
	vim.cmd("edit " .. vim.fn.fnameescape(notes_file))
end

--- Render and display an interactive notes viewer window.
function M.open_notes_view()
	local items = M.collect_notes_items()
	local notes_file = vim.fn.expand(Config.options.org_default_notes_file)
	local fname = vim.fn.fnamemodify(notes_file, ":t")

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "orgnotes"

	local lines = {
		string.format("  CAPTURED NOTES (%s)", fname),
		"  " .. string.rep("=", 60),
		"",
	}

	local line_to_item = {}

	if #items == 0 then
		table.insert(lines, "  No captured notes found in " .. fname .. ".")
		table.insert(lines, "  Use :OrgCapture (<leader>oc) to add quick notes.")
	else
		for _, it in ipairs(items) do
			local todo_str = it.todo ~= "" and string.format("%-8s ", it.todo) or ""
			local display_line
			if it.snippet ~= "" then
				display_line = string.format("  * %s%-30s  %s", todo_str, it.title, it.snippet)
			else
				display_line = string.format("  * %s%s", todo_str, it.title)
			end
			table.insert(lines, display_line)
			line_to_item[#lines] = it
		end
	end

	table.insert(lines, "")
	table.insert(lines, "  [Enter] Jump to note   [e] Edit notes file   [q] Close window")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	vim.cmd("botright split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_win_set_height(win, math.min(18, math.max(6, #lines + 1)))

	local function jump()
		local cur = vim.api.nvim_win_get_cursor(0)
		local item = line_to_item[cur[1]]
		if item then
			vim.cmd("edit " .. vim.fn.fnameescape(item.file))
			vim.api.nvim_win_set_cursor(0, { item.line, 0 })
		end
	end

	vim.keymap.set("n", "<CR>", jump, { buffer = buf, silent = true })
	vim.keymap.set("n", "e", M.open_notes_file, { buffer = buf, silent = true })
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, silent = true })
end

--- Prompt for a quick note and append to the default notes file with context link.
--- @param visual_text string|nil
function M.capture(visual_text)
	local origin_buf = vim.api.nvim_get_current_buf()
	local origin_path = vim.api.nvim_buf_get_name(origin_buf)
	local origin_line = vim.fn.line(".")
	local origin_filename = vim.fn.fnamemodify(origin_path, ":t")

	local context_link = nil
	if origin_path and origin_path ~= "" and vim.fn.filereadable(origin_path) == 1 then
		context_link = string.format("[[file:%s::%d][%s::%d]]", origin_path, origin_line, origin_filename, origin_line)
	end

	local notes_file = vim.fn.expand(Config.options.org_default_notes_file)
	local parent_dir = vim.fn.fnamemodify(notes_file, ":h")
	if vim.fn.isdirectory(parent_dir) == 0 then
		vim.fn.mkdir(parent_dir, "p")
	end

	vim.ui.input({ prompt = "Org Capture Note: " }, function(input)
		if input and vim.trim(input) ~= "" then
			local ts = os.date("[%Y-%m-%d %a %H:%M]")
			local entry_parts = {
				string.format("\n* %s", input),
				string.format("  %s", ts),
			}
			if context_link then
				table.insert(entry_parts, string.format("  %s", context_link))
			end
			if visual_text and vim.trim(visual_text) ~= "" then
				table.insert(entry_parts, "  #+BEGIN_QUOTE")
				for _, vl in ipairs(vim.split(vim.trim(visual_text), "\n")) do
					table.insert(entry_parts, "  " .. vl)
				end
				table.insert(entry_parts, "  #+END_QUOTE")
			end
			table.insert(entry_parts, "")

			local entry = table.concat(entry_parts, "\n")
			local f = io.open(notes_file, "a")
			if f then
				f:write(entry)
				f:close()
				vim.notify("Org: Note captured to " .. notes_file, vim.log.levels.INFO)
			end
		end
	end)
end

return M
