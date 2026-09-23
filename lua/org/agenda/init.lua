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

	table.insert(lines, "")
	table.insert(lines, "  [Enter] Jump to item   [q] Close agenda")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	vim.cmd("botright split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_win_set_height(win, math.min(15, math.max(6, #lines + 1)))

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

--- Prompt for a quick note and append to the default notes file.
function M.capture()
	local notes_file = vim.fn.expand(Config.options.org_default_notes_file)
	local parent_dir = vim.fn.fnamemodify(notes_file, ":h")
	if vim.fn.isdirectory(parent_dir) == 0 then
		vim.fn.mkdir(parent_dir, "p")
	end

	vim.ui.input({ prompt = "Org Capture Note: " }, function(input)
		if input and vim.trim(input) ~= "" then
			local ts = os.date("[%Y-%m-%d %a %H:%M]")
			local entry = string.format("\n* %s\n  %s\n", input, ts)
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
