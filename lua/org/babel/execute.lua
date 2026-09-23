local Config = require("org.config")
local Align = require("org.table.align")

local M = {}

--- Parse block header arguments like :results value :var x=5 :tangle out.py.
--- @param arg_str string
--- @return table
function M.parse_header_args(arg_str)
	local args = {
		results = "output",
		vars = {},
		tangle = nil,
	}

	for k, v in string.gmatch(arg_str, ":(%a+)%s+([^:]+)") do
		local key = vim.trim(k)
		local val = vim.trim(v)
		if key == "results" then
			args.results = val:lower()
		elseif key == "tangle" then
			args.tangle = val
		elseif key == "var" then
			local var_name, var_val = val:match("^([%a_][%w_]*)%s*=%s*(.*)$")
			if var_name and var_val then
				args.vars[var_name] = var_val
			end
		end
	end

	return args
end

--- Prepare language specific code script with injected variable bindings.
--- @param lang string
--- @param code_lines table<number, string>
--- @param vars table<string, string>
--- @return string
local function prepare_script(lang, code_lines, vars)
	local prefix = {}
	local norm_lang = lang:lower()
	local has_return = false
	for _, l in ipairs(code_lines) do
		if l:match("^%s*return%s*") or l:match("^%s*return$") then
			has_return = true
			break
		end
	end

	if norm_lang == "python" or norm_lang == "python3" then
		for k, v in pairs(vars) do
			if tonumber(v) then
				table.insert(prefix, string.format("%s = %s", k, v))
			else
				local clean_v = v:gsub('"', '\\"')
				table.insert(prefix, string.format('%s = "%s"', k, clean_v))
			end
		end

		if has_return then
			local indented = {}
			for _, cl in ipairs(code_lines) do
				table.insert(indented, "    " .. cl)
			end
			local wrapper = {
				"",
				"def __org_babel_python_main():",
				table.concat(indented, "\n"),
				"",
				"__org_babel_res = __org_babel_python_main()",
				"if __org_babel_res is not None:",
				"    if isinstance(__org_babel_res, (list, tuple)):",
				"        for row in __org_babel_res:",
				"            if isinstance(row, (list, tuple)):",
				'                print("| " + " | ".join(str(c) for c in row) + " |")',
				"            else:",
				'                print("| " + str(row) + " |")',
				"    else:",
				"        print(__org_babel_res)",
			}
			local full_code = table.concat(prefix, "\n")
			if #prefix > 0 then
				full_code = full_code .. "\n"
			end
			full_code = full_code .. table.concat(wrapper, "\n")
			return full_code
		end
	elseif norm_lang == "bash" or norm_lang == "sh" then
		for k, v in pairs(vars) do
			table.insert(prefix, string.format('%s="%s"', k, v))
		end
	elseif norm_lang == "lua" then
		for k, v in pairs(vars) do
			if tonumber(v) then
				table.insert(prefix, string.format("local %s = %s", k, v))
			else
				table.insert(prefix, string.format('local %s = %q', k, v))
			end
		end

		if has_return then
			local indented = {}
			for _, cl in ipairs(code_lines) do
				table.insert(indented, "    " .. cl)
			end
			local wrapper = {
				"",
				"local function __org_babel_lua_main()",
				table.concat(indented, "\n"),
				"end",
				"",
				"local __org_babel_res = __org_babel_lua_main()",
				"if __org_babel_res ~= nil then",
				'    if type(__org_babel_res) == "table" then',
				"        for _, row in ipairs(__org_babel_res) do",
				'            if type(row) == "table" then',
				"                local parts = {}",
				"                for _, c in ipairs(row) do table.insert(parts, tostring(c)) end",
				'                print("| " .. table.concat(parts, " | ") .. " |")',
				"            else",
				'                print("| " .. tostring(row) .. " |")',
				"            end",
				"        end",
				"    else",
				"        print(tostring(__org_babel_res))",
				"    end",
				"end",
			}
			local full_code = table.concat(prefix, "\n")
			if #prefix > 0 then
				full_code = full_code .. "\n"
			end
			full_code = full_code .. table.concat(wrapper, "\n")
			return full_code
		end
	elseif norm_lang == "ruby" then
		for k, v in pairs(vars) do
			if tonumber(v) then
				table.insert(prefix, string.format("%s = %s", k, v))
			else
				table.insert(prefix, string.format('%s = %q', k, v))
			end
		end

		if has_return then
			local indented = {}
			for _, cl in ipairs(code_lines) do
				table.insert(indented, "    " .. cl)
			end
			local wrapper = {
				"",
				"def __org_babel_rb_main",
				table.concat(indented, "\n"),
				"end",
				"",
				"__org_babel_res = __org_babel_rb_main",
				"if !__org_babel_res.nil?",
				"    if __org_babel_res.is_a?(Array)",
				"        __org_babel_res.each do |row|",
				"            if row.is_a?(Array)",
				'                puts "| " + row.map(&:to_s).join(" | ") + " |"',
				"            else",
				'                puts "| " + row.to_s + " |"',
				"            end",
				"        end",
				"    else",
				"        puts __org_babel_res",
				"    end",
				"end",
			}
			local full_code = table.concat(prefix, "\n")
			if #prefix > 0 then
				full_code = full_code .. "\n"
			end
			full_code = full_code .. table.concat(wrapper, "\n")
			return full_code
		end
	elseif norm_lang == "javascript" or norm_lang == "node" then
		for k, v in pairs(vars) do
			if tonumber(v) then
				table.insert(prefix, string.format("const %s = %s;", k, v))
			else
				table.insert(prefix, string.format('const %s = %q;', k, v))
			end
		end

		if has_return then
			local indented = {}
			for _, cl in ipairs(code_lines) do
				table.insert(indented, "    " .. cl)
			end
			local wrapper = {
				"",
				"function __org_babel_js_main() {",
				table.concat(indented, "\n"),
				"}",
				"",
				"const __org_babel_res = __org_babel_js_main();",
				"if (__org_babel_res !== undefined && __org_babel_res !== null) {",
				"    if (Array.isArray(__org_babel_res)) {",
				"        for (const row of __org_babel_res) {",
				"            if (Array.isArray(row)) {",
				'                console.log("| " + row.join(" | ") + " |");',
				"            } else {",
				'                console.log("| " + row + " |");',
				"            }",
				"        }",
				"    } else {",
				"        console.log(__org_babel_res);",
				"    }",
				"}",
			}
			local full_code = table.concat(prefix, "\n")
			if #prefix > 0 then
				full_code = full_code .. "\n"
			end
			full_code = full_code .. table.concat(wrapper, "\n")
			return full_code
		end
	end

	local full_code = table.concat(prefix, "\n")
	if #prefix > 0 then
		full_code = full_code .. "\n"
	end
	full_code = full_code .. table.concat(code_lines, "\n")
	return full_code
