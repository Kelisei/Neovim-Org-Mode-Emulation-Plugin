local Parser = require("org.dom.parser")
local Query = require("org.dom.query")

local M = {}

--- Execute parser unit tests.
--- @return boolean, string|nil
function M.run()
	local org_text = {
		"#+TITLE: Test Project",
		"#+AUTHOR: Jane Doe",
		"#+TODO: TODO NEXT | DONE CANCELED",
		"* Level 1 :work:project:",
		"  :PROPERTIES:",
		"  :ID: parent-123",
		"  :CATEGORY: dev",
		"  :END:",
		"** TODO [#A] Level 2 Task [1/2] [50%] :client:",
		"   SCHEDULED: <2026-09-24 Thu> DEADLINE: <2026-09-30 Wed>",
		"   :PROPERTIES:",
		"   :CUSTOM_ID: task-deliv",
		"   :END:",
		"   Some paragraph text here.",
		"*** NEXT Level 3 Child",
		"    More text.",
		"* Completed Section",
		"** DONE Closed Item",
		"   CLOSED: [2026-09-23 Wed 09:00]",
	}

	local root = Parser.parse(org_text, { "TODO", "NEXT", "|", "DONE", "CANCELED" })
	assert(#root.children == 2, "Root should have 2 children")

	local l1 = root.children[1]
	assert(l1.level == 1, "Level 1 heading level mismatch")
	assert(l1.title == "Level 1", "Level 1 title mismatch: " .. l1.title)
	assert(#l1.tags == 2, "Level 1 should have 2 tags")
	assert(l1.properties["ID"] == "parent-123", "Property ID mismatch")

	local l2 = l1.children[1]
	assert(l2.level == 2, "Level 2 heading level mismatch")
	assert(l2.todo == "TODO", "Level 2 todo mismatch: " .. tostring(l2.todo))
	assert(l2.priority == "A", "Level 2 priority mismatch")
	assert(l2.title == "Level 2 Task", "Clean title mismatch: " .. l2.title)
	assert(l2.planning.scheduled == "<2026-09-24 Thu>", "Scheduled mismatch")
	assert(l2.planning.deadline == "<2026-09-30 Wed>", "Deadline mismatch")
	assert(l2.properties["CUSTOM_ID"] == "task-deliv", "CUSTOM_ID mismatch")

	local inherited_cat = l2:get_property("CATEGORY", true)
	assert(inherited_cat == "dev", "Inherited property CATEGORY failed: " .. tostring(inherited_cat))

	local all_tags = l2:get_tags(true)
	local tag_map = {}
	for _, t in ipairs(all_tags) do
		tag_map[t] = true
	end
	assert(tag_map["client"] and tag_map["work"] and tag_map["project"], "Tag inheritance failed")

	local match_id = Query.find_by_id(root, "parent-123")
	assert(match_id == l1, "Query find_by_id failed")

	local match_custom = Query.find_by_custom_id(root, "task-deliv")
	assert(match_custom == l2, "Query find_by_custom_id failed")

	local work_items = Query.find_by_tag(root, "work", true)
	assert(#work_items >= 2, "Query find_by_tag with inheritance failed")

	return true, "Parser tests passed"
end

return M
