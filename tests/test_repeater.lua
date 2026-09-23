local Repeater = require("org.date.repeater")

local M = {}

--- Execute timestamp repeater parsing and advancement unit tests.
--- @return boolean, string|nil
function M.run()
	local rep_type, val, unit = Repeater.parse("2026-09-24 Thu +1w")
	assert(rep_type == "+", "Repeater type mismatch")
	assert(val == 1, "Repeater val mismatch")
	assert(unit == "w", "Repeater unit mismatch")

	local advanced = Repeater.advance("<2026-09-24 Thu +1w>")
	assert(advanced == "<2026-10-01 Thu +1w>", "Weekly repeater advance failed: " .. tostring(advanced))

	local advanced_daily = Repeater.advance("<2026-09-24 Thu .+2d>")
	assert(advanced_daily ~= nil and advanced_daily:find("%+2d"), "Daily relative advance failed: " .. tostring(advanced_daily))

	return true, "Repeater tests passed"
end

return M
