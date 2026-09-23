local Align = require("org.table.align")

local M = {}

--- Calculate numerical sum of values in array.
--- @param vals table
--- @return number
local function vsum(vals)
	local s = 0
	for _, v in ipairs(vals) do
		s = s + (tonumber(v) or 0)
	end
	return s
end

--- Calculate arithmetic mean of values in array.
--- @param vals table
--- @return number
local function vmean(vals)
	if #vals == 0 then
		return 0
	end
	return vsum(vals) / #vals
end

--- Extract cell range values between two coordinate points in data rows.
--- @param data_rows table<number, table<number, string>>
--- @param r1 number
--- @param c1 number
--- @param r2 number
--- @param c2 number
--- @return table<number, number>
local function get_range_values(data_rows, r1, c1, r2, c2)
	local vals = {}
	local r_start = math.min(r1, r2)
	local r_end = math.max(r1, r2)
	local c_start = math.min(c1, c2)
	local c_end = math.max(c1, c2)

	for r = r_start, r_end do
		if data_rows[r] then
			for c = c_start, c_end do
				local val = data_rows[r][c]
				local num = tonumber(val)
				if num then
					table.insert(vals, num)
				end
			end
		end
	end
	return vals
end

--- Build isolated evaluation environment for formula execution.
--- @return table
local function build_eval_env()
	local env = {
		vsum = vsum,
		sum = vsum,
		vmean = vmean,
		mean = vmean,
		min = math.min,
		max = math.max,
		abs = math.abs,
		sqrt = math.sqrt,
		floor = math.floor,
		ceil = math.ceil,
		round = function(x)
			return math.floor(x + 0.5)
		end,
	}
	return env
end

--- Substitute cell references and coordinate ranges in expression for a data row.
--- @param expr string
--- @param data_rows table<number, table<number, string>>
--- @param current_row number
--- @return string
local function substitute_references(expr, data_rows, current_row)
	expr = expr:gsub("@(%d+)%$(%d+)%.%.@(%d+)%$(%d+)", function(r1, c1, r2, c2)
		local vals = get_range_values(data_rows, tonumber(r1), tonumber(c1), tonumber(r2), tonumber(c2))
		return "{" .. table.concat(vals, ",") .. "}"
	end)

	expr = expr:gsub("@(%-?%d+)%$(%d+)", function(r_str, c_str)
		local r = tonumber(r_str)
		local c = tonumber(c_str)
		if r < 0 then
			r = current_row + r
		end
		local val = (data_rows[r] and data_rows[r][c]) or "0"
		return tostring(tonumber(val) or 0)
	end)

	expr = expr:gsub("%$(%d+)", function(c_str)
		local c = tonumber(c_str)
		local val = (data_rows[current_row] and data_rows[current_row][c]) or "0"
		return tostring(tonumber(val) or 0)
	end)

	return expr
end

--- Evaluate mathematical formula string in safe environment.
--- @param expr string
--- @param env table
--- @return number|string|nil
local function eval_expression(expr, env)
	local lua_code = "return " .. expr
	local fn, err = load(lua_code, "org_tblfm", "t", env)
	if not fn then
		return nil
	end
	local ok, res = pcall(fn)
	if ok then
		if type(res) == "number" then
			if res == math.floor(res) then
				return tostring(math.floor(res))
			else
				return string.format("%.2f", res)
			end
		end
		return tostring(res)
	end
	return nil
end

--- Execute a list of formula assignments on a table grid ignoring separator rows.
--- @param raw_lines table<number, string>
--- @param tblfm_str string
--- @return table<number, string>
function M.evaluate_tblfm(raw_lines, tblfm_str)
	local data_rows = {}
	local is_sep = {}
	local phys_to_data = {}

	for idx, l in ipairs(raw_lines) do
		if Align.is_separator(l) then
			is_sep[idx] = true
		else
			local cells = Align.parse_row_cells(l)
			table.insert(data_rows, cells)
			phys_to_data[idx] = #data_rows
		end
	end

	local formulas = {}
	for f in string.gmatch(tblfm_str, "([^:]+)") do
		local clean = vim.trim(f)
		if clean ~= "" then
			table.insert(formulas, clean)
		end
	end

	local env = build_eval_env()

	for _, formula in ipairs(formulas) do
		local target, expr = formula:match("^(.-)=(.*)$")
		if target and expr then
			target = vim.trim(target)
			expr = vim.trim(expr)

			local target_row, target_col = target:match("^@(%d+)%$(%d+)$")
			if target_row and target_col then
				local tr = tonumber(target_row)
				local tc = tonumber(target_col)
				local resolved_expr = substitute_references(expr, data_rows, tr)
				local res = eval_expression(resolved_expr, env)
				if res and data_rows[tr] then
					data_rows[tr][tc] = tostring(res)
				end
			else
				local col_idx = target:match("^%$(%d+)$")
				if col_idx then
					local c = tonumber(col_idx)
					for r = 2, #data_rows do
						local resolved_expr = substitute_references(expr, data_rows, r)
						local res = eval_expression(resolved_expr, env)
						if res then
							data_rows[r][c] = tostring(res)
						end
					end
				end
			end
		end
	end

	local updated_lines = {}
	for idx, l in ipairs(raw_lines) do
		if is_sep[idx] then
			table.insert(updated_lines, l)
		else
			local dr = phys_to_data[idx]
			local cells = data_rows[dr]
			table.insert(updated_lines, "| " .. table.concat(cells, " | ") .. " |")
		end
	end

	local formatted, _ = Align.align_table(updated_lines)
	return formatted
end

return M
