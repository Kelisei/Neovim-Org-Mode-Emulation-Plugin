local Node = require("org.dom.node")

local Parser = {}

--- Parse in-buffer settings keywords such as #+KEYWORD: value.
--- @param line string
--- @return string|nil, string|nil
local function parse_keyword(line)
	local key, val = line:match("^#%+(%a+):%s*(.*)$")
	if key then
		return string.upper(key), vim.trim(val)
	end
	return nil, nil
end

--- Parse headline line components (stars, todo, priority, cookies, tags, clean title).
--- @param line string
--- @param known_todos table<string, boolean>
--- @return table|nil
local function parse_headline(line, known_todos)
	local stars, rest = line:match("^(%*+)%s+(.*)$")
	if not stars then
		return nil
	end

	local level = #stars
	local raw_title = rest
	local todo = nil
	local priority = nil
	local tags = {}
	local cookies = {}

	local tag_str = rest:match(":(%S+):%s*$")
	if tag_str then
		for tag in string.gmatch(tag_str, "([^:]+)") do
			table.insert(tags, tag)
		end
		rest = rest:gsub(":%S+:%s*$", "")
		rest = vim.trim(rest)
	end

	local first_word, after_word = rest:match("^(%S+)%s*(.*)$")
	if first_word and known_todos[first_word] then
		todo = first_word
		rest = after_word or ""
	end

	local prio_match, after_prio = rest:match("^%[#([A-Za-z])%]%s*(.*)$")
	if prio_match then
		priority = string.upper(prio_match)
		rest = after_prio or ""
	end

	for cookie in string.gmatch(rest, "(%[%d+/%d+%])") do
		table.insert(cookies, cookie)
	end
	for cookie in string.gmatch(rest, "(%[%d+%%%])") do
		table.insert(cookies, cookie)
	end

	rest = rest:gsub("%[%d+/%d+%]", "")
	rest = rest:gsub("%[%d+%%%]", "")
	local clean_title = vim.trim(rest)

	return {
		level = level,
		todo = todo,
		priority = priority,
		tags = tags,
		cookies = cookies,
		title = clean_title,
		raw_title = raw_title,
	}
end

--- Parse a planning line containing SCHEDULED, DEADLINE, or CLOSED timestamps.
--- @param line string
--- @return table|nil
local function parse_planning_line(line)
	local result = {}
	local found = false

	local scheduled = line:match("SCHEDULED:%s*([<][^>]+[>])")
	if scheduled then
		result.scheduled = scheduled
		found = true
	end

	local deadline = line:match("DEADLINE:%s*([<][^>]+[>])")
	if deadline then
		result.deadline = deadline
		found = true
	end

	local closed = line:match("CLOSED:%s*([%[][^%]]+[%]])")
	if closed then
		result.closed = closed
		found = true
	end

	if found then
		return result
	end
	return nil
end

--- Parse raw org lines into a hierarchical DOM tree.
--- @param lines table<number, string>
--- @param config_todos table|nil
--- @return table
function Parser.parse(lines, config_todos)
	local known_todos = {
		TODO = true,
		NEXT = true,
		DONE = true,
		CANCELED = true,
		WAIT = true,
		HOLD = true,
	}
	if config_todos then
		for _, kw in ipairs(config_todos) do
			local clean = kw:gsub("%b()", "")
			if clean ~= "|" and clean ~= "" then
				known_todos[clean] = true
			end
		end
	end

	local root = Node.new({
		type = "root",
		level = 0,
		title = "Document Root",
		range = { start_line = 1, end_line = #lines },
	})

	local settings = {}
	local stack = { root }
	local current_headline = nil
	local current_drawer = nil
	local current_block = nil
	local current_table = nil
	local i = 1

	while i <= #lines do
		local line = lines[i]

		local key, val = parse_keyword(line)
		if key then
			settings[key] = val
			if key == "TODO" then
				for part in string.gmatch(val, "(%S+)") do
					local clean = part:gsub("%b()", "")
					if clean ~= "|" then
						known_todos[clean] = true
					end
				end
			end
		end

		local headline_data = parse_headline(line, known_todos)
		if headline_data then
			if current_drawer then
				current_drawer = nil
			end
			if current_block then
				current_block = nil
			end
			if current_table then
				current_table = nil
			end

			local node = Node.new({
				type = "headline",
				level = headline_data.level,
				title = headline_data.title,
				raw_title = headline_data.raw_title,
				todo = headline_data.todo,
				priority = headline_data.priority,
				tags = headline_data.tags,
				cookies = headline_data.cookies,
				range = { start_line = i, end_line = #lines },
			})

			while #stack > 1 and stack[#stack].level >= node.level do
				local popped = table.remove(stack)
				popped.range.end_line = i - 1
			end

			local parent = stack[#stack]
			parent:add_child(node)
			table.insert(stack, node)
			current_headline = node

			if i + 1 <= #lines then
				local plan = parse_planning_line(lines[i + 1])
				if plan then
					node.planning = plan
				end
			end
		else
			local drawer_open = line:match("^%s*:(%a[%a%-_]*):%s*$")
			local drawer_close = line:match("^%s*:END:%s*$")

			if drawer_open and not current_drawer then
				local drawer_name = string.upper(drawer_open)
				current_drawer = {
					name = drawer_name,
					start_line = i,
					end_line = i,
					lines = {},
				}
			elseif drawer_close and current_drawer then
				current_drawer.end_line = i
				if current_headline then
					current_headline.drawers[current_drawer.name] = current_drawer.lines
					if current_drawer.name == "PROPERTIES" then
						for _, dline in ipairs(current_drawer.lines) do
							local pkey, pval = dline:match("^%s*:(%S-):%s*(.*)$")
							if pkey and pval then
								current_headline.properties[string.upper(pkey)] = vim.trim(pval)
							end
						end
					end
				end
				current_drawer = nil
			elseif current_drawer then
				table.insert(current_drawer.lines, line)
			end

			local block_start, block_args = line:match("^%s*#%+BEGIN_([%a_]+)%s*(.*)$")
			local block_end = line:match("^%s*#%+END_([%a_]+)%s*$")
			if block_start and not current_block then
				local block_node = Node.new({
					type = "block",
					title = block_start,
					range = { start_line = i, end_line = i },
					data = {
						block_type = string.upper(block_start),
						args = block_args,
						lines = {},
					},
				})
				if current_headline then
					current_headline:add_child(block_node)
				else
					root:add_child(block_node)
				end
				current_block = block_node
			elseif block_end and current_block then
				current_block.range.end_line = i
				current_block = nil
			elseif current_block then
				table.insert(current_block.data.lines, line)
			end

			local is_table_row = line:match("^%s*|")
			if is_table_row and not current_table then
				local table_node = Node.new({
					type = "table",
					range = { start_line = i, end_line = i },
					data = {
						rows = { line },
						tblfm = nil,
					},
				})
				if current_headline then
					current_headline:add_child(table_node)
				else
					root:add_child(table_node)
				end
				current_table = table_node
			elseif is_table_row and current_table then
				table.insert(current_table.data.rows, line)
				current_table.range.end_line = i
			elseif current_table then
				local tblfm = line:match("^%s*#%+TBLFM:%s*(.*)$")
				if tblfm then
					current_table.data.tblfm = tblfm
					current_table.range.end_line = i
				end
				current_table = nil
			end
		end

		i = i + 1
	end

	while #stack > 1 do
		local popped = table.remove(stack)
		popped.range.end_line = #lines
	end

	root.data.settings = settings
	return root
end

return Parser
