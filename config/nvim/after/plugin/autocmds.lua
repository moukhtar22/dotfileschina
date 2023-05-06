--   __,
--  /  |       _|_  _   _           _|
-- |   |  |  |  |  / \_/   /|/|/|  / |
--  \_/\_/ \/|_/|_/\_/ \__/ | | |_/\/|_/
--

local api = vim.api
local cmd = vim.cmd
local function augroup(name)
  return vim.api.nvim_create_augroup("mnv_" .. name, { clear = true })
end

-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank { timeout = 100 }
  end,
  group = highlight_group,
  pattern = "*",
})

-- show cursor line only in active window
cursorGrp = augroup "CursorLine"
api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, { pattern = "*", command = "set cursorline", group = cursorGrp })

-- go to last loc when opening a buffer
api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- wrap and check for spell in text filetypes
api.nvim_create_autocmd("FileType", {
  group = augroup "wrap_spell",
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Auto toggle hlsearch
-- local ns = api.nvim_create_namespace "toggle_hlsearch"
-- local function toggle_hlsearch(char)
--   if vim.fn.mode() == "n" then
--     local keys = { "<CR>", "n", "N", "*", "#", "?", "/" }
--     local new_hlsearch = vim.tbl_contains(keys, vim.fn.keytrans(char))
--
--     if vim.opt.hlsearch:get() ~= new_hlsearch then
--       vim.opt.hlsearch = new_hlsearch
--     end
--   end
-- end
-- vim.on_key(toggle_hlsearch, ns)

vim.api.nvim_set_hl(0, "TerminalCursorShape", { underline = true })
vim.api.nvim_create_autocmd("TermEnter", {
  callback = function()
    vim.cmd [[setlocal winhighlight=TermCursor:TerminalCursorShape]]
  end,
})

-- Delete spaces
api.nvim_create_autocmd("BufWritePre", { command = [[%s/\s\+$//e]] })
api.nvim_create_autocmd("BufEnter", { command = [[let @/=""]] })
-- Pwd in currente buffer
api.nvim_create_autocmd("BufEnter", { command = "silent! lcd %:p:h" })
-- Format options
api.nvim_create_autocmd("FileType", { pattern = "make", command = [[setlocal noexpandtab]] })
-- don't auto comment new line
api.nvim_create_autocmd("BufEnter", { command = [[set formatoptions-=cro]] })
api.nvim_create_autocmd("FileType", { pattern = "man", command = [[nnoremap <buffer><silent> q :quit<CR>]] })

-- Create an autocmd User PackerCompileDone to update it every time packer is compiled
-- vim.api.nvim_create_autocmd("User", {
-- 	pattern = "PackerCompileDone",
-- 	callback = function()
-- 		vim.cmd "CatppuccinCompile"
-- 		vim.defer_fn(function()
-- 			vim.cmd "colorscheme catppuccin"
-- 		end, 0) -- Defered for live reloading
-- 	end
-- })
-- Fix highlight issue
-- api.nvim_create_autocmd("BufEnter", { command = [[syntax enable]] })

-- au FileType python setlocal tabstop=4 shiftwidth=4 expandtab
-- au FileType typescript setlocal tabstop=2 shiftwidth=2 expandtab
-- au FileType lua setlocal tabstop=2 shiftwidth=2 expandtab
-- au BufEnter *.py set ai sw=4 ts=4 sta et fo=croq;
