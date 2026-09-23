local Cheatsheet = require("org.cheatsheet")
local Config = require("org.config")

local M = {}

--- Test cheatsheet generation, custom key overrides, and floating window lifecycle.
--- @return boolean, string|nil
function M.run()
	Config.setup({})
	local default_lines = Cheatsheet.generate_cheatsheet_lines()
	local content = table.concat(default_lines, "\n")

	assert(content:find("ORG MODE CHEATSHEET & KEYMAPS"), "Header missing in cheatsheet")
	assert(content:find(":OrgAgenda"), "Command :OrgAgenda missing in cheatsheet")
	assert(content:find(":OrgSchedule"), "Command :OrgSchedule missing in cheatsheet")
	assert(content:find("<leader>os"), "Default binding <leader>os missing")

	Config.setup({
		mappings = {
			org = {
				org_schedule = "<leader>custom_sched",
				org_deadline = false,
			},
		},
	})

	local custom_lines = Cheatsheet.generate_cheatsheet_lines()
	local custom_content = table.concat(custom_lines, "\n")

	assert(custom_content:find("<leader>custom_sched"), "Custom mapping <leader>custom_sched not found in cheatsheet")
	assert(custom_content:find("%[unmapped%]"), "Disabled mapping [unmapped] not found in cheatsheet")

	Config.setup({})

	Cheatsheet.show_cheatsheet()
	local cur_buf = vim.api.nvim_get_current_buf()
	local cur_win = vim.api.nvim_get_current_win()
	assert(vim.bo[cur_buf].filetype == "orgcheatsheet", "Buffer filetype mismatch: " .. vim.bo[cur_buf].filetype)
	assert(vim.api.nvim_win_is_valid(cur_win), "Cheatsheet window is not valid")

	vim.api.nvim_win_close(cur_win, true)
	assert(not vim.api.nvim_win_is_valid(cur_win), "Cheatsheet window failed to close")

	return true, "Cheatsheet tests passed"
end

return M
