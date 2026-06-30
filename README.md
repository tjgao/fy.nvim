# fy.nvim

A lightweight notification renderer for Neovim with smooth stack animations.

## Install

Use your plugin manager and load as `fy.nvim`.

## Usage

```lua
local fy = require("fy")

fy.setup({
    override_vim_notify = true,
    timeout = 3000,
})

local h = fy.notify("Build started", vim.log.levels.INFO, { title = "CI" })
fy.notify("Build 50%", vim.log.levels.INFO, { title = "CI", replace = h, timeout = false })
h:close()

-- open in-memory history window (q / <Esc> to close)
fy.show_history()
```

Direct call is also supported:

```lua
require("fy")("hello", vim.log.levels.INFO)
```

## Configuration

`setup(opts)` supports the following keys.

### Top-level

- `override_vim_notify` (boolean, default `true`): replace global `vim.notify`.
- `timeout` (number|false, default `3000`): auto-dismiss delay in ms (`false` disables).
- `vacant_timeout` (number, default `2000`): keep closed slot reserved before collapse.
- `max_height` (number, default `25`): max body lines before footer (`↓ N more lines`).
- `padding` (table): `{ top = 0, right = 2, bottom = 0, left = 2 }`.
- `margin` (table): `{ top = 1, right = 2 }`.
- `gap` (number, default `1`): vertical space between notifications.
- `animate` (boolean, default `true`): enable enter/exit/collapse animations.
- `fps` (number, default `60`): animation framerate.
- `animation` (table): animation timing/effect options (see below).
- `history` (table): in-memory history window options (see below).
- `icons` (table): icon per level (`ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE`).
- `highlights` (table): highlight groups per level (`border`, `icon`, `title`, `body`, `footer`).

### History API

- `require("fy").show_history(opts?)`: open history float.
- `require("fy").clear_history()`: clear in-memory history.
- `require("fy").get_history()`: return history entries table.

Per-notification opt-out:

```lua
require("fy").notify("ephemeral", vim.log.levels.INFO, { history = false })
require("fy").notify("ephemeral", vim.log.levels.INFO, { hide_from_history = true })
```

For compatibility, both `history = false` (snacks.notifier style) and
`hide_from_history = true` are supported.

History row format is: `MM/DD HH:MM  LEVEL  text`.
`WARN` is displayed as `WARNING`.
Multi-line notifications are preserved in history (not collapsed to one line).

### `history` table

- `limit` (number, default `200`): max entries kept in memory.
- `width` (number, default `0.70`): float width ratio of editor columns.
- `height` (number, default `0.60`): float height ratio of editor lines.
- `padding` (table, default `{ top = 0, right = 1, bottom = 0, left = 1 }`): content padding inside history float.
- `border` (string|table, default `"rounded"`): border style passed to `nvim_open_win`.
- `title` (string, default `" Notification History "`): floating window title.

### `animation` table

- `enter_ms` (number, default `220`)
- `exit_ms` (number, default `180`)
- `collapse_ms` (number, default `220`)
- `enter` (string|string[]|false, default `{ "slide", "reveal" }`)
- `exit` (string|string[]|false, default `{ "slide", "reveal" }`)
- `slide_cols` (number|nil, default `nil`): override slide distance.
- `edge_cols` (number|nil, default `nil`): override reveal edge width.

`enter`/`exit` effects support: `fade`, `slide`, `reveal`.
You can pass:

- a `"+"`/`,`/`|` separated string, e.g. `"fade+slide"`
- a list, e.g. `{ "fade", "slide" }`
- `false` or `"none"` to disable effects

### Default config

```lua
require("fy").setup({
    override_vim_notify = true,
    timeout = 3000,
    vacant_timeout = 2000,
    max_height = 25,
    padding = { top = 0, right = 2, bottom = 0, left = 2 },
    margin = { top = 1, right = 2 },
    gap = 1,
    animate = true,
    fps = 60,
    animation = {
        enter_ms = 220,
        exit_ms = 180,
        collapse_ms = 220,
        enter = { "slide", "reveal" },
        exit = { "slide", "reveal" },
        slide_cols = nil,
        edge_cols = nil,
    },
    history = {
        limit = 200,
        width = 0.70,
        height = 0.60,
        padding = { top = 0, right = 1, bottom = 0, left = 1 },
        border = "rounded",
        title = " Notification History ",
    },
    icons = {
        ERROR = "󰅚",
        WARN = "󰀪",
        INFO = "󰋼",
        DEBUG = "",
        TRACE = "󰅩",
    },
    highlights = {
        ERROR = {
            border = "NotifyERRORBorder",
            icon = "NotifyERRORIcon",
            title = "NotifyERRORTitle",
            body = "NotifyERRORBody",
            footer = "NotifyERRORFooter",
        },
        WARN = {
            border = "NotifyWARNBorder",
            icon = "NotifyWARNIcon",
            title = "NotifyWARNTitle",
            body = "NotifyWARNBody",
            footer = "NotifyWARNFooter",
        },
        INFO = {
            border = "NotifyINFOBorder",
            icon = "NotifyINFOIcon",
            title = "NotifyINFOTitle",
            body = "NotifyINFOBody",
            footer = "NotifyINFOFooter",
        },
        DEBUG = {
            border = "NotifyDEBUGBorder",
            icon = "NotifyDEBUGIcon",
            title = "NotifyDEBUGTitle",
            body = "NotifyDEBUGBody",
            footer = "NotifyDEBUGFooter",
        },
        TRACE = {
            border = "NotifyTRACEBorder",
            icon = "NotifyTRACEIcon",
            title = "NotifyTRACETitle",
            body = "NotifyTRACEBody",
            footer = "NotifyTRACEFooter",
        },
    },
})
```
