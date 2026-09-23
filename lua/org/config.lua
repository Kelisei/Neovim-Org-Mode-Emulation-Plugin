local M = {}

M.defaults = {
	org_agenda_files = { "~/orgfiles/**/*" },
	org_default_notes_file = "~/orgfiles/refile.org",
	org_todo_keywords = { "TODO(t)", "NEXT(n)", "|", "DONE(d)", "CANCELED(c)" },
	org_priority_highest = "A",
	org_priority_lowest = "C",
	org_priority_default = "B",
	org_log_done = "time",
	org_log_into_drawer = "LOGBOOK",
	org_use_tag_inheritance = true,
	org_use_property_inheritance = true,
	org_startup_folded = "overview",
	org_babel_languages = {
		python = "python3",
		bash = "bash",
		sh = "sh",
		lua = "nvim -l",
		ruby = "ruby",
		node = "node",
		javascript = "node",
	},
	mappings = {
		global = {
			org_agenda = "<leader>oa",
			org_capture = "<leader>oc",
		},
		org = {
			org_cycle = "<Tab>",
			org_global_cycle = "<S-Tab>",
			org_todo = "t",
			org_todo_prev = "T",
			org_priority_up = "<C-Up>",
			org_priority_down = "<C-Down>",
			org_toggle_checkbox = "<C-c><C-c>",
			org_open_at_point = "<CR>",
			org_table_align = "<Tab>",
			org_table_eval_formula = "<leader>tfe",
			org_babel_execute = "<leader>oe",
			org_babel_tangle = "<leader>ot",
			org_schedule = "<leader>os",
			org_deadline = "<leader>od",
		},
	},
}

M.options = vim.deepcopy(M.defaults)

--- Setup user options by merging with defaults.
--- @param user_opts table|nil
function M.setup(user_opts)
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_opts or {})
	return M.options
end

return M
