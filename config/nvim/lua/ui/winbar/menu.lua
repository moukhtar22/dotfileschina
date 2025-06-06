local bar = require('ui.winbar.bar')
local utils = require('ui.winbar.utils')
local groupid = vim.api.nvim_create_augroup('WinBarMenu', {})
local configs = require('ui.winbar.configs')

---Lookup table for winbar menus
---@type table<integer, winbar_menu_t>
_G._winbar.menus = {}

---@class winbar_menu_hl_info_t
---@field start integer byte-indexed, 0-indexed, start inclusive
---@field end integer byte-indexed, 0-indexed, end exclusive
---@field hlgroup string
---@field ns integer? namespace id, nil if using default namespace

---@class winbar_menu_entry_t
---@field separator winbar_symbol_t
---@field padding {left: integer, right: integer}
---@field components winbar_symbol_t[]
---@field menu winbar_menu_t? the menu the entry belongs to
---@field idx integer? the index of the entry in the menu
local winbar_menu_entry_t = {}
winbar_menu_entry_t.__index = winbar_menu_entry_t

---@class winbar_menu_entry_opts_t
---@field separator winbar_symbol_t?
---@field padding {left: integer, right: integer}?
---@field components winbar_symbol_t[]?
---@field menu winbar_menu_t? the menu the entry belongs to
---@field idx integer? the index of the entry in the menu

---Create a winbar menu entry instance
---@param opts winbar_menu_entry_opts_t?
---@return winbar_menu_entry_t
function winbar_menu_entry_t:new(opts)
  local entry = setmetatable(
    vim.tbl_deep_extend('force', {
      separator = bar.winbar_symbol_t:new({
        icon = configs.opts.icons.ui.menu.separator,
        icon_hl = 'WinBarIconUISeparatorMenu',
      }),
      padding = configs.opts.menu.entry.padding,
      components = {},
    }, opts or {}),
    self
  )
  -- vim.tbl_deep_extend drops metatables
  setmetatable(entry.separator, bar.winbar_symbol_t)
  for idx, component in ipairs(entry.components) do
    component.entry = entry
    component.entry_idx = idx
  end
  return entry
end

---Concatenate inside a winbar menu entry to get the final string
---and highlight information of the entry
---@return string str
---@return winbar_menu_hl_info_t[] hl_info
function winbar_menu_entry_t:cat()
  local components_with_sep = {} ---@type winbar_symbol_t[]
  for component_idx, component in ipairs(self.components) do
    if component_idx > 1 then
      table.insert(components_with_sep, self.separator)
    end
    table.insert(components_with_sep, component)
  end
  local str = string.rep(' ', self.padding.left)
  local hl_info = {}
  for _, component in ipairs(components_with_sep) do
    if component.icon_hl then
      table.insert(hl_info, {
        start = #str,
        ['end'] = #str + #component.icon,
        hlgroup = component.icon_hl,
      })
    end
    if component.name_hl then
      table.insert(hl_info, {
        start = #str + #component.icon,
        ['end'] = #str + #component.icon + #component.name,
        hlgroup = component.name_hl,
      })
    end
    str = str .. component:cat(true)
  end
  return str .. string.rep(' ', self.padding.right), hl_info
end

---Get the display length of the winbar menu entry
---@return number
function winbar_menu_entry_t:displaywidth()
  return vim.fn.strdisplaywidth((self:cat()))
end

---Get the byte length of the winbar menu entry
---@return number
function winbar_menu_entry_t:bytewidth()
  return #(self:cat())
end

---Get the first clickable component in the winbar menu entry
---@param offset integer? offset from the beginning of the entry, default 0
---@return winbar_symbol_t?
---@return {start: integer, end: integer}? range of the clickable component in the menu, byte-indexed, 0-indexed, start-inclusive, end-exclusive
function winbar_menu_entry_t:first_clickable(offset)
  offset = offset or 0
  local col_start = self.padding.left
  for _, component in ipairs(self.components) do
    local col_end = col_start + component:bytewidth()
    if offset < col_end and component.on_click then
      return component, { start = col_start, ['end'] = col_end }
    end
    col_start = col_end + self.separator:bytewidth()
  end
