local M = {}

M.default = {
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
}

return M
