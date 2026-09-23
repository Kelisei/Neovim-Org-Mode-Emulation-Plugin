local Timestamp = require("org.date.timestamp")
local Repeater = require("org.date.repeater")
local DOM = require("org.dom")

local M = {}

--- Prompt user to set SCHEDULED date on current headline.
--- @param bufnr number|nil
--- @param headline_lnum number|nil
function M.prompt_scheduled(bufnr, headline_lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	headline_lnum = headline_lnum or vim.fn.line(".")

	local root = DOM.get(bufnr)
	local node = DOM.find_headline_at_line(root, headline_lnum)
	if not node then
		return
	end

	local default_date = Timestamp.format(os.date("*t"), true, false)
	vim.ui.input({ prompt = "Schedule date: ", default = default_date }, function(input)
		if input then
			local clean = vim.trim(input)
			if clean ~= "" and not clean:match("^[<]") then
				clean = "<" .. clean .. ">"
			end
			Timestamp.set_planning(bufnr, node.range.start_line, "SCHEDULED", clean ~= "" and clean or nil)
		end
	end)
end

--- Prompt user to set DEADLINE date on current headline.
--- @param bufnr number|nil
--- @param headline_lnum number|nil
function M.prompt_deadline(bufnr, headline_lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	headline_lnum = headline_lnum or vim.fn.line(".")

	local root = DOM.get(bufnr)
	local node = DOM.find_headline_at_line(root, headline_lnum)
	if not node then
		return
	end

	local default_date = Timestamp.format(os.date("*t"), true, false)
	vim.ui.input({ prompt = "Deadline date: ", default = default_date }, function(input)
		if input then
			local clean = vim.trim(input)
			if clean ~= "" and not clean:match("^[<]") then
				clean = "<" .. clean .. ">"
			end
			Timestamp.set_planning(bufnr, node.range.start_line, "DEADLINE", clean ~= "" and clean or nil)
		end
	end)
end

--- Insert active or inactive timestamp at cursor position.
--- @param active boolean|nil
--- @param with_time boolean|nil
function M.insert_timestamp(active, with_time)
	local ts = Timestamp.format(os.date("*t"), active ~= false, with_time == true)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1], cursor[2]
	local line = vim.api.nvim_get_current_line()
	local new_line = line:sub(1, col) .. ts .. line:sub(col + 1)
	vim.api.nvim_set_current_line(new_line)
	vim.api.nvim_win_set_cursor(0, { row, col + #ts })
end

return setmetatable(M, {
	__index = function(_, key)
		if Timestamp[key] then
			return Timestamp[key]
		end
		return Repeater[key]
	end,
})
