local Repeater = require("org.date.repeater")
local DOM = require("org.dom")

local M = {}

--- Parse a raw timestamp string into date parts.
--- @param str string
--- @return table|nil
function M.parse(str)
	local is_active = str:sub(1, 1) == "<"
	local inner = str:match("^[<%[](.-)[>%]]$")
	if not inner then
		return nil
	end

	local year, month, day, day_name, hour, min = inner:match("(%d%d%d%d)%-(%d%d)%-(%d%d)%s*(%a*)%s*(%d*):?(%d*)")
	if not year then
		return nil
	end

	local rep_type, rep_val, rep_unit = Repeater.parse(inner)

	return {
		active = is_active,
		year = tonumber(year),
		month = tonumber(month),
		day = tonumber(day),
		day_name = day_name ~= "" and day_name or nil,
		hour = tonumber(hour) or nil,
		min = tonumber(min) or nil,
		repeater_type = rep_type,
		repeater_val = rep_val,
		repeater_unit = rep_unit,
		raw = str,
	}
end

--- Format a date table as an Org Mode timestamp string.
--- @param date table
--- @param active boolean|nil
--- @param with_time boolean|nil
--- @param repeater string|nil
--- @return string
function M.format(date, active, with_time, repeater)
	local days = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
	local day_name = date.wday and days[date.wday] or "Sun"
	local b_open = active and "<" or "["
	local b_close = active and ">" or "]"

	local str
	if with_time and date.hour and date.min then
		str = string.format("%04d-%02d-%02d %s %02d:%02d", date.year, date.month, date.day, day_name, date.hour, date.min)
	else
		str = string.format("%04d-%02d-%02d %s", date.year, date.month, date.day, day_name)
	end

	if repeater and repeater ~= "" then
		str = str .. " " .. repeater
	end

	return b_open .. str .. b_close
end

--- Update planning field (SCHEDULED, DEADLINE) for a headline.
--- @param bufnr number
--- @param headline_lnum number
--- @param field string
--- @param ts_string string|nil
function M.set_planning(bufnr, headline_lnum, field, ts_string)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local next_line = lines[headline_lnum + 1]
	local has_planning = next_line and (next_line:match("SCHEDULED:") or next_line:match("DEADLINE:") or next_line:match("CLOSED:"))
	local key = string.upper(field)

	if has_planning then
		local pat = key .. ":%s*[<][^>]+[>]"
		if key == "CLOSED" then
			pat = key .. ":%s*%[[^%]]+%]"
		end

		local updated = next_line
		if ts_string and ts_string ~= "" then
			if next_line:match(pat) then
				updated = next_line:gsub(pat, key .. ": " .. ts_string)
			else
				updated = next_line .. " " .. key .. ": " .. ts_string
			end
		else
			updated = next_line:gsub("%s*" .. pat, "")
		end

		if vim.trim(updated) == "" then
			vim.api.nvim_buf_set_lines(bufnr, headline_lnum, headline_lnum + 1, false, {})
		else
			vim.api.nvim_buf_set_lines(bufnr, headline_lnum, headline_lnum + 1, false, { updated })
		end
	else
		if ts_string and ts_string ~= "" then
			local new_line = string.format("   %s: %s", key, ts_string)
			vim.api.nvim_buf_set_lines(bufnr, headline_lnum, headline_lnum, false, { new_line })
		end
	end

	DOM.invalidate(bufnr)
end

return M