end

---Get the component at the given position in the winbar menu
---@param col integer 0-indexed, byte-indexed
---@param look_ahead boolean? whether to look ahead for the next component if the given position does not contain a component
---@return winbar_symbol_t?
---@return {start: integer, end: integer}? range of the component in the menu, byte-indexed, 0-indexed, start-inclusive, end-exclusive
function winbar_menu_entry_t:get_component_at(col, look_ahead)
  local col_offset = self.padding.left
  for _, component in ipairs(self.components) do
    local component_len = component:bytewidth()
    if
      (look_ahead or col >= col_offset) and col < col_offset + component_len
    then
      return component,
        {
          start = col_offset,
          ['end'] = col_offset + component_len,
        }
    end
    col_offset = col_offset + component_len + self.separator:bytewidth()
  end
  return nil, nil
end

---Find the previous clickable component in the winbar menu entry
---@param col integer byte-indexed, 0-indexed column position
---@return winbar_symbol_t?
---@return {start: integer, end: integer}? range of the clickable component in the menu, byte-indexed, 0-indexed, start-inclusive, end-exclusive
function winbar_menu_entry_t:prev_clickable(col)
  local col_start = self.padding.left
  local prev_component, range
  for _, component in ipairs(self.components) do
    local col_end = col_start + component:bytewidth()
    if col > col_end and component.on_click then
      prev_component = component
      range = { start = col_start, ['end'] = col_end }
    end
    col_start = col_end + self.separator:bytewidth()
  end
  return prev_component, range
end

---Find the next clickable component in the winbar menu entry
---@param col integer byte-indexed, 0-indexed column position
---@return winbar_symbol_t?
---@return {start: integer, end: integer}? range of the clickable component in the menu, byte-indexed, 0-indexed, start-inclusive, end-exclusive
function winbar_menu_entry_t:next_clickable(col)
  local col_start = self.padding.left
  for _, component in ipairs(self.components) do
    local col_end = col_start + component:bytewidth()
    if col < col_start and component.on_click then
      return component, { start = col_start, ['end'] = col_end }
    end
    col_start = col_end + self.separator:bytewidth()
  end
end

---@class winbar_menu_t
---@field buf integer?
---@field win integer?
---@field is_opened boolean?
---@field entries winbar_menu_entry_t[]
---@field win_configs table window configuration, value can be a function
---@field _win_configs table evaluated window configuration
---@field cursor integer[]? initial cursor position
---@field prev_win integer? previous window, assigned when calling new() or automatically determined in open()
---@field sub_menu winbar_menu_t? submenu, assigned when calling new() or automatically determined when a new menu opens
---@field prev_menu winbar_menu_t? previous menu, assigned when calling new() or automatically determined in open()
---@field clicked_at integer[]? last position where the menu was clicked, byte-indexed, 1,0-indexed
---@field prev_cursor integer[]? previous cursor position
---@field symbol_previewed winbar_symbol_t? symbol being previewed
---@field scrollbar { thumb: integer, background: integer }? scrollbar window handlers
local winbar_menu_t = {}
winbar_menu_t.__index = winbar_menu_t

---@class winbar_menu_opts_t
---@field buf integer?
---@field win integer?
---@field is_opened boolean?
---@field entries winbar_menu_entry_t[]?
---@field win_configs table? window configuration, value can be a function
---@field _win_configs table? evaluated window configuration
---@field cursor integer[]? initial cursor position
---@field prev_win integer? previous window, assigned when calling new() or automatically determined in open()
---@field sub_menu winbar_menu_t? submenu, assigned when calling new() or automatically determined when a new menu opens
---@field prev_menu winbar_menu_t? previous menu, assigned when calling new() or automatically determined in open()
---@field clicked_at integer[]? last position where the menu was clicked, byte-indexed, 1,0-indexed
---@field prev_cursor integer[]? previous cursor position
---@field symbol_previewed winbar_symbol_t? symbol being previewed

