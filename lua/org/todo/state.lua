local Config = require("org.config")

local M = {}

--- Parse state definitions into structured metadata.
--- @param keywords_list table<number, string>|nil
--- @return table
function M.parse_sequence(keywords_list)
	keywords_list = keywords_list or Config.options.org_todo_keywords
	local states = {}
	local is_terminal = false

	for _, item in ipairs(keywords_list) do
		if item == "|" then
			is_terminal = true
		else
			local name, key, flags = item:match("^([%a_]+)%((%a?)([@!]*/?[@!]*)%)")
			if not name then
				name = item:match("^([%a_]+)")
				key = name and string.sub(name, 1, 1):lower() or ""
				flags = ""
			end

			if name and name ~= "" then
				table.insert(states, {
					name = name,
					key = key ~= "" and key or string.sub(name, 1, 1):lower(),
					is_done = is_terminal,
					enter_note = flags:find("@") ~= nil,
					enter_time = flags:find("!") ~= nil,
				})
			end
		end
	end

	return states
end

--- Extract in-buffer TODO sequence or fallback to global config.
--- @param bufnr number
--- @return table
function M.get_buffer_states(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 50, false)
	for _, l in ipairs(lines) do
		local val = l:match("^#%+TODO:%s*(.*)$")
		if val then
			local parts = {}
			for p in string.gmatch(val, "(%S+)") do
				table.insert(parts, p)
			end
			return M.parse_sequence(parts)
		end
	end
	return M.parse_sequence(Config.options.org_todo_keywords)
end

--- Format current timestamp in Org format.
--- @param active boolean|nil
--- @param with_time boolean|nil
--- @return string
function M.format_timestamp(active, with_time)
	local now = os.date("*t")
	local days = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
	local day_name = days[now.wday]
	local str
	if with_time then
		str = string.format("%04d-%02d-%02d %s %02d:%02d", now.year, now.month, now.day, day_name, now.hour, now.min)
	else
		str = string.format("%04d-%02d-%02d %s", now.year, now.month, now.day, day_name)
	end
	if active then
		return "<" .. str .. ">"
	else
		return "[" .. str .. "]"
	end
end

--- Add a state transition entry to the LOGBOOK drawer.
--- @param bufnr number
--- @param headline_lnum number
--- @param old_state string|nil
--- @param new_state string|nil
--- @param note string|nil
local function append_logbook_entry(bufnr, headline_lnum, old_state, new_state, note)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local total = #lines
	local drawer_start = nil
	local drawer_end = nil

	local i = headline_lnum + 1
	while i <= total do
		local line = lines[i]
		if line:match("^(%*+)%s+") then
			break
		end
		if line:match("^%s*:LOGBOOK:%s*$") then
			drawer_start = i
		elseif line:match("^%s*:END:%s*$") and drawer_start and not drawer_end then
			drawer_end = i
			break
		end
		i = i + 1
	end

	local ts = M.format_timestamp(false, true)
	local entry_line
	if old_state and new_state then
		entry_line = string.format("  - State %-12s from %-12s %s", '"' .. new_state .. '"', '"' .. old_state .. '"', ts)
	elseif new_state then
		entry_line = string.format("  - State %-12s %s", '"' .. new_state .. '"', ts)
	else
		entry_line = string.format("  - State reset from %-12s %s", '"' .. (old_state or "") .. '"', ts)
	end

	local note_lines = {}
	if note and note ~= "" then
		table.insert(note_lines, "    \\\\\n    " .. note)
	end

	if drawer_start and drawer_end then
		vim.api.nvim_buf_set_lines(bufnr, drawer_start, drawer_start, false, { entry_line })
		if #note_lines > 0 then
			vim.api.nvim_buf_set_lines(bufnr, drawer_start + 1, drawer_start + 1, false, note_lines)
		end
	else
		local insert_pos = headline_lnum
		if lines[headline_lnum + 1] and (lines[headline_lnum + 1]:match("SCHEDULED:") or lines[headline_lnum + 1]:match("DEADLINE:")) then
			insert_pos = headline_lnum + 1
		end
		local new_drawer = {
			"  :LOGBOOK:",
			entry_line,
		}
		if #note_lines > 0 then
			for _, nl in ipairs(note_lines) do
				table.insert(new_drawer, nl)
			end
		end
		table.insert(new_drawer, "  :END:")
		vim.api.nvim_buf_set_lines(bufnr, insert_pos, insert_pos, false, new_drawer)
	end
end

