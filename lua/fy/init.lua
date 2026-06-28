local api = vim.api
local uv = vim.uv or vim.loop

local config_data = require("fy.config")
local levels = require("fy.levels")
local highlights = require("fy.highlights")
local layout = require("fy.layout")
local content = require("fy.content")
local history_factory = require("fy.history")
local animation_factory = require("fy.animation")
local handle_factory = require("fy.handle")

local M = {}

local config = vim.deepcopy(config_data.default)
local stack = {}
local next_id = 0

local function get_config()
    return config
end

local function layout_rows()
    return layout.layout_rows(stack, config)
end

local function reflow()
    layout.reflow(stack, config)
end

local animation = animation_factory.new({
    api = api,
    uv = uv,
    stack = stack,
    get_config = get_config,
    layout_rows = layout_rows,
    reflow = reflow,
    win_move = layout.win_move,
    set_win_option = layout.set_win_option,
    get_win_option = layout.get_win_option,
})

local Handle = handle_factory.new({
    api = api,
    uv = uv,
    stack = stack,
    get_config = get_config,
    editor_size = layout.editor_size,
    layout_rows = layout_rows,
    reflow = reflow,
    win_move = layout.win_move,
    set_buf_option = layout.set_buf_option,
    set_win_option = layout.set_win_option,
    apply_highlights = layout.apply_highlights,
    animation = animation,
    content = content,
})

local history = history_factory.new({
    api = api,
    get_config = get_config,
    editor_size = layout.editor_size,
    set_buf_option = layout.set_buf_option,
    set_win_option = layout.set_win_option,
    apply_highlights = layout.apply_highlights,
})

---@param msg string
---@param level? number|string
---@param opts? { title?: string, timeout?: number|false, replace?: table, history?: boolean, hide_from_history?: boolean }
---@return table
function M.notify(msg, level, opts)
    opts = opts or {}
    local lvl_name = levels.name(level or vim.log.levels.INFO)

    if opts.history ~= false and opts.hide_from_history ~= true then
        history.add(lvl_name, msg, opts)
    end

    if opts.replace and not opts.replace._closed then
        opts.replace:update(msg, opts)
        return opts.replace
    end

    local inner_w = content.compute_inner_width(msg, opts.title, lvl_name, config, layout.editor_size)
    local win_w = inner_w + config.padding.left + config.padding.right
    local lines = content.build_content(msg, lvl_name, opts, inner_w, config)
    local win_h = math.min(#lines, config.max_height + 3)

    next_id = next_id + 1
    local handle = setmetatable({
        id = next_id,
        _lvl_name = lvl_name,
        _opts = opts,
        _win_width = win_w,
        _win_height = win_h + 2,
    }, Handle)

    table.insert(stack, handle)

    vim.schedule(function()
        handle:_open(msg, lvl_name, opts)
    end)

    return handle
end

function M.show_history(opts)
    return history.show(opts)
end

function M.clear_history()
    history.clear()
end

function M.get_history()
    return history.list()
end

function M.dismiss_all()
    local handles = {}
    for _, handle in ipairs(stack) do
        table.insert(handles, handle)
    end
    for _, handle in ipairs(handles) do
        handle:close()
    end
end

---@param opts? table
function M.setup(opts)
    opts = opts or {}
    local override_vim_notify = opts.override_vim_notify
    if override_vim_notify == nil then
        override_vim_notify = true
    end

    config = vim.tbl_deep_extend("force", config_data.default, opts)
    highlights.setup(config)

    api.nvim_create_autocmd("ColorScheme", {
        group = api.nvim_create_augroup("NotifyHighlights", { clear = true }),
        callback = function()
            highlights.setup(config)
        end,
    })

    api.nvim_create_autocmd("VimResized", {
        group = api.nvim_create_augroup("NotifyResize", { clear = true }),
        callback = reflow,
    })

    if override_vim_notify then
        ---@diagnostic disable-next-line: duplicate-set-field
        vim.notify = function(notify_msg, notify_level, notify_opts)
            return M.notify(notify_msg, notify_level, notify_opts)
        end
    end
end

setmetatable(M, {
    __call = function(_, ...)
        return M.notify(...)
    end,
})

return M
