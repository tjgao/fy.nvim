local api = vim.api

local M = {}

function M.editor_size()
    return { width = vim.o.columns, height = vim.o.lines }
end

function M.layout_rows(stack, config)
    local ed = M.editor_size()
    local rows = {}
    local y = config.margin.top
    for i, handle in ipairs(stack) do
        local win_w = handle._win_width or 30
        local col = ed.width - win_w - config.margin.right - 2
        rows[i] = { row = y, col = col }
        y = y + (handle._win_height or 3) + config.gap
    end
    return rows
end

function M.reflow(stack, config)
    local rows = M.layout_rows(stack, config)
    for i, handle in ipairs(stack) do
        local pos = rows[i]
        if pos and handle._winnr and api.nvim_win_is_valid(handle._winnr) and not handle._animating then
            api.nvim_win_set_config(handle._winnr, {
                relative = "editor",
                row = pos.row,
                col = pos.col,
            })
        end
    end
end

function M.win_move(winnr, row, col)
    if row == nil or col == nil then
        return
    end
    pcall(api.nvim_win_set_config, winnr, {
        relative = "editor",
        row = math.floor(tonumber(row) or 0),
        col = math.floor(tonumber(col) or 0),
    })
end

function M.set_buf_option(bufnr, name, value)
    pcall(api.nvim_set_option_value, name, value, { buf = bufnr })
end

function M.set_win_option(winnr, name, value)
    pcall(api.nvim_set_option_value, name, value, { win = winnr })
end

function M.get_win_option(winnr, name, fallback)
    local ok, value = pcall(api.nvim_get_option_value, name, { win = winnr })
    if ok then
        return value
    end
    return fallback
end

function M.apply_highlights(bufnr, ns, hls)
    api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for _, h in ipairs(hls) do
        local line, cs, ce, group = h[1], h[2], h[3], h[4]
        local text = lines[line + 1] or ""
        local end_col = ce == -1 and #text or ce
        pcall(api.nvim_buf_set_extmark, bufnr, ns, line, cs, {
            end_row = line,
            end_col = end_col,
            hl_group = group,
        })
    end
end

return M
