# Neovim Org Mode Emulation Plugin (v0.1.0-beta)

Emacs Org mode implementation for Neovim.

---

## Technical Specifications

### Document Tree & Folding
Headlines parse hierarchically by leading asterisk depth. Subtrees track start line, content end line, and nested children.

```org
* Project Plan [1/2] [50%] :dev:urgent:
** DONE Architecture design
   CLOSED: [2026-09-23 Wed 11:00]
** NEXT Core parser [0/2]
   SCHEDULED: <2026-09-24 Thu> DEADLINE: <2026-09-30 Wed>
   - [ ] AST tokens
   - [ ] Error recovery
```

- `<Tab>` toggles subtree folding between `FOLDED`, `CHILDREN`, and `SUBTREE`.
- `<S-Tab>` toggles buffer folding between `OVERVIEW`, `CONTENTS`, and `SHOW ALL`.
- Checkboxes update parent headline statistics cookies `[/]` and `[%]` upon toggle (`<C-c><C-c>`).

---

### Task Management & State Machines
Buffers configure state sequences through `#+TODO:` declarations.

```org
#+TODO: TODO(t) NEXT(n) | DONE(d!) CANCELED(c@)
```

- Transitions into terminal states automatically manage `CLOSED: [timestamp]`.
- The `!` modifier appends a transition timestamp to `:LOGBOOK:`.
- The `@` modifier prompts for a note entry with timestamp and multi-line text input.
- `t` advances state sequence forward; `T` steps backward. Outside headlines, both keys retain Neovim character search motions.
- `<leader>ott` or `:OrgTodoPrompt` displays an interactive state selection menu.
- `op` cycles priority markers `[#A]`, `[#B]`, `[#C]`; `<leader>op` opens the prompt picker.

---

### Metadata, Properties & Drawers
Key-value metadata and timestamps are stored in named drawers:

```org
* Engine Module
  :PROPERTIES:
  :ID: 550e8400-e29b-41d4-a716-446655440000
  :CUSTOM_ID: core-engine
  :CATEGORY: backend
  :END:
  :LOGBOOK:
  CLOCK: [2026-09-23 Wed 09:00]--[2026-09-23 Wed 11:30] =>  2:30
  - Note taken on [2026-09-23 Wed 11:32] \\
    Refactored AST parsing cache
  :END:
```

- Properties are queryable and inherited down the headline hierarchy.
- `:OrgClockIn` (`<leader>oxi`) starts a running clock in `:LOGBOOK:`.
- `:OrgClockOut` (`<leader>oxo`) closes the active clock and calculates elapsed duration `=> HH:MM`.
- `:OrgAddNote` (`<leader>oz`) prompts and writes timestamped notes.
- `:OrgToggleInlineNotes` (`<leader>oi`) renders virtual text annotations at the end of headline lines for attached notes.

---

### Dates, Timestamps & Repeaters
Active timestamps trigger agenda scheduling; inactive timestamps serve as historical markers.

```org
* Sprint Review
  SCHEDULED: <2026-09-25 Fri 14:00 +1w>
  DEADLINE: <2026-09-25 Fri 18:00>
```

- Supported repeater syntax: `+1w` (standard interval), `++1m` (future recurrence catch-up), `.+2d` (restart from completion date).
- Setting a TODO with a repeater to `DONE` increments the timestamp to the next period and resets the state to `TODO`.

---

### Tables & Spreadsheet Engine
Tables format and recalculate formulas defined on `#+TBLFM:` lines.

```org
#+NAME: bill-of-materials
| ID | Item         | Units | Rate | Total |
|----+--------------+-------+------+-------|
| 01 | Engine Block |     2 |  150 |   300 |
| 02 | Spark Plug   |     4 |   15 |    60 |
|----+--------------+-------+------+-------|
|    | Sum          |       |      |   360 |
#+TBLFM: $5=$3*$4::@4$5=vsum(@2$5..@3$5)
```

- Pressing `<Tab>` aligns columns and advances the cursor to the next cell.
- Formulas support `@row$col` indexing, column expressions (`$5=$3*$4`), vector functions (`vsum`, `vmean`, `min`, `max`), and relative offsets (`@-1$2`).
- Recalculate via `<C-c><C-c>` on `#+TBLFM:`, `<leader>tfe`, or `:OrgTableEval`.

---

### Literate Programming (Org Babel)
Source code blocks execute in external processes and capture output back into the buffer.

```org
#+BEGIN_SRC python :var multiplier=10 :results table
data = [["Item", "Value"], ["Alpha", 1 * multiplier], ["Beta", 2 * multiplier]]
return data
#+END_SRC

#+RESULTS:
| Item  | Value |
| Alpha |    10 |
| Beta  |    20 |

#+BEGIN_SRC python :tangle build/out.py
def main():
    print("tangled code")
#+END_SRC
```

- Supported interpreters: Python, Bash, Sh, Lua, Ruby, Node.js.
- Parameter `:results`: `output`, `table`, `raw`, `silent`.
- Parameter `:var`: Injects variable declarations directly into the runtime context.
- `:OrgExecute` (`<leader>oe`) executes the block under the cursor.
- `:OrgTangle` (`<leader>ot`) parses blocks with `:tangle <path>` and writes target files.

