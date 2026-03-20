-- Treesitter-aware gq/gw replacements.
--
-- Neovim's built-in gq/gw use the buffer's 'comments' option to detect and
-- preserve comment leaders when wrapping text. This breaks in buffers with
-- injected languages (e.g. a Lua code block inside markdown) because the
-- buffer-level 'comments' belongs to the host filetype, not the injected one.
--
-- This module uses treesitter to find the injected language at the cursor
-- position, temporarily sets 'comments' to match that language, then delegates
-- to the real gq/gw via normal! so all other formatting behavior (formatprg,
-- formatexpr, internal formatter) is preserved.

local function get_comments_at_pos(bufnr, row, col)
  local ok, ts_parser = pcall(vim.treesitter.get_parser, bufnr, '')
  if not ok or not ts_parser then
    return vim.bo[bufnr].comments
  end

  local ref_range = { row, col, row, col + 1 }
  local result, res_level = nil, 0

  local function traverse(lang_tree, level)
    if not lang_tree:contains(ref_range) then
      return
    end
    local lang = lang_tree:lang()
    for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
      local comments = vim.filetype.get_option(ft, 'comments')
      if comments ~= '' and level > res_level then
        result, res_level = comments, level
      end
    end
    for _, child in pairs(lang_tree:children()) do
      traverse(child, level + 1)
    end
  end

  traverse(ts_parser, 1)
  return result or vim.bo[bufnr].comments
end

local function format_operator(mode, keep_cursor)
  if mode == nil then
    -- Expression mapping: set operatorfunc and return g@
    vim.o.operatorfunc = ("v:lua.require'format'.%s"):format(
      keep_cursor and 'gw' or 'gq'
    )
    return 'g@'
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum_from = vim.fn.line("'[")
  local lnum_to = vim.fn.line("']")

  local comments = get_comments_at_pos(0, cursor[1] - 1, cursor[2])
  local saved_comments = vim.bo.comments

  vim.bo.comments = comments
  -- Visually select the range and format (normal! to avoid recursion)
  local op = keep_cursor and 'gw' or 'gq'
  vim.cmd(string.format('normal! %dGV%dG%s', lnum_from, lnum_to, op))
  vim.bo.comments = saved_comments

  if keep_cursor then
    vim.api.nvim_win_set_cursor(0, cursor)
  else
    -- gq moves cursor to last formatted line, first non-blank
    vim.cmd("normal! ']")
    vim.cmd('normal! ^')
  end
end

return {
  gq = function(mode) return format_operator(mode, false) end,
  gw = function(mode) return format_operator(mode, true) end,
}