---Create a winbar menu instance
---@param opts winbar_menu_opts_t?
---@return winbar_menu_t
function winbar_menu_t:new(opts)
  local winbar_menu = setmetatable(
    vim.tbl_deep_extend('force', {
      entries = {},
      win_configs = configs.opts.menu.win_configs,
    }, opts or {}),
    self
  )
  for idx, entry in ipairs(winbar_menu.entries) do
    entry.menu = winbar_menu
    entry.idx = idx
  end
  return winbar_menu
end

---Delete a winbar menu
---@return nil
function winbar_menu_t:del()
  if self.sub_menu then
    self.sub_menu:del()
    self.sub_menu = nil
  end
  self:close()
  if self.buf then
    if vim.api.nvim_buf_is_valid(self.buf) then
      vim.api.nvim_buf_delete(self.buf, {})
    end
    self.buf = nil
  end
  if self.win then
    _G._winbar.menus[self.win] = nil
  end
end

---Retrieves the root menu (first menu opened from winbar)
---@return winbar_menu_t?
function winbar_menu_t:root()
  local current = self
  while current and current.prev_menu do
    current = current.prev_menu
  end
  return current
end

---Evaluate window configurations
---Side effects: update self._win_configs
---@return nil
---@see vim.api.nvim_open_win
function winbar_menu_t:eval_win_configs()
  -- Evaluate function-valued window configurations
  self._win_configs = {}
  for k, config in pairs(self.win_configs) do
    self._win_configs[k] = configs.eval(config, self)
  end

  -- Ensure `win` field is nil if `relative` ~= 'win', else nvim will
  -- throw error
  -- Why `win` field is set if `relative` field is not 'win'?
  -- It's set because the global configs are used when creating windows, and
  -- overridden by the menu-local settings, but `vim.tbl_deep_extend` will not
  -- replace non-nil with nil so if the default win config uses
  -- `relative` = 'win' (which it does), win will be set even if the menu-local
  -- win config doesn't set it.
  if self._win_configs.relative ~= 'win' then
    self._win_configs.win = nil
  end
end

---Get the component at the given position in the winbar menu
---@param pos integer[] 1,0-indexed, byte-indexed
---@param look_ahead boolean? whether to look ahead for the component at the given position
---@return winbar_symbol_t?
---@return {start: integer, end: integer}? range of the component in the menu, byte-indexed, 0-indexed, start-inclusive, end-exclusive
function winbar_menu_t:get_component_at(pos, look_ahead)
  if not self.entries or vim.tbl_isempty(self.entries) then
    return nil, nil
  end
  local entry = self.entries[pos[1]]
  if not entry or not entry.components then
    return nil, nil
  end
  return entry:get_component_at(pos[2], look_ahead)
end

---"Click" the component at the given position in the winbar menu
---Side effects: update self.clicked_at, close sub-menus
---@param pos integer[] 1,0-indexed, byte-indexed
---@param min_width integer?
---@param n_clicks integer?
---@param button string?
---@param modifiers string?
function winbar_menu_t:click_at(pos, min_width, n_clicks, button, modifiers)
  if self.sub_menu then
    self.sub_menu:close()
  end
  self.clicked_at = pos
  vim.api.nvim_win_set_cursor(self.win, pos)
  local component = self:get_component_at(pos)
  if component and component.on_click then
    component:on_click(min_width, n_clicks, button, modifiers)
  end
end

