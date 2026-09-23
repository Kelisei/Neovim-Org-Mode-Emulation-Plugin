local Config = require("org.config")

local M = {}

--- Execute mapping and command collision validation unit tests.
--- @return boolean, string|nil
function M.run()
	local default_collisions = Config.validate_mappings(Config.defaults.mappings)
	assert(vim.tbl_count(default_collisions) == 0, "Default mappings should have 0 unintended collisions")

	local conflicting_mappings = {
		org = {
			org_todo = "<leader>xx",
			org_babel_execute = "<leader>xx",
		},
	}

	local detected = Config.validate_mappings(conflicting_mappings)
	assert(detected["<leader>xx"] ~= nil, "Collision for <leader>xx was not detected")
	assert(#detected["<leader>xx"] == 2, "Collision action count mismatch")

	local dummy_name = "OrgTestCollisionCmd"
	vim.api.nvim_create_user_command(dummy_name, function() end, {})
	assert(vim.fn.exists(":" .. dummy_name) == 2, "Pre-existing command check failed")
	vim.api.nvim_del_user_command(dummy_name)

	return true, "Validation tests passed"
end

return M
