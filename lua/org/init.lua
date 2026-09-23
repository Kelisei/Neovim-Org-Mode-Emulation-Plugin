local Config = require("org.config")
local DOM = require("org.dom")
local Fold = require("org.fold")
local Todo = require("org.todo")
local Drawer = require("org.drawer")
local List = require("org.list")
local Date = require("org.date")
local Link = require("org.link")
local Table = require("org.table")
local Babel = require("org.babel")
local Format = require("org.format")
local Agenda = require("org.agenda")

local M = {}

M.config = Config
M.dom = DOM
M.fold = Fold
M.todo = Todo
M.drawer = Drawer
M.list = List
M.date = Date
M.link = Link
M.table = Table
M.babel = Babel
M.format = Format
M.agenda = Agenda

--- Setup buffer-local keymaps for active Org Mode buffer.
--- @param bufnr number
local function setup_buffer_mappings(bufnr)
	local map = function(mode, lhs, rhs, desc)
		if lhs and lhs ~= "" then
			vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
		end
	end

	local m = Config.options.mappings.org
	local function handle_tab()
		local lnum = vim.fn.line(".")
		local s, e = Table.find_table_bounds(0, lnum)
		if s and e then
			Table.next_cell()
		else
			Fold.cycle()
		end
	end

	if m.org_cycle == m.org_table_align then
		map("n", m.org_cycle, handle_tab, "Tab: Next Table Cell / Cycle Fold")
	else
		map("n", m.org_cycle, Fold.cycle, "Cycle Subtree Fold")
		map("n", m.org_table_align, Table.next_cell, "Next Table Cell / Align")
	end
	map("n", m.org_global_cycle, Fold.global_cycle, "Cycle Global Folds")
	map("n", m.org_todo, Todo.cycle, "Cycle TODO State")
	map("n", m.org_priority_up, Todo.priority_up, "Increase Priority")
	map("n", m.org_priority_down, Todo.priority_down, "Decrease Priority")
	map("n", m.org_toggle_checkbox, List.toggle_checkbox, "Toggle Checkbox")
	map("n", m.org_open_at_point, Link.open_at_point, "Open Link at Point")
	map("n", m.org_table_eval_formula, Table.recalculate, "Eval Table Formula")
	map("n", m.org_babel_execute, Babel.execute_at_point, "Execute Source Block")
	map("n", m.org_babel_tangle, Babel.tangle_file, "Tangle Document Blocks")
	map("n", m.org_schedule, Date.prompt_scheduled, "Set Scheduled Date")
	map("n", m.org_deadline, Date.prompt_deadline, "Set Deadline Date")
end

--- Attach Org Mode features to an opened Org buffer.
--- @param bufnr number
function M.attach(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	Fold.attach(bufnr)
	Format.apply_buffer_syntax(bufnr)
	setup_buffer_mappings(bufnr)
end

--- Register user command with duplicate warning.
--- @param name string
--- @param command any
--- @param opts table
local function safe_create_command(name, command, opts)
	if vim.fn.exists(":" .. name) == 2 then
		vim.notify(
			string.format("org.nvim: User command :%s already exists and will be overwritten", name),
			vim.log.levels.WARN
		)
	end
	vim.api.nvim_create_user_command(name, command, opts)
end

--- Register user commands for interactive Org operations.
local function register_commands()
	safe_create_command("OrgAgenda", Agenda.open_agenda, { desc = "Open Org Agenda view" })
	safe_create_command("OrgCapture", Agenda.capture, { desc = "Capture quick Org note" })
	safe_create_command("OrgTangle", function()
		Babel.tangle_file(0)
	end, { desc = "Tangle Org source blocks" })
	safe_create_command("OrgExecute", function()
		Babel.execute_at_point(0, vim.fn.line("."))
	end, { desc = "Execute Org source block" })
	safe_create_command("OrgTableAlign", function()
		Table.align(0, vim.fn.line("."))
	end, { desc = "Align table under cursor" })
	safe_create_command("OrgTableEval", function()
		Table.recalculate(0, vim.fn.line("."))
	end, { desc = "Recalculate table formulas" })
	safe_create_command("OrgClockIn", function()
		Drawer.clock_in(0, vim.fn.line("."))
	end, { desc = "Clock in on current headline" })
	safe_create_command("OrgClockOut", function()
		Drawer.clock_out(0, vim.fn.line("."))
	end, { desc = "Clock out on current headline" })
	safe_create_command("OrgSchedule", function()
		Date.prompt_scheduled(0, vim.fn.line("."))
	end, { desc = "Set scheduled date on headline" })
	safe_create_command("OrgDeadline", function()
		Date.prompt_deadline(0, vim.fn.line("."))
	end, { desc = "Set deadline date on headline" })
	safe_create_command("OrgTodoPrompt", function()
		Todo.prompt_state(0, vim.fn.line("."))
	end, { desc = "Prompt fast TODO selection" })
end

--- Setup the org.nvim plugin with user configuration.
--- @param opts table|nil
function M.setup(opts)
	Config.setup(opts)
	register_commands()

	local gm = Config.options.mappings.global
	if gm.org_agenda and gm.org_agenda ~= "" then
		vim.keymap.set("n", gm.org_agenda, Agenda.open_agenda, { silent = true, desc = "Org Agenda" })
	end
	if gm.org_capture and gm.org_capture ~= "" then
		vim.keymap.set("n", gm.org_capture, Agenda.capture, { silent = true, desc = "Org Capture" })
	end

	local group = vim.api.nvim_create_augroup("OrgModeNvim", { clear = true })
	vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
		group = group,
		pattern = "*.org",
		callback = function(args)
			vim.bo[args.buf].filetype = "org"
			M.attach(args.buf)
		end,
	})
end

return M