---"Click" the component in the winbar menu
---Side effects: update self.clicked_at, close sub-menus
---@param symbol winbar_symbol_t
---@param min_width integer?
---@param n_clicks integer?
---@param button string?
---@param modifiers string?
function winbar_menu_t:click_on(symbol, min_width, n_clicks, button, modifiers)
  if self.sub_menu then
    self.sub_menu:close()
  end
  local row = symbol.entry.idx
  local col = symbol.entry.padding.left
  for idx, component in ipairs(symbol.entry.components) do
    if idx == symbol.entry_idx then
      break
    end
    col = col + component:bytewidth() + symbol.entry.separator:bytewidth()
  end
  self.clicked_at = { row, col }
  if symbol and symbol.on_click then
    symbol:on_click(min_width, n_clicks, button, modifiers)
  end
end

---Update WinBarMenuHover* highlights according to pos
---@param pos integer[]? byte-indexed, 1,0-indexed cursor/mouse position
---@return nil
function winbar_menu_t:update_hover_hl(pos)
  if not self.buf then
    return
  end
  utils.hl.range_single(self.buf, 'WinBarMenuHoverSymbol')
  utils.hl.range_single(self.buf, 'WinBarMenuHoverIcon')
  utils.hl.range_single(self.buf, 'WinBarMenuHoverEntry')
  if not pos then
    return
  end
  utils.hl.line_single(self.buf, 'WinBarMenuHoverEntry', pos[1])
  local component, range = self:get_component_at({ pos[1], pos[2] })
  local hlgroup = component and component.name == '' and 'WinBarMenuHoverIcon'
    or 'WinBarMenuHoverSymbol'
  if component and component.on_click and range then
    utils.hl.range_single(self.buf, hlgroup, {
      start = { line = pos[1] - 1, character = range.start },
      ['end'] = { line = pos[1] - 1, character = range['end'] },
    })
  end
end

---Update highlights for current context according to pos
---@param linenr integer? 1-indexed line number
function winbar_menu_t:update_current_context_hl(linenr)
  if self.buf then
    utils.hl.line_single(self.buf, 'WinBarMenuCurrentContext', linenr)
  end
end

