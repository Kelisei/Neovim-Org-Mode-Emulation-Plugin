local M = {}

--- Parse repeater specifier from a timestamp string.
--- @param str string
--- @return string|nil, number|nil, string|nil
function M.parse(str)
	local rep_type, val, unit = str:match("([%+%c%.]+)(%d+)([dwmy])")
	if rep_type and val and unit then
		return rep_type, tonumber(val), unit
	end
	return nil, nil, nil
end

--- Add specified interval to a date table.
--- @param date table
--- @param val number
--- @param unit string
--- @return table
local function add_interval(date, val, unit)
	local d = vim.deepcopy(date)
	if unit == "d" then
		d.day = d.day + val
	elseif unit == "w" then
		d.day = d.day + (val * 7)
	elseif unit == "m" then
		d.month = d.month + val
	elseif unit == "y" then
		d.year = d.year + val
	end
	local t = os.time(d)
	return os.date("*t", t)
end

--- Compute the next recurrence of a timestamp string according to its repeater.
--- @param ts_str string
--- @return string|nil
function M.advance(ts_str)
	local bracket_open, inner, bracket_close = ts_str:match("^([<%[])(.-)([>%]])$")
	if not inner then
		return nil
	end

	local rep_type, val, unit = M.parse(inner)
	if not rep_type then
		return nil
	end

	local year, month, day, hour, min = inner:match("(%d%d%d%d)%-(%d%d)%-(%d%d)%s+%a+%s*(%d*):?(%d*)")
	if not year then
		return nil
	end

	local orig_date = {
		year = tonumber(year),
		month = tonumber(month),
		day = tonumber(day),
		hour = tonumber(hour) or 0,
		min = tonumber(min) or 0,
		sec = 0,
	}

	local now = os.date("*t")
	local next_date = nil

	if rep_type == ".+" then
		next_date = add_interval(now, val, unit)
	elseif rep_type == "++" then
		next_date = add_interval(orig_date, val, unit)
		local now_t = os.time(now)
		while os.time(next_date) < now_t do
			next_date = add_interval(next_date, val, unit)
		end
	else
		next_date = add_interval(orig_date, val, unit)
	end

	local days = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
	local day_name = days[next_date.wday]

	local date_part
	if hour and hour ~= "" and min and min ~= "" then
		date_part = string.format("%04d-%02d-%02d %s %02d:%02d", next_date.year, next_date.month, next_date.day, day_name, orig_date.hour, orig_date.min)
	else
		date_part = string.format("%04d-%02d-%02d %s", next_date.year, next_date.month, next_date.day, day_name)
	end

	local rep_str = rep_type .. val .. unit
	return bracket_open .. date_part .. " " .. rep_str .. bracket_close
end

return M
