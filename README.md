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
```

Direct call is also supported:

```lua
require("fy")("hello", vim.log.levels.INFO)
```

## Options

`setup()` accepts the same options as the internal defaults in `lua/fy/init.lua`.

- `override_vim_notify` (boolean, default `true`)
- `timeout`, `vacant_timeout`, `max_height`
- `padding`, `margin`, `gap`
- `animate`, `fps`, `animation`
- `icons`, `highlights`