end

--- Format output lines into an Org Mode table representation.
--- @param raw_output string
--- @return table<number, string>
local function format_as_org_table(raw_output)
	local lines = vim.split(raw_output, "\n", { trimempty = true })
	local rows = {}
	for _, l in ipairs(lines) do
		local trimmed = vim.trim(l)
		if trimmed:match("^%s*|.*|%s*$") then
			table.insert(rows, trimmed)
		elseif trimmed:match("^%[.*%]$") then
			local inner = trimmed:sub(2, -2)
			local cells = {}
			for item in string.gmatch(inner, "([^,]+)") do
				table.insert(cells, vim.trim(item):gsub('^["\']', ''):gsub('["\']$', ''))
			end
			table.insert(rows, "| " .. table.concat(cells, " | ") .. " |")
		else
			local cells = {}
			for word in string.gmatch(trimmed, "(%S+)") do
				table.insert(cells, word)
			end
			if #cells > 0 then
				table.insert(rows, "| " .. table.concat(cells, " | ") .. " |")
			end
		end
	end
	if #rows > 0 then
		local aligned, _ = Align.align_table(rows)
		return aligned
	end
	return { "| " .. raw_output .. " |" }
end

--- Execute source code block and capture standard output.
--- @param lang string
--- @param code_lines table<number, string>
--- @param header_args table
--- @return boolean, table<number, string>
function M.run(lang, code_lines, header_args)
	local norm_lang = lang:lower()
	local cmd_str = Config.options.org_babel_languages[norm_lang]
	if not cmd_str then
		return false, { "Error: No interpreter configured for language: " .. lang }
	end

	local full_code = prepare_script(norm_lang, code_lines, header_args.vars or {})
	local tmp_file = vim.fn.tempname()
	local f = io.open(tmp_file, "w")
	if not f then
		return false, { "Error: Unable to create temporary execution file" }
	end
	f:write(full_code)
	f:close()

	local cmd_parts = vim.split(cmd_str, "%s+")
	table.insert(cmd_parts, tmp_file)

	local res = vim.system(cmd_parts, { text = true }):wait(10000)
	os.remove(tmp_file)

	if res.code ~= 0 then
		local err_msg = (res.stderr and res.stderr ~= "") and res.stderr or (res.stdout or "")
		local out_lines = vim.split(vim.trim(err_msg), "\n")
		local formatted = {}
		for _, ol in ipairs(out_lines) do
			table.insert(formatted, ": " .. ol)
		end
		return false, formatted
	end

	local raw_out = vim.trim(res.stdout or "")
	local results_mode = header_args.results or "output"

	if results_mode == "silent" then
		return true, {}
	end

	if results_mode == "table" then
		return true, format_as_org_table(raw_out)
	end

	local out_lines = vim.split(raw_out, "\n")
	local formatted = {}
	for _, ol in ipairs(out_lines) do
		table.insert(formatted, ": " .. ol)
	end
	return true, formatted
end

return M
