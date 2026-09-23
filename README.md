# org.nvim

Full Emacs Org Mode for Neovim written from scratch in pure, idiomatic Lua.

`org.nvim` provides an authentic Emacs Org Mode experience in Neovim: hierarchical document structures, TODO lifecycle workflows, property and tag inheritance, scheduling with repeaters, table auto-alignment with `#+TBLFM:` formula calculations, literate programming (Org Babel) with in-buffer code execution and tangling, and interactive agenda views.

---

## Features

### 1. Document Structure & Hierarchies
- **Headings & Subtrees:** Multi-level headlines (`*`, `**`, `***`) representing structured nodes.
- **3-State Folding:** Cycle subtree folding states via `<Tab>` (`FOLDED` -> `CHILDREN` -> `SUBTREE`) and buffer-wide folds via `<S-Tab>` (`OVERVIEW` -> `CONTENTS` -> `SHOW ALL`).
- **In-Buffer Settings:** Case-insensitive `#+TITLE:`, `#+AUTHOR:`, `#+DATE:`, `#+TODO:`, `#+TAGS:`, `#+STARTUP:`.
- **Lists & Checkboxes:** Unordered (`-`, `+`, `*`), ordered (`1.`, `1)`), checkboxes (`[ ]`, `[-]`, `[X]`), and auto-updating progress cookie statistics (`[/]` and `[%]`).

### 2. Task Management & Workflows (TODOs)
- **State Sequences:** Configurable active and terminal states (`TODO NEXT | DONE CANCELED`) with sequence navigation.
- **State Selection:** Fast selection menu (`:OrgTodoPrompt`) with state shortcuts (`TODO(t) NEXT(n) | DONE(d) CANCELED(c)`).
- **Logbook Notes & Timestamps:** `@` flag prompts for closing note; `!` flag inserts state transition timestamps into `:LOGBOOK:`.
- **Closed Dates:** Automatic `CLOSED: [YYYY-MM-DD Day HH:MM]` management on terminal state transitions.
- **Priorities:** Cycle priority levels `[#A]`, `[#B]`, `[#C]` with `<C-Up>` and `<C-Down>`.

### 3. Metadata, Properties & Drawers
- **Generic Drawers:** Structured hidden data blocks (`:NAME:` to `:END:`).
- **Property Drawers:** Key-value pairs (`:KEY: Value`) in `:PROPERTIES:`.
- **Property Inheritance:** Child headlines inherit properties from parent headlines unless overridden.
- **Tags & Tag Inheritance:** Headline tags (`:work:urgent:`) inherited by child subtrees; tag query filtering.
- **Time Clocking:** `:OrgClockIn` and `:OrgClockOut` logging timestamps in `:LOGBOOK:`.

### 4. Dates, Timestamps & Scheduling
- **Timestamps:** Active (`<YYYY-MM-DD Day>`) and inactive (`[YYYY-MM-DD Day]`) formats with optional times and ranges.
- **Repeaters:** Full support for `+1w` (weekly), `++1m` (monthly from current date), and `.+1d` (completion relative).
- **Planning Lines:** `SCHEDULED:` and `DEADLINE:` management immediately beneath headlines.

### 5. Links & References
- **Syntax:** Inline links `[[URI][Description]]` and bare links `[[URI]]`.
- **Protocols & Targets:**
  - `https://` and `http://` URLs (opened via system browser)
  - `file:path` and `file:path::*Heading` (opened inside Neovim)
  - `#custom-id` jumping to `:CUSTOM_ID:` property
  - `id:UUID` jumping to `:ID:` property
  - Dedicated anchor targets `<<anchor-name>>`
- **Follow Link:** `<CR>` follows link under cursor.

### 6. Tables & Formulas
- **Grid Layout:** Tables formatted with `|` and horizontal separators `|---+---|`.
- **Auto-Alignment:** Formats columns, cell widths, and numerical values on `<Tab>`.
- **Formula Engine (`#+TBLFM:`):**
  - Coordinates: `@row$col` (data row indexing), column targets (`$5=$3*$4`), relative coordinates (`@-1$2`).
  - Coordinate ranges: `@2$5..@3$5`.
  - Built-in functions: `vsum(...)`, `vmean(...)`, `sum(...)`, `min`, `max`, `abs`, `round`.
  - Multiple formula rules chained via `::`.
  - Recalculate table via `<leader>tfe` or `:OrgTableEval`.