---

### Links & Jump Stack Navigation
Links resolve URLs, file paths, IDs, custom IDs, and text anchors:

```org
[[https://github.com/Kelisei/Neovim-Org-Mode-Emulation-Plugin][Repository]]
[[file:~/notes.org::*Tasks]]
[[#core-engine][Jump to Custom ID]]
[[id:550e8400-e29b-41d4-a716-446655440000][Jump to ID]]
```

- `<CR>` follows the link target under cursor.
- Origin file, line, and column coordinates are recorded onto an internal jump stack and the Vim jumplist (`m'`).
- `:OrgBack` or `<leader>ob` pops from the jump stack and returns to the previous position.

---

## Installation

### lazy.nvim
```lua
{
  "Kelisei/Neovim-Org-Mode-Emulation-Plugin",
  ft = { "org" },
  keys = {
    { "<leader>oa", "<cmd>OrgAgenda<cr>", desc = "Org Agenda" },
    { "<leader>oc", "<cmd>OrgCapture<cr>", desc = "Org Capture" },
    { "<leader>on", "<cmd>OrgOpenNotes<cr>", desc = "Org Open Notes" },
    { "<leader>oN", "<cmd>OrgNotes<cr>", desc = "Org Notes Viewer" },
    { "<leader>o?", "<cmd>OrgShowCheatsheet<cr>", desc = "Org Cheatsheet" },
  },
  opts = {
    org_agenda_files = { "~/orgfiles/**/*" },
    org_default_notes_file = "~/orgfiles/refile.org",
    org_startup_folded = "overview",
    org_inline_notes = false,
  },
}
```

---

## Keybindings Configuration

Every command has a configurable key binding in `mappings.global` or `mappings.org`. Pass `false` or `""` to unmap any command.

```lua
require("org").setup({
  mappings = {
    global = {
      org_agenda = "<leader>oa",
      org_capture = "<leader>oc",
      org_open_notes = "<leader>on",
      org_notes = "<leader>oN",
      org_show_cheatsheet = "<leader>o?",
    },
    org = {
      org_cycle = "<Tab>",
      org_global_cycle = "<S-Tab>",
      org_todo = "t",
      org_todo_prev = "T",
      org_todo_prompt = "<leader>ott",
      org_priority = "op",
      org_priority_prompt = "<leader>op",
      org_toggle_checkbox = "<C-c><C-c>",
      org_open_at_point = "<CR>",
      org_link_back = "<leader>ob",
      org_toggle_inline_notes = "<leader>oi",
      org_table_align = "<Tab>",
      org_table_eval_formula = "<leader>tfe",
      org_babel_execute = "<leader>oe",
      org_babel_tangle = "<leader>ot",
      org_schedule = "<leader>os",
      org_deadline = "<leader>od",
      org_clock_in = "<leader>oxi",
      org_clock_out = "<leader>oxo",
      org_add_note = "<leader>oz",
      org_show_cheatsheet = "<leader>o?",
    },
  },
})
```

---

## Commands

| Command | Action |
| :--- | :--- |
| `:OrgShowCheatsheet` | Open floating command and keymap cheatsheet |
| `:OrgAgenda` | Open daily/weekly agenda view |
| `:OrgCapture` | Capture note with context back-link |
| `:OrgOpenNotes` | Open refile notes file in buffer |
| `:OrgNotes` | Open interactive captured notes list |
| `:OrgAddNote` | Add timestamped note to `:LOGBOOK:` |
| `:OrgToggleInlineNotes` | Toggle inline virtual text for headline notes |
| `:OrgBack` | Return to previous jump location |
| `:OrgTodo` | Advance TODO state forward |
| `:OrgTodoPrev` | Regress TODO state backward |
| `:OrgTodoPrompt` | Open interactive TODO state picker |
| `:OrgPriority` | Set or cycle priority level (`[#A]`, `[#B]`, `[#C]`) |
| `:OrgCycle` | Cycle subtree folding state |
| `:OrgGlobalCycle` | Cycle global document folding |
| `:OrgOpenAtPoint` | Follow link under cursor |
| `:OrgToggleCheckbox` | Toggle checkbox status under cursor |
| `:OrgExecute` | Execute code block under cursor |
| `:OrgTangle` | Tangle code blocks to destination files |
| `:OrgTableAlign` | Realign table under cursor |
| `:OrgTableEval` | Evaluate `#+TBLFM:` formulas in table |
| `:OrgClockIn` | Clock in on current headline |
| `:OrgClockOut` | Clock out on current headline |
| `:OrgSchedule` | Set or update `SCHEDULED:` date |
| `:OrgDeadline` | Set or update `DEADLINE:` date |

---

## Automated Test Suite

Headless verification covering parser, AST, tables, formulas, repeaters, Babel, links, and cheatsheet:

```bash
nvim --headless -u NONE --cmd "set rtp+=." -l tests/run_tests.lua
```

---

## License

GNU General Public License v3.0 (GPL-3.0). See [LICENSE](LICENSE) for details.
