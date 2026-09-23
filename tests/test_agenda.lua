local Agenda = require("org.agenda")
local Config = require("org.config")

local M = {}

--- Execute agenda collection unit tests.
--- @return boolean, string|nil
function M.run()
	local tmp_file = "/tmp/test_agenda_sample.org"
	local f = io.open(tmp_file, "w")
	assert(f ~= nil, "Unable to create test agenda file")
	f:write([[
#+TITLE: Test Agenda File
* TODO Urgent Task
  SCHEDULED: <2026-09-23 Wed>
* NEXT Client Deliverable
  DEADLINE: <2026-09-24 Thu>
* Unscheduled Idea
  Some notes
]])
	f:close()

	local old_files = Config.options.org_agenda_files
	Config.options.org_agenda_files = { "/tmp/test_agenda_sample.org" }

	local items = Agenda.collect_agenda_items("2026-09-24")
	Config.options.org_agenda_files = old_files
	os.remove(tmp_file)

	assert(#items == 2, "Expected 2 agenda items, got " .. tostring(#items))
	assert(items[1].title == "Urgent Task", "Item 1 title mismatch")
	assert(items[1].plan_type == "Scheduled", "Item 1 plan type mismatch")
	assert(items[2].title == "Client Deliverable", "Item 2 title mismatch")
	assert(items[2].plan_type == "Deadline", "Item 2 plan type mismatch")

	return true, "Agenda tests passed"
end

return M
