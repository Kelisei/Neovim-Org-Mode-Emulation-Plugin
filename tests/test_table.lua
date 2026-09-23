local Align = require("org.table.align")
local Formula = require("org.table.formula")

local M = {}

--- Execute table alignment and formula calculation unit tests.
--- @return boolean, string|nil
function M.run()
	local raw = {
		"| ID | Item | Units | Rate | Total |",
		"|----+----+----+----+----|",
		"| 01 | Engine Block | 2 | 150 | 0 |",
		"| 02 | Spark Plug | 4 | 15 | 0 |",
		"|----+----+----+----+----|",
		"| | Sum | | | 0 |",
	}

	local tblfm = "$5=$3*$4::@4$5=vsum(@2$5..@3$5)"
	local evaluated = Formula.evaluate_tblfm(raw, tblfm)

	local r3 = Align.parse_row_cells(evaluated[3])
	assert(r3[5] == "300", "Row 1 total calculation failed: expected 300, got " .. tostring(r3[5]))

	local r4 = Align.parse_row_cells(evaluated[4])
	assert(r4[5] == "60", "Row 2 total calculation failed: expected 60, got " .. tostring(r4[5]))

	local r6 = Align.parse_row_cells(evaluated[6])
	assert(r6[5] == "360", "Row 3 vsum calculation failed: expected 360, got " .. tostring(r6[5]))

	local aligned, widths = Align.align_table(raw)
	assert(#aligned == #raw, "Aligned row count mismatch")
	assert(widths[2] >= 12, "Column width calculation failed")

	return true, "Table and formula tests passed"
end

return M
