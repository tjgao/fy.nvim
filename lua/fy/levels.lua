local M = {}

local level_names = {
    [vim.log.levels.ERROR] = "ERROR",
    [vim.log.levels.WARN] = "WARN",
    [vim.log.levels.INFO] = "INFO",
    [vim.log.levels.DEBUG] = "DEBUG",
    [vim.log.levels.TRACE] = "TRACE",
}

function M.name(level)
    if type(level) == "string" then
        return level:upper()
    end
    return level_names[level] or "INFO"
end

return M
