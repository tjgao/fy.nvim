local M = {}

function M.new(ctx)
    local Handle = {}
    Handle.__index = Handle

    function Handle:_open(msg, lvl_name, opts)
        local config = ctx.get_config()
        local inner_w = ctx.content.compute_inner_width(msg, opts.title, lvl_name, config, ctx.editor_size)
        local win_w = inner_w + config.padding.left + config.padding.right
        local lines, hls = ctx.content.build_content(msg, lvl_name, opts, inner_w, config)
        local win_h = math.min(#lines, config.max_height + 3)

        self._win_width = win_w
        self._win_height = win_h + 2

        local bufnr = ctx.api.nvim_create_buf(false, true)
        ctx.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        ctx.set_buf_option(bufnr, "modifiable", false)
        ctx.set_buf_option(bufnr, "filetype", "notify")

        local ns = ctx.api.nvim_create_namespace("notify_hl_" .. self.id)
        ctx.apply_highlights(bufnr, ns, hls)

        local ed = ctx.editor_size()
        local col = ed.width - win_w - config.margin.right

        local winnr = ctx.api.nvim_open_win(bufnr, false, {
            relative = "editor",
            row = ed.height - 4,
            col = col,
            width = win_w,
            height = win_h,
            style = "minimal",
            border = ctx.content.make_border(lvl_name, config),
            title = ctx.content.make_win_title(opts.title, lvl_name, inner_w, config),
            title_pos = "center",
            focusable = false,
            noautocmd = true,
        })

        ctx.set_win_option(
            winnr,
            "winhl",
            "Normal:NotifyBackground,FloatBorder:" .. (config.highlights[lvl_name] or config.highlights.INFO).border
        )
        ctx.set_win_option(winnr, "winblend", config.animate and 100 or 0)
        ctx.set_win_option(winnr, "wrap", false)
        ctx.set_win_option(winnr, "cursorline", false)

        self._bufnr = bufnr
        self._winnr = winnr
        self._closed = false

        local rows = ctx.layout_rows()
        local slot_pos = nil
        for i, handle in ipairs(ctx.stack) do
            if handle.id == self.id then
                slot_pos = rows[i]
                break
            end
        end

        local target_col = slot_pos and slot_pos.col or (ed.width - win_w - config.margin.right)
        local target_row = slot_pos and slot_pos.row or config.margin.top

        if config.animate then
            local effects = ctx.animation.animation_effects("enter", { slide = true, reveal = true })
            local use_fade = ctx.animation.has_effect(effects, "fade")
            local use_slide = ctx.animation.has_effect(effects, "slide")
            local use_reveal = ctx.animation.has_effect(effects, "reveal")

            local start_width = win_w
            local start_col = target_col
            if use_reveal then
                local edge = ctx.animation.slide_edge_cols(win_w)
                start_width = math.max(2, edge)
                start_col = target_col + (win_w - start_width)
            end
            if use_slide then
                start_col = start_col + ctx.animation.slide_distance_cols(win_w)
            end

            pcall(ctx.api.nvim_win_set_config, winnr, {
                relative = "editor",
                row = math.floor(target_row),
                col = math.floor(start_col),
                width = start_width,
                height = win_h,
            })
            ctx.set_win_option(winnr, "winblend", use_fade and 100 or 0)

            if use_fade or use_slide or use_reveal then
                local enter_keyframe = {
                    row = target_row,
                    col = target_col,
                }
                if use_reveal then
                    enter_keyframe.width = win_w
                end
                if use_fade then
                    enter_keyframe.blend = 0
                end
                ctx.animation.animate_to(self, { enter_keyframe }, nil, ctx.animation.animation_ms("enter_ms", 220))
            else
                ctx.win_move(winnr, target_row, target_col)
            end
        else
            ctx.win_move(winnr, target_row, target_col)
        end

        if opts.timeout ~= false then
            local timeout = opts.timeout or config.timeout
            if timeout and timeout > 0 then
                self._timeout_timer = ctx.uv.new_timer()
                if self._timeout_timer then
                    self._timeout_timer:start(
                        timeout,
                        0,
                        vim.schedule_wrap(function()
                            self:close()
                        end)
                    )
                end
            end
        end
    end

    function Handle:close()
        if self._closed then
            return
        end
        self._closed = true

        if self._timeout_timer then
            pcall(function()
                self._timeout_timer:stop()
                self._timeout_timer:close()
            end)
            self._timeout_timer = nil
        end

        if self._vacant_timer then
            pcall(function()
                self._vacant_timer:stop()
                self._vacant_timer:close()
            end)
            self._vacant_timer = nil
        end

        ctx.animation.stop_anim(self)

        local function remove_and_collapse()
            local slot_idx = nil
            for i, handle in ipairs(ctx.stack) do
                if handle.id == self.id then
                    slot_idx = i
                    break
                end
            end

            if not slot_idx then
                return
            end

            table.remove(ctx.stack, slot_idx)
            ctx.animation.animate_collapse()
        end

        local function do_close_win()
            if self._winnr and ctx.api.nvim_win_is_valid(self._winnr) then
                ctx.api.nvim_win_close(self._winnr, true)
            end
            if self._bufnr and ctx.api.nvim_buf_is_valid(self._bufnr) then
                ctx.api.nvim_buf_delete(self._bufnr, { force = true })
            end

            self._winnr = nil
            self._bufnr = nil

            local vacant_timeout = ctx.get_config().vacant_timeout or 3000
            self._vacant_timer = ctx.uv.new_timer()
            if self._vacant_timer then
                self._vacant_timer:start(
                    vacant_timeout,
                    0,
                    vim.schedule_wrap(function()
                        remove_and_collapse()
                    end)
                )
            else
                remove_and_collapse()
            end
        end

        local config = ctx.get_config()
        if config.animate and self._winnr and ctx.api.nvim_win_is_valid(self._winnr) then
            local ed = ctx.editor_size()
            local wininfo = ctx.api.nvim_win_get_config(self._winnr)
            local cur_col = wininfo and wininfo.col or ed.width
            local cur_row = wininfo and wininfo.row or 0
            local cur_width = wininfo and wininfo.width or self._win_width or 30
            local effects = ctx.animation.animation_effects("exit", { slide = true, reveal = true })
            local use_fade = ctx.animation.has_effect(effects, "fade")
            local use_slide = ctx.animation.has_effect(effects, "slide")
            local use_reveal = ctx.animation.has_effect(effects, "reveal")

            if use_fade or use_slide or use_reveal then
                local target_col = cur_col
                local target_width = cur_width
                if use_reveal then
                    local edge = ctx.animation.slide_edge_cols(cur_width)
                    target_width = math.max(2, edge)
                    target_col = target_col + (cur_width - target_width)
                end
                if use_slide then
                    target_col = target_col + ctx.animation.slide_distance_cols(cur_width)
                end

                local exit_keyframe = {
                    row = cur_row,
                    col = target_col,
                }
                if use_reveal then
                    exit_keyframe.width = target_width
                end
                if use_fade then
                    exit_keyframe.blend = 100
                end

                ctx.animation.animate_to(
                    self,
                    { exit_keyframe },
                    vim.schedule_wrap(do_close_win),
                    ctx.animation.animation_ms("exit_ms", 180)
                )
            else
                do_close_win()
            end
        else
            do_close_win()
        end
    end

    Handle.hide = Handle.close
    Handle.dismiss = Handle.close

    function Handle:update(msg, opts)
        opts = opts or {}
        if self._closed or not self._bufnr or not ctx.api.nvim_buf_is_valid(self._bufnr) then
            return
        end

        local config = ctx.get_config()
        local lvl_name = self._lvl_name
        local merged = vim.tbl_extend("force", self._opts, opts)
        local inner_w = ctx.content.compute_inner_width(msg, merged.title, lvl_name, config, ctx.editor_size)
        local win_w = inner_w + config.padding.left + config.padding.right
        local lines, hls = ctx.content.build_content(msg, lvl_name, merged, inner_w, config)

        ctx.set_buf_option(self._bufnr, "modifiable", true)
        ctx.api.nvim_buf_set_lines(self._bufnr, 0, -1, false, lines)
        ctx.set_buf_option(self._bufnr, "modifiable", false)

        local ns = ctx.api.nvim_create_namespace("notify_hl_" .. self.id)
        ctx.apply_highlights(self._bufnr, ns, hls)

        local win_h = math.min(#lines, config.max_height + 3)
        if self._animating then
            self._pending_update = {
                msg = msg,
                opts = opts,
            }
            return
        end

        self._win_width = win_w
        self._win_height = win_h + 2
        if self._winnr and ctx.api.nvim_win_is_valid(self._winnr) then
            ctx.api.nvim_win_set_config(self._winnr, {
                width = win_w,
                height = win_h,
                title = ctx.content.make_win_title(merged.title, lvl_name, inner_w, config),
                title_pos = "center",
            })
        end
        ctx.reflow()
    end

    return Handle
end

return M
