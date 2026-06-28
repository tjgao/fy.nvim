local M = {}

local ellipsis = "…"
local ellipsis_w = vim.fn.strdisplaywidth(ellipsis)

local function truncate(text, max_cols)
    if vim.fn.strdisplaywidth(text) <= max_cols then
        return text
    end

    local out = text
    while #out > 0 and vim.fn.strdisplaywidth(out) + ellipsis_w > max_cols do
        out = out:gsub("[\128-\191]*.$", "")
    end
    return out .. ellipsis
end

function M.compute_inner_width(msg, title, lvl_name, config, editor_size)
    local ed = editor_size()
    local pad = config.padding.left + config.padding.right
    local icon = config.icons[lvl_name] or " "
    local max_inner = math.floor(ed.width * 0.30) - pad - 2

    local widest = 25
    if title and title ~= "" then
        widest = math.max(widest, vim.fn.strdisplaywidth(icon) + 1 + vim.fn.strdisplaywidth(title))
    end

    local raw_lines = vim.split(msg, "\n", { plain = true })
    local no_title = not (title and title ~= "")
    for i, raw in ipairs(raw_lines) do
        local prefix_w = (no_title and i == 1) and (vim.fn.strdisplaywidth(icon) + 1) or 0
        widest = math.max(widest, prefix_w + vim.fn.strdisplaywidth(raw))
    end

    return math.min(widest, max_inner)
end

function M.build_content(msg, lvl_name, opts, inner_w, config)
    local hl = config.highlights[lvl_name] or config.highlights.INFO
    local icon = config.icons[lvl_name] or " "
    local title = opts.title

    local pad_l = string.rep(" ", config.padding.left)
    local pad_r = string.rep(" ", config.padding.right)

    local lines = {}
    local hls = {}

    local raw_lines = vim.split(msg, "\n", { plain = true })
    local no_title = not (title and title ~= "")

    for idx, raw in ipairs(raw_lines) do
        local prefix = pad_l
        local icon_hl_end = nil
        if no_title and idx == 1 then
            prefix = pad_l .. icon .. " "
            icon_hl_end = config.padding.left + vim.fn.strdisplaywidth(icon)
        end
        local available = inner_w - (vim.fn.strdisplaywidth(prefix) - config.padding.left)
        local text = truncate(raw, available)
        local full_line = prefix .. text .. pad_r
        table.insert(lines, full_line)
        local line_idx = #lines - 1
        if icon_hl_end then
            table.insert(hls, { line_idx, config.padding.left, icon_hl_end, hl.icon })
            table.insert(hls, { line_idx, icon_hl_end + 1, -1, hl.body })
        else
            table.insert(hls, { line_idx, 0, -1, hl.body })
        end
    end

    local has_more = false
    local total_body = #lines
    if total_body > config.max_height then
        has_more = true
        local kept = {}
        for i = 1, config.max_height do
            kept[i] = lines[i]
        end
        hls = vim.tbl_filter(function(h)
            return h[1] < config.max_height
        end, hls)
        lines = kept

        local hidden = total_body - config.max_height
        local footer_text = string.format("↓ %d more line%s", hidden, hidden == 1 and "" or "s")
        local footer_line = pad_l .. truncate(footer_text, inner_w) .. pad_r
        table.insert(lines, footer_line)
        table.insert(hls, { #lines - 1, 0, -1, hl.footer })
    end

    return lines, hls, has_more
end

function M.make_win_title(title, lvl_name, inner_w, config)
    local icon = config.icons[lvl_name] or " "
    local hl = config.highlights[lvl_name] or config.highlights.INFO
    if title and title ~= "" then
        local text = truncate(icon .. " " .. title, inner_w)
        return { { " " .. text .. " ", hl.title } }
    end
    return { { " " .. icon .. " ", hl.icon } }
end

function M.make_border(lvl_name, config)
    local hl = config.highlights[lvl_name] or config.highlights.INFO
    local function c(char)
        return { char, hl.border }
    end
    return {
        c("╭"),
        c("─"),
        c("╮"),
        c("│"),
        c("╯"),
        c("─"),
        c("╰"),
        c("│"),
    }
end

return M
