local api = vim.api

local M = {}

local function get_hl_attr(name, attr)
    local ok, hl = pcall(api.nvim_get_hl, 0, { name = name, link = false })
    if ok and hl and hl[attr] then
        return hl[attr]
    end
end

local function resolve_fg(groups, fallback)
    for _, group in ipairs(groups) do
        local value = get_hl_attr(group, "fg")
        if value then
            return value
        end
    end
    return fallback
end

local function resolve_bg(groups, fallback)
    for _, group in ipairs(groups) do
        local value = get_hl_attr(group, "bg")
        if value then
            return value
        end
    end
    return fallback
end

local level_accent_groups = {
    ERROR = { "DiagnosticSignError", "DiagnosticError", "DiagnosticVirtualTextError" },
    WARN = { "DiagnosticSignWarn", "DiagnosticWarn", "DiagnosticVirtualTextWarn" },
    INFO = { "DiagnosticSignInfo", "DiagnosticInfo", "DiagnosticVirtualTextInfo" },
    DEBUG = { "DiagnosticSignHint", "DiagnosticHint", "DiagnosticVirtualTextHint" },
    TRACE = { "Comment" },
}

local level_fallbacks = {
    ERROR = 0xf87171,
    WARN = 0xfbbf24,
    INFO = 0x4ade80,
    DEBUG = 0xa78bfa,
    TRACE = 0x94a3b8,
}

function M.setup(config)
    local bg = resolve_bg({ "Normal", "NormalFloat" }, 0x1e1e2e)
    local fg_body = resolve_fg({ "NormalFloat", "Normal" }, 0xcdd6f4)
    local fg_dim = resolve_fg({ "Comment" }, 0x6c7086)

    for level, groups in pairs(level_accent_groups) do
        local accent = resolve_fg(groups, level_fallbacks[level])
        local hl = config.highlights[level]
        api.nvim_set_hl(0, hl.border, { fg = accent, bg = bg, default = false })
        api.nvim_set_hl(0, hl.icon, { fg = accent, bg = bg, bold = true, default = false })
        api.nvim_set_hl(0, hl.title, { fg = accent, bg = bg, bold = true, default = false })
        api.nvim_set_hl(0, hl.body, { fg = fg_body, bg = bg, default = false })
        api.nvim_set_hl(0, hl.footer, { fg = fg_dim, bg = bg, italic = true, default = false })
    end

    api.nvim_set_hl(0, "NotifyBackground", { bg = bg, default = false })
    api.nvim_set_hl(0, "NotifyDimText", { fg = fg_dim, bg = bg, default = false })
end

return M
