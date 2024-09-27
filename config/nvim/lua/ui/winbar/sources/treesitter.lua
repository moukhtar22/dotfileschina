local configs = require('ui.winbar.configs')
local bar = require('ui.winbar.bar')
local utils = require('ui.winbar.utils')

---Get short name of treesitter symbols in buffer buf
---@param node TSNode
---@param buf integer buffer handler
local function get_node_short_name(node, buf)
  return vim.trim(
    vim.fn.matchstr(
      vim.treesitter.get_node_text(node, buf):gsub('\n', ' '):gsub('\t', ' '),
      configs.opts.sources.treesitter.name_pattern
    )
  )
end

---Get valid treesitter node type name
---@param node TSNode
---@return string type_name
local function get_node_short_type(node)
  local ts_type = node:type()
  for _, type in ipairs(configs.opts.sources.treesitter.valid_types) do
    if vim.startswith(ts_type, type) then
      return type
    end
  end
  return ''
end

---Check if treesitter node is valid
---@param node TSNode
---@param buf integer buffer handler
---@return boolean
local function valid_node(node, buf)
  return get_node_short_type(node) ~= ''
    and get_node_short_name(node, buf) ~= ''
end

---Get treesitter node children
---@param node TSNode
---@param buf integer buffer handler
---@return TSNode[] children
local function get_node_children(node, buf)
  local children = {}
  for child in node:iter_children() do
    if valid_node(child, buf) then
      table.insert(children, child)
    else
      vim.list_extend(children, get_node_children(child, buf))
    end
  end
  return children
end

---Get treesitter node siblings
---@param node TSNode
---@param buf integer buffer handler
---@return TSNode[] siblings
---@return integer idx index of the node in its siblings
local function get_node_siblings(node, buf)
  local siblings = {}
  local current = node ---@type TSNode?
  while current do
    if valid_node(current, buf) then
      table.insert(siblings, 1, current)
    else
      for _, sib in ipairs(get_node_children(current, buf)) do
        table.insert(siblings, 1, sib)
      end
    end
    current = current:prev_sibling()
  end
  local idx = #siblings
  current = node:next_sibling()
  while current do
    if valid_node(current, buf) then
      table.insert(siblings, current)
    else
      vim.list_extend(siblings, get_node_children(current, buf))
    end
    current = current:next_sibling()
  end
  return siblings, idx
end

---Convert TSNode into winbar symbol structure
---@param ts_node TSNode
---@param buf integer buffer handler
---@param win integer window handler
---@return winbar_symbol_t?
local function convert(ts_node, buf, win)
  if not valid_node(ts_node, buf) then
    return nil
  end
  local kind = utils.string.snake_to_camel(get_node_short_type(ts_node))
  local range = { ts_node:range() }
  return bar.winbar_symbol_t:new(setmetatable({
    buf = buf,
    win = win,
    name = get_node_short_name(ts_node, buf),
    icon = configs.opts.icons.kinds.symbols[kind],
    icon_hl = 'WinBarIconKind' .. kind,
    range = {
      start = {
        line = range[1],
        character = range[2],
      },
      ['end'] = {
        line = range[3],
        character = range[4],
      },
    },
  }, {
    ---@param self winbar_symbol_t
    ---@param k string|number
    __index = function(self, k)
      if k == 'children' then
        self.children = vim.tbl_map(function(child)
          return convert(child, buf, win)
        end, get_node_children(ts_node, buf))
        return self.children
      elseif k == 'siblings' or k == 'sibling_idx' then
        local siblings, idx = get_node_siblings(ts_node, buf)
        self.siblings = vim.tbl_map(function(sibling)
          return convert(sibling, buf, win)
        end, siblings)
        self.sibling_idx = idx
        return self[k]
      end
    end,
  }))
end

---Get treesitter symbols from buffer
---@param buf integer buffer handler
---@param win integer window handler
---@param cursor integer[] cursor position
---@return winbar_symbol_t[] symbols winbar symbols
local function get_symbols(buf, win, cursor)
  if not utils.treesitter.is_active(buf) then
    return {}
  end

  local symbols = {} ---@type winbar_symbol_t[]
  local current_node =
    vim.treesitter.get_node({
      bufnr = buf,
      pos = {
        cursor[1] - 1,
        cursor[2] - (cursor[2] >= 1 and vim.api
          .nvim_get_mode().mode
          :match('^i') and 1 or 0),
      },
    })
  while current_node do
    if valid_node(current_node, buf) then
      table.insert(symbols, 1, convert(current_node, buf, win))
    end
    current_node = current_node:parent()
  end
  return symbols
end

return {
  get_symbols = get_symbols,
}
