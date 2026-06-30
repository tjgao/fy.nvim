local M = {}

local function clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

local function truncate(text, max_cols)
    if max_cols <= 0 then
        return ""
    end
    if vim.fn.strdisplaywidth(text) <= max_cols then
        return text
    end

    local ellipsis = "..."
    local out = text
    local ellipsis_w = vim.fn.strdisplaywidth(ellipsis)
    while #out > 0 and vim.fn.strdisplaywidth(out) + ellipsis_w > max_cols do
        out = out:gsub("[\128-\191]*.$", "")
    end
    return out .. ellipsis
end

local function display_level(level)
    if level == "WARN" then
        return "WARNING"
    end
    return level
end

local function format_text(entry)
    local msg = tostring(entry.msg or ""):gsub("\r", "")
    local lines = vim.split(msg, "\n", { plain = true })
    if #lines == 0 then
        lines = { "" }
    end
    if entry.title and entry.title ~= "" then
        table.insert(lines, 1, string.format("[%s]", tostring(entry.title)))
    end
    return lines
end

function M.new(ctx)
    local entries = {}

    local function get_history_config()
        local config = ctx.get_config().history or {}
        return {
            limit = tonumber(config.limit) or 200,
            width = tonumber(config.width) or 0.70,
            height = tonumber(config.height) or 0.60,
            border = config.border or "rounded",
            title = config.title or " Notification History ",
            padding = {
                top = math.max(0, tonumber(config.padding and config.padding.top) or 0),
                right = math.max(0, tonumber(config.padding and config.padding.right) or 0),
                bottom = math.max(0, tonumber(config.padding and config.padding.bottom) or 0),
                left = math.max(0, tonumber(config.padding and config.padding.left) or 0),
            },
        }
    end

    local function add(level_name, msg, opts)
        local cfg = get_history_config()
        entries[#entries + 1] = {
            ts = os.date("%m/%d %H:%M"),
            level = level_name,
            title = opts and opts.title or nil,
            msg = tostring(msg),
        }

        local overflow = #entries - cfg.limit
        if overflow > 0 then
            for _ = 1, overflow do
                table.remove(entries, 1)
            end
        end
    end

    local function clear()
        entries = {}
    end

    local function list()
        return vim.deepcopy(entries)
    end

    local function show(opts)
        opts = opts or {}
        local cfg = get_history_config()
        local ed = ctx.editor_size()
        local width_ratio = clamp(cfg.width, 0.30, 0.95)
        local height_ratio = clamp(cfg.height, 0.20, 0.95)

        local win_w = clamp(math.floor(ed.width * width_ratio), 50, ed.width - 4)
        local win_h = clamp(math.floor(ed.height * height_ratio), 8, ed.height - 4)
        local row = math.floor((ed.height - win_h) / 2)
        local col = math.floor((ed.width - win_w) / 2)

        local bufnr = ctx.api.nvim_create_buf(false, true)
        ctx.set_buf_option(bufnr, "filetype", "fy_history")
        ctx.set_buf_option(bufnr, "modifiable", true)

        local lines = {}
        local hls = {}
        local pad_top = cfg.padding.top
        local pad_right = cfg.padding.right
        local pad_bottom = cfg.padding.bottom
        local pad_left = cfg.padding.left

        local inner_w = math.max(1, win_w - 2 - pad_left - pad_right)
        local left_pad = string.rep(" ", pad_left)
        local right_pad = string.rep(" ", pad_right)
        local function with_side_padding(text)
            return left_pad .. text .. right_pad
        end

        local max_level_len = 7
        if #entries == 0 then
            lines[1] = with_side_padding(truncate("No notifications yet", inner_w))
            hls[1] = { 0, pad_left, -1, "NotifyDimText" }
        else
            local line_idx = 0
            for i = #entries, 1, -1 do
                local entry = entries[i]
                local lvl_name = entry.level or "INFO"
                local lvl_label = display_level(lvl_name)
                local entry_lines = format_text(entry)
                local prefix = string.format("%s  %-" .. max_level_len .. "s  ", entry.ts, lvl_label)
                local continuation_prefix = string.rep(" ", #prefix)
                local level_hl = (ctx.get_config().highlights[lvl_name] or ctx.get_config().highlights.INFO)
                for idx, text in ipairs(entry_lines) do
                    local line_prefix = idx == 1 and prefix or continuation_prefix
                    lines[#lines + 1] = with_side_padding(line_prefix .. text)

                    if idx == 1 then
                        hls[#hls + 1] = { line_idx, pad_left + 0, pad_left + 11, "NotifyDimText" }
                        hls[#hls + 1] = { line_idx, pad_left + 13, pad_left + 13 + max_level_len, level_hl.title }
                    end
                    hls[#hls + 1] = { line_idx, pad_left + #line_prefix, -1, level_hl.body }
                    line_idx = line_idx + 1
                end
            end
        end

        if pad_top > 0 or pad_bottom > 0 then
            local padded = {}
            local blank = with_side_padding(string.rep(" ", inner_w))
            for _ = 1, pad_top do
                padded[#padded + 1] = blank
            end
            for _, line in ipairs(lines) do
                padded[#padded + 1] = line
            end
            for _ = 1, pad_bottom do
                padded[#padded + 1] = blank
            end
            for _, hl in ipairs(hls) do
                hl[1] = hl[1] + pad_top
            end
            lines = padded
        end

        ctx.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        ctx.set_buf_option(bufnr, "modifiable", false)

        local ns = ctx.api.nvim_create_namespace("fy_notify_history")
        ctx.apply_highlights(bufnr, ns, hls)

        local winnr = ctx.api.nvim_open_win(bufnr, true, {
            relative = "editor",
            row = row,
            col = col,
            width = win_w,
            height = win_h,
            style = "minimal",
            border = opts.border or cfg.border,
            title = opts.title or cfg.title,
            title_pos = "center",
            noautocmd = true,
        })

        ctx.set_win_option(winnr, "winhl", "Normal:NotifyBackground,FloatBorder:NotifyINFOBorder")
        ctx.set_win_option(winnr, "wrap", vim.o.wrap)
        ctx.set_win_option(winnr, "cursorline", true)

        local close_window = function()
            if winnr and ctx.api.nvim_win_is_valid(winnr) then
                ctx.api.nvim_win_close(winnr, true)
            end
        end

        vim.keymap.set("n", "q", close_window, { buffer = bufnr, nowait = true, silent = true })
        vim.keymap.set("n", "<Esc>", close_window, { buffer = bufnr, nowait = true, silent = true })

        return { bufnr = bufnr, winnr = winnr }
    end

    return {
        add = add,
        clear = clear,
        list = list,
        show = show,
    }
end

return M
