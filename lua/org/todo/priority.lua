local Config = require("org.config")

local M = {}

--- Parse priority indicator from headline line.
--- @param line string
--- @return string|nil, number, number
local function get_priority_span(line)
	local s, e, prio = line:find("%[#([A-Za-z])%]")
	if s then
		return string.upper(prio), s, e
	end
	return nil, nil, nil
end

--- Set or update priority for a given headline line.
--- @param bufnr number
--- @param headline_lnum number
--- @param prio string|nil
function M.set_priority(bufnr, headline_lnum, prio)
	local line = vim.api.nvim_buf_get_lines(bufnr, headline_lnum - 1, headline_lnum, false)[1]
	if not line or not line:match("^(%*+)%s+") then
		return
	end

	local cur_prio, s, e = get_priority_span(line)
	local updated
	if cur_prio then
		if prio and prio ~= "" then
			updated = line:sub(1, s - 1) .. "[#" .. string.upper(prio) .. "]" .. line:sub(e + 1)
		else
			updated = line:sub(1, s - 1) .. vim.trim(line:sub(e + 1))
		end
	else
		if prio and prio ~= "" then
			local stars, todo_and_rest = line:match("^(%*+)%s+(.*)$")
			local first_word, rest = todo_and_rest:match("^(%S+)%s*(.*)$")
			local is_todo = false
			for _, kw in ipairs(Config.options.org_todo_keywords) do
				local clean = kw:gsub("%b()", "")
				if first_word == clean then
					is_todo = true
					break
				end
			end
			if is_todo then
				updated = string.format("%s %s [#%s] %s", stars, first_word, string.upper(prio), rest)
			else
				updated = string.format("%s [#%s] %s", stars, string.upper(prio), todo_and_rest)
			end
		else
			return
		end
	end

	updated = updated:gsub("%s+$", "")
	vim.api.nvim_buf_set_lines(bufnr, headline_lnum - 1, headline_lnum, false, { updated })
end

--- Increase priority (C -> B -> A).
--- @param bufnr number|nil
--- @param headline_lnum number|nil
function M.cycle_up(bufnr, headline_lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	headline_lnum = headline_lnum or vim.fn.line(".")

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local target_lnum = nil
	for i = headline_lnum, 1, -1 do
		if lines[i]:match("^(%*+)%s+") then
			target_lnum = i
			break
		end
	end
	if not target_lnum then
		return
	end

	local cur_prio = get_priority_span(lines[target_lnum])
	local next_prio
	if not cur_prio then
		next_prio = Config.options.org_priority_default or "B"
	elseif cur_prio == "C" then
		next_prio = "B"
	elseif cur_prio == "B" then
		next_prio = "A"
	elseif cur_prio == "A" then
		next_prio = nil
	else
		next_prio = "B"
	end

	M.set_priority(bufnr, target_lnum, next_prio)
end

--- Decrease priority (A -> B -> C).
--- @param bufnr number|nil
--- @param headline_lnum number|nil
function M.cycle_down(bufnr, headline_lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	headline_lnum = headline_lnum or vim.fn.line(".")

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local target_lnum = nil
	for i = headline_lnum, 1, -1 do
		if lines[i]:match("^(%*+)%s+") then
			target_lnum = i
			break
		end
	end
	if not target_lnum then
		return
	end

	local cur_prio = get_priority_span(lines[target_lnum])
	local next_prio
	if not cur_prio then
		next_prio = Config.options.org_priority_default or "B"
	elseif cur_prio == "A" then
		next_prio = "B"
	elseif cur_prio == "B" then
		next_prio = "C"
	elseif cur_prio == "C" then
		next_prio = nil
	else
		next_prio = "B"
	end

	M.set_priority(bufnr, target_lnum, next_prio)
end

--- Prompt interactive priority picker for current headline.
--- @param bufnr number|nil
--- @param headline_lnum number|nil
function M.prompt_priority(bufnr, headline_lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	headline_lnum = headline_lnum or vim.fn.line(".")

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local target_lnum = nil
	for i = headline_lnum, 1, -1 do
		if lines[i]:match("^(%*+)%s+") then
			target_lnum = i
			break
		end
	end
	if not target_lnum then
		return
	end

	local items = {
		"[A] Priority A (Highest)",
		"[B] Priority B (Medium)",
		"[C] Priority C (Lowest)",
		"[ ] Clear Priority",
	}

	vim.ui.select(items, { prompt = "Select Priority:" }, function(choice)
		if not choice then
			return
		end
		if choice == "[ ] Clear Priority" then
			M.set_priority(bufnr, target_lnum, nil)
		else
			local p = choice:match("%[([A-Za-z])%]")
			if p then
				M.set_priority(bufnr, target_lnum, p)
			end
		end
	end)
end

return M
