local Node = {}
Node.__index = Node

--- Create a new DOM node instance.
--- @param opts table
--- @return table
function Node.new(opts)
	local self = setmetatable({}, Node)
	self.type = opts.type or "node"
	self.level = opts.level or 0
	self.title = opts.title or ""
	self.raw_title = opts.raw_title or ""
	self.todo = opts.todo or nil
	self.priority = opts.priority or nil
	self.tags = opts.tags or {}
	self.cookies = opts.cookies or {}
	self.planning = opts.planning or {}
	self.properties = opts.properties or {}
	self.drawers = opts.drawers or {}
	self.range = opts.range or { start_line = 1, end_line = 1 }
	self.parent = opts.parent or nil
	self.children = opts.children or {}
	self.data = opts.data or {}
	return self
end

--- Add a child node to this node and establish back-reference.
--- @param child table
function Node:add_child(child)
	child.parent = self
	table.insert(self.children, child)
end

--- Retrieve property value with optional hierarchical inheritance.
--- @param key string
--- @param inherit boolean|nil
--- @return string|nil
function Node:get_property(key, inherit)
	if inherit == nil then
		inherit = true
	end
	local normalized = string.upper(key)
	if self.properties[normalized] ~= nil then
		return self.properties[normalized]
	end
	if self.properties[key] ~= nil then
		return self.properties[key]
	end
	if inherit and self.parent and self.parent.get_property then
		return self.parent:get_property(key, inherit)
	end
	return nil
end

--- Retrieve all active tags including hierarchical ancestors.
--- @param inherit boolean|nil
--- @return table
function Node:get_tags(inherit)
	if inherit == nil then
		inherit = true
	end
	local tag_set = {}
	local result = {}
	for _, tag in ipairs(self.tags) do
		if not tag_set[tag] then
			tag_set[tag] = true
			table.insert(result, tag)
		end
	end
	if inherit and self.parent and self.parent.get_tags then
		local parent_tags = self.parent:get_tags(inherit)
		for _, tag in ipairs(parent_tags) do
			if not tag_set[tag] then
				tag_set[tag] = true
				table.insert(result, tag)
			end
		end
	end
	return result
end

return Node
