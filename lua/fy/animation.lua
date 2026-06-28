local M = {}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function ease(t)
    return t * t * (3 - 2 * t)
end

function M.new(ctx)
    local collapse_state = {
        timer = nil,
        moving = {},
    }

    local function animation_ms(name, fallback)
        local animation = ctx.get_config().animation
        if type(animation) ~= "table" then
            return fallback
        end
        local value = tonumber(animation[name])
        if not value or value <= 0 then
            return fallback
        end
        return math.floor(value)
    end

    local function stop_anim(handle)
        if handle._anim_timer then
            pcall(function()
                handle._anim_timer:stop()
                handle._anim_timer:close()
            end)
            handle._anim_timer = nil
        end
        handle._animating = false
    end

    local function stop_collapse_animation()
        if collapse_state.timer and not collapse_state.timer:is_closing() then
            collapse_state.timer:stop()
            collapse_state.timer:close()
        end
        collapse_state.timer = nil
        for _, handle in ipairs(collapse_state.moving) do
            handle._animating = false
        end
        collapse_state.moving = {}
    end

    local function effect_set(values)
        local set = {}
        if type(values) == "string" then
            local text = values:lower()
            if text == "none" then
                return set
            end
            for token in text:gmatch("[^+,%s|]+") do
                set[token] = true
            end
            return set
        end
        if type(values) == "table" then
            for _, value in ipairs(values) do
                if type(value) == "string" then
                    set[value:lower()] = true
                end
            end
        end
        return set
    end

    local function animation_effects(name, fallback)
        local animation = ctx.get_config().animation
        if type(animation) ~= "table" then
            return fallback
        end
        local raw = animation[name]
        if raw == nil then
            return fallback
        end
        if type(raw) == "string" and raw:lower() == "none" then
            return {}
        end
        if raw == false then
            return {}
        end
        if type(raw) == "table" and next(raw) == nil then
            return {}
        end
        local set = effect_set(raw)
        if next(set) == nil then
            return fallback
        end
        return set
    end

    local function has_effect(effects, name)
        return effects and effects[name] == true
    end

    local function slide_edge_cols(win_w)
        local animation = ctx.get_config().animation
        if type(animation) == "table" then
            local edge = tonumber(animation.edge_cols)
            if edge and edge >= 2 then
                return math.floor(edge)
            end
        end
        local width = tonumber(win_w) or 30
        return math.max(2, math.floor(width * 0.12))
    end

    local function slide_distance_cols(win_w)
        local animation = ctx.get_config().animation
        if type(animation) == "table" then
            local slide = tonumber(animation.slide_cols)
            if slide and slide > 0 then
                return math.floor(slide)
            end
        end
        local width = tonumber(win_w) or 30
        return math.max(4, math.floor(width * 0.2))
    end

    local function animate_to(handle, keyframes, on_done, duration_ms)
        local config = ctx.get_config()
        if not config.animate or #keyframes == 0 then
            if on_done then
                on_done()
            end
            return
        end

        stop_anim(handle)
        handle._animating = true

        local rows = ctx.layout_rows()
        local slot_pos = nil
        for i, h in ipairs(ctx.stack) do
            if h.id == handle.id then
                slot_pos = rows[i]
                break
            end
        end
        if not slot_pos then
            handle._animating = false
            if on_done then
                on_done()
            end
            return
        end

        local interval = math.floor(1000 / config.fps)
        local ms = tonumber(duration_ms) or 200
        if ms <= 0 then
            ms = 200
        end
        local steps_per = math.max(1, math.floor((config.fps * ms) / 1000))
        local kf_idx = 1
        local step = 0

        local cur_blend = tonumber(ctx.get_win_option(handle._winnr, "winblend", 0)) or 0
        local cur_col = slot_pos.col
        local cur_row = slot_pos.row
        local cur_width = handle._win_width or 30
        local cur_height = handle._win_height or 3

        local winfo = ctx.api.nvim_win_get_config(handle._winnr)
        if winfo and winfo.col then
            cur_col = winfo.col
        end
        if winfo and winfo.row then
            cur_row = winfo.row
        end
        if winfo and winfo.width then
            cur_width = winfo.width
        end
        if winfo and winfo.height then
            cur_height = winfo.height
        end

        local timer = ctx.uv.new_timer()
        if not timer then
            handle._animating = false
            if on_done then
                on_done()
            end
            return
        end
        handle._anim_timer = timer

        timer:start(
            0,
            interval,
            vim.schedule_wrap(function()
                if not handle._winnr or not ctx.api.nvim_win_is_valid(handle._winnr) then
                    handle._animating = false
                    if timer and not timer:is_closing() then
                        timer:stop()
                        timer:close()
                    end
                    return
                end

                local kf = keyframes[kf_idx]
                if not kf then
                    handle._animating = false
                    if timer and not timer:is_closing() then
                        timer:stop()
                        timer:close()
                    end
                    if handle._pending_update and not handle._closed then
                        local pending = handle._pending_update
                        handle._pending_update = nil
                        handle:update(pending.msg, pending.opts)
                    end
                    if on_done then
                        on_done()
                    end
                    return
                end

                step = step + 1
                local t = ease(math.min(step / steps_per, 1))

                local new_col = kf.col ~= nil and lerp(cur_col, kf.col, t) or nil
                local new_row = kf.row ~= nil and lerp(cur_row, kf.row, t) or nil
                local new_width = kf.width ~= nil and lerp(cur_width, kf.width, t) or nil
                local new_height = kf.height ~= nil and lerp(cur_height, kf.height, t) or nil

                if kf.right_edge ~= nil then
                    local width_for_col = new_width ~= nil and new_width or cur_width
                    new_col = kf.right_edge - width_for_col
                end

                if kf.blend ~= nil then
                    local blend = math.floor(lerp(cur_blend, kf.blend, t))
                    ctx.set_win_option(handle._winnr, "winblend", math.max(0, math.min(100, blend)))
                end

                if new_col ~= nil or new_row ~= nil or new_width ~= nil or new_height ~= nil then
                    local row = tonumber(new_row ~= nil and new_row or cur_row) or 0
                    local col = tonumber(new_col ~= nil and new_col or cur_col) or 0
                    local cfg = {
                        relative = "editor",
                        row = math.floor(row),
                        col = math.floor(col),
                    }
                    if new_width ~= nil then
                        cfg.width = math.max(2, math.floor(new_width))
                    end
                    if new_height ~= nil then
                        cfg.height = math.max(1, math.floor(new_height))
                    end
                    pcall(ctx.api.nvim_win_set_config, handle._winnr, cfg)
                end

                if t >= 1 then
                    step = 0
                    kf_idx = kf_idx + 1
                    cur_blend = kf.blend ~= nil and kf.blend or cur_blend
                    cur_col = kf.col ~= nil and kf.col or cur_col
                    cur_row = kf.row ~= nil and kf.row or cur_row
                    cur_width = kf.width ~= nil and kf.width or cur_width
                    cur_height = kf.height ~= nil and kf.height or cur_height
                    if kf.right_edge ~= nil then
                        cur_col = kf.right_edge - cur_width
                    end
                end
            end)
        )
    end

    local function animate_collapse()
        local config = ctx.get_config()
        stop_collapse_animation()

        local ms = animation_ms("collapse_ms", 220)
        local steps_per = math.max(1, math.floor((config.fps * ms) / 1000))
        local interval = math.floor(1000 / config.fps)
        local step = 0

        local targets = ctx.layout_rows()
        local moving = {}
        for i = 1, #ctx.stack do
            local handle = ctx.stack[i]
            local target = targets[i]
            if handle and target and handle._winnr and ctx.api.nvim_win_is_valid(handle._winnr) then
                local cfg = ctx.api.nvim_win_get_config(handle._winnr)
                local start_row = cfg and cfg.row or target.row
                local start_col = cfg and cfg.col or target.col
                if start_row ~= target.row or start_col ~= target.col then
                    handle._animating = true
                    moving[#moving + 1] = {
                        handle = handle,
                        start_row = start_row,
                        start_col = start_col,
                        target_row = target.row,
                        target_col = target.col,
                    }
                end
            end
        end

        if #moving == 0 then
            ctx.reflow()
            return
        end

        collapse_state.moving = {}
        for _, item in ipairs(moving) do
            table.insert(collapse_state.moving, item.handle)
        end

        local timer = ctx.uv.new_timer()
        if not timer then
            stop_collapse_animation()
            ctx.reflow()
            return
        end
        collapse_state.timer = timer

        timer:start(
            0,
            interval,
            vim.schedule_wrap(function()
                step = step + 1
                local t = ease(math.min(step / steps_per, 1))

                for _, item in ipairs(moving) do
                    local handle = item.handle
                    if handle._winnr and ctx.api.nvim_win_is_valid(handle._winnr) then
                        ctx.win_move(
                            handle._winnr,
                            lerp(item.start_row, item.target_row, t),
                            lerp(item.start_col, item.target_col, t)
                        )
                    end
                end

                if t >= 1 then
                    stop_collapse_animation()
                    ctx.reflow()
                end
            end)
        )
    end

    return {
        animation_ms = animation_ms,
        animate_to = animate_to,
        animate_collapse = animate_collapse,
        animation_effects = animation_effects,
        has_effect = has_effect,
        slide_edge_cols = slide_edge_cols,
        slide_distance_cols = slide_distance_cols,
        stop_anim = stop_anim,
    }
end

return M
