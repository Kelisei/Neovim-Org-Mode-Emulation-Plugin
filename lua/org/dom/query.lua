local Query = {}

--- Recursively collect all headline nodes from a root node.
--- @param node table
--- @param acc table|nil
--- @return table
function Query.find_all_headlines(node, acc)
	acc = acc or {}
	if node.type == "headline" then
		table.insert(acc, node)
	end
	for _, child in ipairs(node.children) do
		Query.find_all_headlines(child, acc)
	end
	return acc
end

--- Find the innermost headline or node encompassing a given line number.
--- @param node table
--- @param line_number number
--- @return table|nil
function Query.find_node_at_line(node, line_number)
	if line_number < node.range.start_line or line_number > node.range.end_line then
		return nil
	end
	for _, child in ipairs(node.children) do
		local match = Query.find_node_at_line(child, line_number)
		if match then
			return match
		end
	end
	return node
end

--- Find the active headline at or preceding a given line number.
--- @param root table
--- @param line_number number
--- @return table|nil
function Query.find_headline_at_line(root, line_number)
	local headlines = Query.find_all_headlines(root)
	local candidate = nil
	for _, hl in ipairs(headlines) do
		if hl.range.start_line <= line_number and line_number <= hl.range.end_line then
			candidate = hl
		end
	end
	return candidate
end

--- Locate headline matching ID property across the tree.
--- @param root table
--- @param id string
--- @return table|nil
function Query.find_by_id(root, id)
	local headlines = Query.find_all_headlines(root)
	for _, hl in ipairs(headlines) do
		if hl.properties["ID"] == id then
			return hl
		end
	end
	return nil
end

--- Locate headline matching CUSTOM_ID property across the tree.
--- @param root table
--- @param custom_id string
--- @return table|nil
function Query.find_by_custom_id(root, custom_id)
	local headlines = Query.find_all_headlines(root)
	for _, hl in ipairs(headlines) do
		if hl.properties["CUSTOM_ID"] == custom_id then
			return hl
		end
	end
	return nil
end

--- Find all headlines matching a specified tag.
--- @param root table
--- @param tag string
--- @param inherit boolean|nil
--- @return table
function Query.find_by_tag(root, tag, inherit)
	local headlines = Query.find_all_headlines(root)
	local results = {}
	local target = string.lower(tag)
	for _, hl in ipairs(headlines) do
		local tags = hl:get_tags(inherit)
		for _, t in ipairs(tags) do
			if string.lower(t) == target then
				table.insert(results, hl)
				break
			end
		end
	end
	return results
end

--- Find all headlines with a specified TODO status.
--- @param root table
--- @param todo_state string
--- @return table
function Query.find_by_todo(root, todo_state)
	local headlines = Query.find_all_headlines(root)
	local results = {}
	for _, hl in ipairs(headlines) do
		if hl.todo == todo_state then
			table.insert(results, hl)
		end
	end
	return results
end

--- Locate all table nodes in the document.
--- @param node table
--- @param acc table|nil
--- @return table
function Query.find_tables(node, acc)
	acc = acc or {}
	if node.type == "table" then
		table.insert(acc, node)
	end
	for _, child in ipairs(node.children) do
		Query.find_tables(child, acc)
	end
	return acc
end

--- Locate all code block nodes in the document.
--- @param node table
--- @param block_type string|nil
--- @param acc table|nil
--- @return table
function Query.find_blocks(node, block_type, acc)
	acc = acc or {}
	if node.type == "block" then
		if not block_type or (node.data and node.data.block_type == string.upper(block_type)) then
			table.insert(acc, node)
		end
	end
	for _, child in ipairs(node.children) do
		Query.find_blocks(child, block_type, acc)
	end
	return acc
end

return Query
