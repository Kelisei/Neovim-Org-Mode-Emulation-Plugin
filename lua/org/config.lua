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
			org_priority = "op",
			org_priority_prompt = "<leader>op",
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

--- Normalize key sequence preserving letter case while lowering bracketed tags.
--- @param key string
--- @return string
local function normalize_key(key)
	if key:match("^<.*>$") then
		return key:lower()
	end
	return key
end

--- Validate mappings and detect unintended key collisions.
--- @param mappings table
--- @return table<string, table<number, string>>
function M.validate_mappings(mappings)
	local collisions = {}
	local registered = {}

	local allowed_shared = {
		["<tab>"] = { org_cycle = true, org_table_align = true },
	}

	local org_maps = mappings.org or {}
	for action, key in pairs(org_maps) do
		if key and key ~= "" then
			local norm_key = normalize_key(key)
			if not registered[norm_key] then
				registered[norm_key] = {}
			end
			table.insert(registered[norm_key], action)
		end
	end

	for key, actions in pairs(registered) do
		if #actions > 1 then
			local is_allowed = true
			local allowed_set = allowed_shared[key]
			if allowed_set then
				for _, act in ipairs(actions) do
					if not allowed_set[act] then
						is_allowed = false
						break
					end
				end
			else
				is_allowed = false
			end

			if not is_allowed then
				collisions[key] = actions
				vim.notify(
					string.format("org.nvim: Keybinding collision detected for %q (actions: %s)", key, table.concat(actions, ", ")),
					vim.log.levels.WARN
				)
			end
		end
	end

	return collisions
end

--- Setup user options by merging with defaults and validating mappings.
--- @param user_opts table|nil
function M.setup(user_opts)
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_opts or {})
	M.validate_mappings(M.options.mappings)
	return M.options
end

return M
