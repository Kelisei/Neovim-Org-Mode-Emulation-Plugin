local State = require("org.todo.state")
local Priority = require("org.todo.priority")

local M = {}

--- Advance TODO state for current headline.
--- @param bufnr number|nil
--- @param headline_lnum number|nil
function M.cycle(bufnr, headline_lnum)
	State.cycle(bufnr, headline_lnum)
end

--- Increase priority for current headline.
function M.priority_up()
	Priority.cycle_up()
end

--- Decrease priority for current headline.
function M.priority_down()
	Priority.cycle_down()
end

--- Open interactive fast selection menu for TODO states.
--- @param bufnr number|nil
--- @param headline_lnum number|nil
function M.prompt_state(bufnr, headline_lnum)
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

	local states = State.get_buffer_states(bufnr)
	local items = {}
	for _, s in ipairs(states) do
		table.insert(items, string.format("[%s] %s", s.key, s.name))
	end
	table.insert(items, "[ ] (Clear State)")

	vim.ui.select(items, { prompt = "Select TODO State:" }, function(choice)
		if not choice then
			return
		end
		if choice == "[ ] (Clear State)" then
			State.set_state(bufnr, target_lnum, nil)
			return
		end
		local selected_name = choice:match("%]%s*(%S+)")
		local state_def = nil
		for _, s in ipairs(states) do
			if s.name == selected_name then
				state_def = s
				break
			end
		end
		if state_def and state_def.enter_note then
			vim.ui.input({ prompt = "Closing Note: " }, function(note)
				State.set_state(bufnr, target_lnum, selected_name, note)
			end)
		else
			State.set_state(bufnr, target_lnum, selected_name)
		end
	end)
end

return setmetatable(M, {
	__index = function(_, key)
		if State[key] then
			return State[key]
		end
		return Priority[key]
	end,
})