### 7. Literate Programming (Org Babel)
- **Source Blocks:** `#+BEGIN_SRC <language> ... #+END_SRC`.
- **Interactive Execution:** `:OrgExecute` or `<leader>oe` runs code block and captures stdout into `#+RESULTS:`.
- **Header Arguments:**
  - `:results output|table|silent|raw`
  - `:var name=value` injected as language variables
  - `:tangle <file_path>` for literate file generation
- **Supported Interpreters:** Python, Bash, Sh, Lua, Ruby, Node.js.
- **Tangling:** `:OrgTangle` or `<leader>ot` extracts and writes code blocks to target paths on disk.

### 8. Text Formatting & Entities
- **Inline Styling:** `*bold*`, `/italic/`, `_underline_`, `+strikethrough+`, `~code~`, `=verbatim=`.
- **Footnotes:** References (`[fn:1]`, `[fn:label]`), definitions (`[fn:1] text`), and bi-directional jumping.

### 9. Interactive Agenda & Quick Capture
- **Agenda View:** Scans configured agenda files, compiles daily/weekly task schedules, deadlines, priorities, and allows one-key jump (`<CR>`).
- **Quick Capture:** `:OrgCapture` or `<leader>oc` appends notes directly to refile notebook.

---

## Installation

### Using lazy.nvim
```lua
{
  "francisco/org.nvim",
  ft = { "org" },
  keys = {
    { "<leader>oa", "<cmd>OrgAgenda<cr>", desc = "Org Agenda" },
    { "<leader>oc", "<cmd>OrgCapture<cr>", desc = "Org Capture" },
  },
  opts = {
    org_agenda_files = { "~/orgfiles/**/*" },
    org_default_notes_file = "~/orgfiles/refile.org",
  },
}
```

---

## Default Keybindings

| Key | Context | Action |
| :--- | :--- | :--- |
| `<Tab>` | Headline | Cycle subtree fold (`FOLDED` -> `CHILDREN` -> `SUBTREE`) |
| `<S-Tab>` | Normal | Cycle buffer folds (`OVERVIEW` -> `CONTENTS` -> `ALL`) |
| `t` | Headline | Cycle TODO state forward |
| `op` | Headline | Cycle priority (`C` -> `B` -> `A` -> none) |
| `<leader>op` | Headline | Fast interactive priority picker |
| `<C-c><C-c>` | Context | Toggle checkbox / Recalculate table formulas |
| `<CR>` | Context | Follow link under cursor / Recalculate table on `#+TBLFM:` |
| `<Tab>` | Table | Jump to next cell and re-align table |
| `<leader>tfe` / `<leader>of` | Table | Evaluate table formulas (`#+TBLFM:`) |
| `<leader>oe` | Source Block | Execute code block (Org Babel) |
| `<leader>ot` | Normal | Tangle code blocks to disk |
| `<leader>os` | Headline | Set scheduled date |
| `<leader>od` | Headline | Set deadline date |
| `<leader>oz` | Headline | Add timestamped note to LOGBOOK drawer |
| `<leader>oa` | Global | Open Org Agenda view |
| `<leader>oc` | Global | Quick capture note with origin link and selection |
| `<leader>on` | Global | Open default notes file (refile.org) |

---

## Commands

- `:OrgAgenda` - Open interactive agenda view.
- `:OrgCapture` - Prompt and append note to refile file.
- `:OrgOpenNotes` - Open default notes file in buffer.
- `:OrgNotes` - Open interactive captured notes viewer.
- `:OrgAddNote` - Prompt and add note to current headline LOGBOOK drawer.
- `:OrgExecute` - Execute source block under cursor.
- `:OrgTangle` - Extract code blocks to configured tangle files.
- `:OrgTableAlign` - Format and align table under cursor.
- `:OrgTableEval` - Recalculate table formulas in place.
- `:OrgClockIn` - Start clock timer on current headline.
- `:OrgClockOut` - Stop clock timer and log elapsed time.
- `:OrgSchedule` - Set or edit scheduled date.
- `:OrgDeadline` - Set or edit deadline date.
- `:OrgTodoPrompt` - Fast interactive TODO state picker.
- `:OrgPriority` - Set or prompt priority picker.

---

## Running Tests

`org.nvim` includes a full headless test suite covering all modules:

```bash
nvim --headless -u NONE --cmd "set rtp+=." -l tests/run_tests.lua
```

---

## License

MIT License.