---Make a buffer for the menu and set buffer-local keymaps
---Must be called after self:eval_win_configs()
---Side effect: change self.buf, self.hl_info
---@return nil
function winbar_menu_t:make_buf()
  if self.buf then
    return
  end
  self.buf = vim.api.nvim_create_buf(false, true)

  -- Align symbol icons with different lengths
  local max_sym_icon_len = math.max(
    0,
    unpack(
      ---@param entry winbar_menu_entry_t
      vim.tbl_map(function(entry)
        local sym = entry.components[2]
        return (not sym or not sym.icon) and 0
          or vim.fn.strdisplaywidth(sym.icon)
      end, self.entries)
    )
  )
  for _, entry in ipairs(self.entries) do
    local sym = entry.components[2]
    if sym then
      sym.icon = sym.icon or ''
      sym.icon = sym.icon
        .. string.rep(' ', max_sym_icon_len - vim.fn.strdisplaywidth(sym.icon))
    end
  end

  -- Ensure menu width is sufficient after aligning symbol icons which can
  -- increase symbol width
  local max_entry_width = math.max(
    0,
    unpack(vim.tbl_map(function(entry)
      local w = entry:displaywidth()
      return w
    end, self.entries))
  )
  if max_entry_width > self._win_configs.width then
    self._win_configs.width = max_entry_width
  end

  -- Get lines and highlights for each line
  local lines = {} ---@type string[]
  local hl_info = {} ---@type winbar_menu_hl_info_t[][]
  for _, entry in ipairs(self.entries) do
    local line, entry_hl_info = entry:cat()
    -- Pad lines with spaces to the width of the window
    -- This is to make sure hl-WinBarMenuCurrentContext colors
    -- the entire line
    -- Also pad the last symbol's name so that cursor is always
    -- on at least one symbol when inside the menu
    local n = self._win_configs.width - entry:displaywidth()
    if n > 0 then
      local pad = string.rep(' ', n)
      local last_sym = entry.components[#entry.components]
      if last_sym then
        last_sym.name = last_sym.name .. pad
      end
      line = line .. pad
    end
    table.insert(lines, line)
    table.insert(hl_info, entry_hl_info)
  end

  -- Fill the buffer with lines, then add highlights
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  for linenr, hl_line_info in ipairs(hl_info) do
    for _, hl_symbol_info in ipairs(hl_line_info) do
      vim.hl.range(
        self.buf,
        hl_symbol_info.ns or vim.api.nvim_create_namespace('WinBar'),
        hl_symbol_info.hlgroup,
        { linenr - 1, hl_symbol_info.start },
        { linenr - 1, hl_symbol_info['end'] },
        {}
      )
    end
  end

  -- Update highlight at cursor position for the first time if initial
  -- cursor position is set, later updates of cursor highlights will be
  -- triggered by autocmds
  if self.cursor then
    self:update_current_context_hl(self.cursor[1])
  end

  -- Set buffer local options
  vim.bo[self.buf].ma = false
  vim.bo[self.buf].ft = 'winbar_menu'

  -- Set buffer-local keymaps
  -- Default modes: normal
  for key, mapping in pairs(configs.opts.menu.keymaps) do
    local mapping_type = type(mapping)
    if mapping_type == 'function' or mapping_type == 'string' then
      vim.keymap.set('n', key, mapping, { buffer = self.buf })
    elseif mapping_type == 'table' then
      for mode, rhs in pairs(mapping) do
        vim.keymap.set(mode, key, rhs, { buffer = self.buf })
      end
    end
  end

  -- Set buffer-local autocmds
  vim.api.nvim_create_autocmd('WinClosed', {
    nested = true,
    group = groupid,
    buffer = self.buf,
    callback = function()
      -- Trigger self:close() when the popup window is closed
      -- to ensure the cursor is set to the correct previous window
      self:close()
    end,
  })
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = groupid,
    buffer = self.buf,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(self.win)

      if configs.opts.menu.preview then
        self:preview_symbol_at(cursor, true)
      else
        self.prev_cursor = cursor
      end

      if configs.opts.menu.quick_navigation then
        self:quick_navigation(cursor)
      else
        self.prev_cursor = vim.api.nvim_win_get_cursor(0)
      end

      self:update_hover_hl(self.prev_cursor)
      self:update_scrollbar()
    end,
  })
  vim.api.nvim_create_autocmd('WinScrolled', {
    group = groupid,
    buffer = self.buf,
    callback = function()
      self:update_scrollbar()
    end,
  })
  vim.api.nvim_create_autocmd('BufLeave', {
    group = groupid,
    buffer = self.buf,
    callback = function()
      self:update_hover_hl()

      -- BufLeave event fires BEFORE actually switching buffers, so schedule a
      -- check to run after buffer switch is complete
      -- If we've switched to a non-menu buffer, close all menus starting from
      -- root, this ensures proper cleanup when leaving menu navigation
      vim.schedule(function()
        if vim.bo.ft ~= 'winbar_menu' then
          self:root():close()
        end
      end)
    end,
  })
end

---Open the popup window with win configs and opts,
---must be called after self:make_buf()
---@return nil
function winbar_menu_t:open_win()
  if self.is_opened then
    return
  end
  self.is_opened = true

  self.win = vim.api.nvim_open_win(self.buf, true, self._win_configs)
  vim.wo[self.win].scrolloff = 0
  vim.wo[self.win].sidescrolloff = 0
  vim.wo[self.win].wrap = false
  vim.wo[self.win].winfixbuf = true
  vim.wo[self.win].winhl = table.concat({
    'NormalFloat:WinBarMenuNormalFloat',
    'FloatBorder:WinBarMenuFloatBorder',
  }, ',')
end