--- Update or remove CLOSED timestamp on planning line.
--- @param bufnr number
--- @param headline_lnum number
--- @param set_closed boolean
local function update_closed_timestamp(bufnr, headline_lnum, set_closed)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local next_line = lines[headline_lnum + 1]

	if set_closed then
		local closed_ts = "CLOSED: " .. M.format_timestamp(false, true)
		if next_line and (next_line:match("SCHEDULED:") or next_line:match("DEADLINE:") or next_line:match("CLOSED:")) then
			if next_line:match("CLOSED:%s*%[[^%]]+%]") then
				local updated = next_line:gsub("CLOSED:%s*%[[^%]]+%]", closed_ts)
				vim.api.nvim_buf_set_lines(bufnr, headline_lnum, headline_lnum + 1, false, { updated })
			else
				local updated = next_line .. " " .. closed_ts
				vim.api.nvim_buf_set_lines(bufnr, headline_lnum, headline_lnum + 1, false, { updated })
			end
		else
			local planning_line = "   " .. closed_ts
			vim.api.nvim_buf_set_lines(bufnr, headline_lnum, headline_lnum, false, { planning_line })
		end
	else
		if next_line and next_line:match("CLOSED:%s*%[[^%]]+%]") then
			local updated = next_line:gsub("%s*CLOSED:%s*%[[^%]]+%]", "")
			if vim.trim(updated) == "" then
				vim.api.nvim_buf_set_lines(bufnr, headline_lnum, headline_lnum + 1, false, {})
			else
				vim.api.nvim_buf_set_lines(bufnr, headline_lnum, headline_lnum + 1, false, { updated })
			end
		end
	end
end

--- Set TODO state for a specified headline.
--- @param bufnr number
--- @param headline_lnum number
--- @param new_state string|nil
--- @param note string|nil
function M.set_state(bufnr, headline_lnum, new_state, note)
	local line = vim.api.nvim_buf_get_lines(bufnr, headline_lnum - 1, headline_lnum, false)[1]
	if not line then
		return
	end

	local stars, rest = line:match("^(%*+)%s+(.*)$")
	if not stars then
		return
	end

	local states = M.get_buffer_states(bufnr)
	local current_state = nil
	local first_word, remaining = rest:match("^(%S+)%s*(.*)$")

	for _, s in ipairs(states) do
		if first_word == s.name then
			current_state = s.name
			rest = remaining or ""
			break
		end
	end

	if current_state == new_state then
		return
	end

	local new_line
	if new_state and new_state ~= "" then
		new_line = string.format("%s %s %s", stars, new_state, rest)
	else
		new_line = string.format("%s %s", stars, rest)
	end
	new_line = new_line:gsub("%s+$", "")
	vim.api.nvim_buf_set_lines(bufnr, headline_lnum - 1, headline_lnum, false, { new_line })

	local new_state_def = nil
	for _, s in ipairs(states) do
		if s.name == new_state then
			new_state_def = s
			break
		end
	end

	if new_state_def and new_state_def.is_done then
		update_closed_timestamp(bufnr, headline_lnum, true)
	else
		update_closed_timestamp(bufnr, headline_lnum, false)
	end

	if new_state_def and (new_state_def.enter_time or new_state_def.enter_note or Config.options.org_log_done == "time") then
		append_logbook_entry(bufnr, headline_lnum, current_state, new_state, note)
	end
end

--- Advance headline to the next state in sequence.
--- @param bufnr number|nil
--- @param headline_lnum number|nil
function M.cycle(bufnr, headline_lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	headline_lnum = headline_lnum or vim.fn.line(".")

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local current_line = lines[headline_lnum]
	if not current_line or not current_line:match("^(%*+)%s+") then
		return
	end

	local target_lnum = headline_lnum

	local line = lines[target_lnum]
	local stars, rest = line:match("^(%*+)%s+(.*)$")
	local first_word = rest:match("^(%S+)")
	local states = M.get_buffer_states(bufnr)

	local current_idx = 0
	for idx, s in ipairs(states) do
		if first_word == s.name then
			current_idx = idx
			break
		end
	end

	local next_state = nil
	if current_idx == 0 then
		next_state = states[1] and states[1].name or nil
	elseif current_idx < #states then
		next_state = states[current_idx + 1].name
	else
		next_state = nil
	end

	local state_def = nil
	for _, s in ipairs(states) do
		if s.name == next_state then
			state_def = s
			break
		end
	end

	if state_def and state_def.enter_note then
		vim.ui.input({ prompt = "Closing Note: " }, function(note)
			M.set_state(bufnr, target_lnum, next_state, note)
		end)
	else
		M.set_state(bufnr, target_lnum, next_state)
	end
end

return M
