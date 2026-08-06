local util = require('config.util')

local event_to_pattern = {
  -- highlight trailing whitespace when we enter into a buffer
  BufWinEnter = "\\s\\+$",
  -- do not highlight trailing whitespace while inserting
  InsertEnter = "\\s\\+\\%#\\@<!$",
  -- re-highlight trailing whitespace when leaving insert mode
  InsertLeave = "\\s\\+$",
}

vim.api.nvim_set_hl(0, 'ExtraWhitespace', { bg = 'red' })

local function HighlightWhitespace()
  for event, pattern in pairs(event_to_pattern) do
    vim.api.nvim_create_autocmd(event, {
      buffer = 0,
      callback = function()
        -- Delete the existing match if it exists, we only want one at a time
        if vim.w.whitespace_match then
          vim.fn.matchdelete(vim.w.whitespace_match)
        end
        vim.w.whitespace_match = vim.fn.matchadd('ExtraWhitespace', pattern)
      end,
    })
  end
end

-- Lua match patterns to ignore certain filetypes
local whitespaceIgnoreFileTypes = {
  'terminal',
  'toggleterm',
  'lazy',
  'mcphub',
  'markdown',
  'help',
  'k8s_.*',
  -- Dashes need to be escaped
  vim.pesc('blink-cmp-menu'),
  'Avante.*',
  'opencode.*',
}

vim.api.nvim_create_autocmd({ 'FileType' }, {
  -- Apply to all filetypes because we will filter inside the callback since
  -- there is no way to use patterns in the FileType autocmd to do an ignore
  -- list without inverting all patterns directly
  pattern = '*',
  callback = function(ev)
    -- Check if the current filetype matches any pattern in the ignore list
    for _, pattern in ipairs(whitespaceIgnoreFileTypes) do
      if vim.bo.filetype:match('^' .. pattern .. '$') then
        return
      end
    end
    HighlightWhitespace()
  end
})

local function StripTrailingWhitespace()
  -- Get all lines in the buffer
  local lines = util.GetBufferLines()
  local changed = false

  for i, line in ipairs(lines) do
    local stripped = line:gsub("%s+$", "")
    if stripped ~= line then
      lines[i] = stripped
      changed = true
    end
  end

  if changed then
    util.ReplaceBufferLines(lines)
  end
end

local function ToggleStripTrailingWhitespace()
  vim.b.noStripWhitespace = not vim.b.noStripWhitespace
  local status = vim.b.noStripWhitespace and "disabled" or "enabled"
  print("StripTrailingWhitespace on save for this buffer " .. status)
end

vim.api.nvim_create_user_command('ToggleStripTrailingWhitespace', ToggleStripTrailingWhitespace,
  { desc = "Toggle stripping trailing whitespace on save for this buffer" })

-- strip trailing whitespace
vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
  pattern = '*',
  callback = function()
    if not vim.b.noStripWhitespace then
      StripTrailingWhitespace()
    end
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd({ 'TextYankPost' }, {
  pattern = '*',
  callback = function()
    vim.hl.on_yank({ higroup = 'IncSearch', timeout = 300 })
  end,
})

-- Disable cursorline and cursorcolumn in non-active windows
vim.api.nvim_create_autocmd({ 'WinLeave' }, {
  pattern = '*',
  callback = function()
    vim.wo.cursorline = false
    vim.wo.cursorcolumn = false
    vim.wo.colorcolumn = ''
  end,
})

-- Enable cursorline and cursorcolumn in active window
vim.api.nvim_create_autocmd({ 'WinEnter' }, {
  pattern = '*',
  callback = function()
    vim.wo.cursorline = true
    vim.wo.cursorcolumn = true
    vim.wo.colorcolumn = '80,100'
  end,
})

vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
  pattern = '*',
  desc = 'Auto create parent directory if it does not exist',
  callback = function(ev)
    local dir = vim.fn.fnamemodify(ev.file, ':p:h')
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
    end
  end,
})

-- octo:// buffers are URIs, not files, so editorconfig has no business
-- configuring them. It matches on the path anyway and sets 'fileencoding',
-- which marks the buffer modified. That breaks session restore: the session
-- file does `enew` + `file octo://...` + `balt octo://...`, and balt aborts
-- with E37 (no write since last change) on a modified buffer.
--
-- Registered here rather than in the octo spec because octo is lazy loaded on
-- BufReadCmd and is not loaded yet while the session is being restored.
vim.api.nvim_create_autocmd({ 'BufFilePost' }, {
  pattern = 'octo://*',
  desc = 'Keep editorconfig from marking octo:// buffers as modified',
  callback = function(ev)
    -- Opt out of editorconfig for this buffer. This is enough on its own when
    -- this runs before editorconfig's own BufFilePost hook.
    vim.b[ev.buf].editorconfig = false
    -- If editorconfig already ran and dirtied the buffer, undo that. Only do it
    -- while the buffer is still empty so a `:file octo://...` on a buffer with
    -- real unsaved edits does not lose its modified flag.
    local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
    if #lines <= 1 and (lines[1] or '') == '' then
      vim.bo[ev.buf].modified = false
    end
  end,
})

-- A restored octo:// buffer is empty: the session file recreates it with
-- `enew` + `file octo://...`, which never fires BufReadCmd, so octo never gets
-- a chance to fetch and render it. Re-edit them so they load their contents.
-- Deferred because octo itself lazy loads on BufReadCmd, which has not
-- happened yet while the session is being sourced.
vim.api.nvim_create_autocmd({ 'SessionLoadPost' }, {
  desc = 'Populate octo:// buffers restored from a session',
  callback = function()
    vim.schedule(function()
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name:match('^octo://') and vim.api.nvim_buf_line_count(bufnr) <= 1 then
          vim.api.nvim_buf_call(bufnr, function()
            pcall(vim.cmd.edit)
          end)
        end
      end
    end)
  end,
})

-- Automatically open help as a vertical split
vim.api.nvim_create_autocmd({ 'FileType' }, {
  pattern = 'help',
  callback = function()
    vim.cmd('wincmd L')
  end,
})

-- Automatically attach the correct CRD schema to YAML files when the
-- yaml-language-server starts
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'yaml',
  callback = function(args)
    local bufnr = args.buf
    -- Wait for the yaml-language-server to start
    local clients = vim.lsp.get_clients({ name = 'yamlls', bufnr = bufnr })
    if #clients > 0 then
      -- If the server is already running, call init()
      require('config.yaml-k8s-crds').init(bufnr)
    else
      -- If the server is not running, wait for it to start
      vim.api.nvim_create_autocmd('LspAttach', {
        once = true,
        buffer = bufnr,
        callback = function(lsp_args)
          local client = vim.lsp.get_client_by_id(lsp_args.data.client_id)
          if client and client.name == 'yamlls' then
            require('config.yaml-k8s-crds').init(bufnr)
          end
        end,
      })
    end
  end,
})
