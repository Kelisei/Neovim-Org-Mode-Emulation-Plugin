local Properties = require("org.drawer.properties")
local DOM = require("org.dom")
local State = require("org.todo.state")

local M = {}

--- Set or replace tags on a specified headline.
--- @param bufnr number
--- @param headline_lnum number
--- @param tags table<number, string>
function M.set_tags(bufnr, headline_lnum, tags)
	local line = vim.api.nvim_buf_get_lines(bufnr, headline_lnum - 1, headline_lnum, false)[1]
	if not line or not line:match("^(%*+)%s+") then
		return
	end

	local clean_line = line:gsub("%s*:%S+:%s*$", "")
	local tag_str = ""
	if #tags > 0 then
		tag_str = " :" .. table.concat(tags, ":") .. ":"
	end
	local updated = clean_line .. tag_str
	vim.api.nvim_buf_set_lines(bufnr, headline_lnum - 1, headline_lnum, false, { updated })
	DOM.invalidate(bufnr)
end

--- Add a tag to a headline if not already present.
--- @param bufnr number
--- @param headline_lnum number
--- @param tag string
function M.add_tag(bufnr, headline_lnum, tag)
	local root = DOM.get(bufnr)
	local node = DOM.find_headline_at_line(root, headline_lnum)
	if not node then
		return
	end

	local tags = vim.deepcopy(node.tags)
	for _, t in ipairs(tags) do
		if t == tag then
			return
		end
	end
	table.insert(tags, tag)
	M.set_tags(bufnr, headline_lnum, tags)
end

--- Toggle tag presence on a headline.
--- @param bufnr number
--- @param headline_lnum number
--- @param tag string
function M.toggle_tag(bufnr, headline_lnum, tag)
	local root = DOM.get(bufnr)
	local node = DOM.find_headline_at_line(root, headline_lnum)
	if not node then
		return
	end

	local tags = {}
	local found = false
	for _, t in ipairs(node.tags) do
		if t == tag then
			found = true
		else
			table.insert(tags, t)
		end
	end
	if not found then
		table.insert(tags, tag)
	end
	M.set_tags(bufnr, headline_lnum, tags)
end

--- Retrieve active tags for a headline with optional hierarchical inheritance.
--- @param bufnr number
--- @param headline_lnum number
--- @param inherit boolean|nil
--- @return table
function M.get_tags(bufnr, headline_lnum, inherit)
	local root = DOM.get(bufnr)
	local node = DOM.find_headline_at_line(root, headline_lnum)
	if not node then
		return {}
	end
	return node:get_tags(inherit)
end

--- Clock in on the current headline, creating a running CLOCK line in LOGBOOK.
--- @param bufnr number|nil
--- @param headline_lnum number|nil
function M.clock_in(bufnr, headline_lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	headline_lnum = headline_lnum or vim.fn.line(".")

	local root = DOM.get(bufnr)
	local node = DOM.find_headline_at_line(root, headline_lnum)
	if not node then
		return
	end

	local target_lnum = node.range.start_line
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local d_start = nil
	local i = target_lnum + 1
	while i <= #lines do
		if lines[i]:match("^(%*+)%s+") then
			break
		end
		if lines[i]:match("^%s*:LOGBOOK:%s*$") then
			d_start = i
			break
		end
		i = i + 1
	end

	local ts = State.format_timestamp(false, true)
	local clock_line = string.format("  CLOCK: %s", ts)

	if d_start then
		vim.api.nvim_buf_set_lines(bufnr, d_start, d_start, false, { clock_line })
	else
		local insert_pos = target_lnum
		if lines[target_lnum + 1] and (lines[target_lnum + 1]:match("SCHEDULED:") or lines[target_lnum + 1]:match("DEADLINE:") or lines[target_lnum + 1]:match("CLOSED:")) then
			insert_pos = target_lnum + 1
		end
		local drawer = {
			"  :LOGBOOK:",
			clock_line,
			"  :END:",
		}
		vim.api.nvim_buf_set_lines(bufnr, insert_pos, insert_pos, false, drawer)
	end
	DOM.invalidate(bufnr)
end

--- Clock out on the current headline, closing the active CLOCK line in LOGBOOK with duration.
--- @param bufnr number|nil
--- @param headline_lnum number|nil
function M.clock_out(bufnr, headline_lnum)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	headline_lnum = headline_lnum or vim.fn.line(".")

	local root = DOM.get(bufnr)
	local node = DOM.find_headline_at_line(root, headline_lnum)
	if not node then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local end_ts = State.format_timestamp(false, true)

	for i = node.range.start_line + 1, node.range.end_line do
		local line = lines[i]
		if line:match("^(%*+)%s+") then
			break
		end
		local start_ts = line:match("^%s*CLOCK:%s*(%[[^%]]+%])%s*$")
		if start_ts then
			local closed_line = string.format("  CLOCK: %s--%s =>  0:00", start_ts, end_ts)
			vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { closed_line })
			DOM.invalidate(bufnr)
			break
		end
	end
end

M.set_property = Properties.set_property
M.get_property = Properties.get_property
M.remove_property = Properties.remove_property

return M