---Update the scrollbar's position and height, create a new scrollbar if
---one does not exist
---Side effect: can change self.scrollbar
---@return nil
function winbar_menu_t:update_scrollbar()
  if
    not self.win
    or not self.buf
    or not vim.api.nvim_win_is_valid(self.win)
    or not vim.api.nvim_buf_is_valid(self.buf)
    or not configs.opts.menu.scrollbar.enable
  then
    return
  end

  local buf_height = vim.api.nvim_buf_line_count(self.buf)
  local menu_win_configs = vim.api.nvim_win_get_config(self.win)
  if buf_height <= menu_win_configs.height then
    self:close_scrollbar()
    return
  end

  local thumb_height =
    math.max(1, math.floor(menu_win_configs.height ^ 2 / buf_height))
  local offset = vim.fn.line('w$') == buf_height
      and menu_win_configs.height - thumb_height
    or math.min(
      menu_win_configs.height - thumb_height,
      math.floor(menu_win_configs.height * vim.fn.line('w0') / buf_height)
    )

  if self.scrollbar and vim.api.nvim_win_is_valid(self.scrollbar.thumb) then
    local config = vim.api.nvim_win_get_config(self.scrollbar.thumb)
    config.row = offset
    config.height = thumb_height
    vim.api.nvim_win_set_config(self.scrollbar.thumb, config)
  else
    self:close_scrollbar()
    self.scrollbar = {}
    local win_configs = {
      row = 0,
      col = menu_win_configs.width,
      width = 1,
      height = menu_win_configs.height,
      style = 'minimal',
      border = 'none',
      relative = 'win',
      win = self.win,
      focusable = false,
      noautocmd = true,
      zindex = menu_win_configs.zindex,
    }
    self.scrollbar.background = vim.api.nvim_open_win(
      vim.api.nvim_create_buf(false, true),
      false,
      win_configs
    )
    vim.wo[self.scrollbar.background].winhl = 'NormalFloat:WinBarMenuSbar'

    win_configs.row = offset
    win_configs.height = thumb_height
    win_configs.zindex = menu_win_configs.zindex + 1
    self.scrollbar.thumb = vim.api.nvim_open_win(
      vim.api.nvim_create_buf(false, true),
      false,
      win_configs
    )
    vim.wo[self.scrollbar.thumb].winhl = 'NormalFloat:WinBarMenuThumb'
  end
end

---Close the scrollbar, if one exists
---Side effect: set self.scrollbar to nil
---@return nil
function winbar_menu_t:close_scrollbar()
  if not self.scrollbar then
    return
  end
  if vim.api.nvim_win_is_valid(self.scrollbar.thumb) then
    vim.api.nvim_win_close(self.scrollbar.thumb, true)
  end
  if vim.api.nvim_win_is_valid(self.scrollbar.background) then
    vim.api.nvim_win_close(self.scrollbar.background, true)
  end
  self.scrollbar = nil
end

---Override menu options
---@param opts winbar_symbol_opts_t?
---@return nil
function winbar_menu_t:override(opts)
  if not opts then
    return
  end
  for k, v in pairs(opts) do
    if type(v) == 'table' then
      if type(self[k]) == 'table' then
        self[k] = vim.tbl_extend('force', self[k], v)
      else
        self[k] = v
      end
    else
      self[k] = v
    end
  end
end

---Open the menu
---Side effect: change self.win and self.buf
---@param opts winbar_symbol_opts_t?
---@return nil
function winbar_menu_t:open(opts)
  if self.is_opened then
    return
  end
  self:override(opts)

  self.prev_menu = _G._winbar.menus[self.prev_win]
  if self.prev_menu then
    -- if the prev menu has an existing sub-menu, close the sub-menu first
    if self.prev_menu.sub_menu then
      self.prev_menu.sub_menu:close()
    end
    self.prev_menu.sub_menu = self
  end

  self:eval_win_configs()
  self:make_buf()
  self:open_win()
  _G._winbar.menus[self.win] = self
  -- Initialize cursor position
  if self._win_configs.focusable ~= false then
    if self.prev_cursor then
      vim.api.nvim_win_set_cursor(self.win, self.prev_cursor)
    elseif self.cursor then
      vim.api.nvim_win_set_cursor(self.win, self.cursor)
      vim.api.nvim_exec_autocmds('CursorMoved', { buffer = self.buf })
    end
  end
  self:update_scrollbar()
end

---Close the menu
---@param restore_view boolean? whether to restore the source win view, default true
---@return nil
function winbar_menu_t:close(restore_view)
  if not self.is_opened then
    return
  end
  self.is_opened = false
  restore_view = restore_view == nil or restore_view
  -- Close sub-menus
  if self.sub_menu then
    self.sub_menu:close(restore_view)
  end
  -- Move cursor to the previous window
  if self.prev_win and vim.api.nvim_win_is_valid(self.prev_win) then
    vim.api.nvim_set_current_win(self.prev_win)
  end
  -- Close the menu window and dereference it in the lookup table
  if self.win then
    if vim.api.nvim_win_is_valid(self.win) then
      vim.api.nvim_win_close(self.win, true)
    end
    _G._winbar.menus[self.win] = nil
    self.win = nil
  end
  if self.scrollbar then
    self:close_scrollbar()
  end
  -- Finish preview
  if configs.opts.menu.preview then
    self:finish_preview(restore_view)
  end
  -- Update highlights in the previous menu
  if self.prev_menu then
    self.prev_menu:update_hover_hl()
    if configs.opts.menu.preview then
      self.prev_menu:preview_symbol_at(self.prev_menu.prev_cursor)
    end
  end
end

---Preview the symbol at the given position
---@param pos integer[]? 1,0-indexed, byte-indexed position
---@param look_ahead boolean? whether to look ahead for a component
---@return nil
function winbar_menu_t:preview_symbol_at(pos, look_ahead)
  if not pos then
    return
  end
  local component = self:get_component_at(pos, look_ahead)
  if not component then
    return
  end
  component:preview(self.symbol_previewed and self.symbol_previewed.view)
  self.symbol_previewed = component
end

---Finish the preview in current menu
---@param restore_view boolean? whether to restore the source win view, default true
function winbar_menu_t:finish_preview(restore_view)
  restore_view = restore_view == nil or restore_view
  if self.symbol_previewed then
    self.symbol_previewed:preview_restore_hl()
    if restore_view then
      self.symbol_previewed:preview_restore_view()
    end
    self.symbol_previewed = nil
  end
end

---Set the cursor to the nearest clickable component in the direction of
---cursor movement
---@param new_cursor integer[] 1,0-indexed, byte-indexed position
---@return nil
function winbar_menu_t:quick_navigation(new_cursor)
  local entry = self.entries and self.entries[new_cursor[1]]
  if not entry then
    return
  end
  local target_component, range
  if not self.prev_cursor then
    target_component, range =
      entry.components and entry.components[1], {
        start = entry.padding.left,
        ['end'] = entry.padding.left,
      }
  elseif self.prev_cursor[1] == new_cursor[1] then -- moved inside an entry
    if new_cursor[2] > self.prev_cursor[2] then -- moves right
      target_component, range = entry:next_clickable(self.prev_cursor[2])
    else -- moves left
      target_component, range = entry:prev_clickable(self.prev_cursor[2])
    end
  end
  if target_component and range then
    new_cursor = { new_cursor[1], range.start }
    vim.api.nvim_win_set_cursor(self.win, new_cursor)
  end
  self.prev_cursor = new_cursor
end

---Toggle the menu
---@param opts winbar_symbol_opts_t? menu options passed to self:open()
---@return nil
function winbar_menu_t:toggle(opts)
  if self.is_opened then
    self:close()
  else
    self:open(opts)
  end
end

return {
  winbar_menu_t = winbar_menu_t,
  winbar_menu_entry_t = winbar_menu_entry_t,
}
