-- Terminal title matching the zsh one: shortened cwd plus git branch.
-- Keeps the kitty tab title stable when switching between the shell and nvim.

local M = {}

-- ~/projects/foo/bar/baz -> ~/p/f/b/baz
local function shorten(path)
  local parts = vim.split(path, '/', { plain = true })
  for i = 1, #parts - 1 do
    local seg = parts[i]
    if seg ~= '' and seg ~= '~' then
      -- Keep the dot on hidden dirs, otherwise they all collapse to '.'
      parts[i] = seg:sub(1, 1) == '.' and seg:sub(1, 2) or seg:sub(1, 1)
    end
  end
  return table.concat(parts, '/')
end

local branch_cache = {}

-- A remote nvim says which host it is on, matching zsh/title.zsh.
--
-- Needed for the same reason it is needed there: these dotfiles are installed on both ends of an ssh, so
-- the rest of the title is byte for byte what a local session produces and there is nothing to tell them
-- apart. kitty's own integration does this too, prefixing the short hostname, and it is switched off here
-- with no-title because this file owns the title instead.
--
-- Computed once at load. Neither the hostname nor whether this process is remote changes while nvim runs,
-- and the title is rebuilt on every BufEnter.
--
-- SSH_CONNECTION and SSH_TTY are what sshd sets, the same pair title.zsh tests. vim.uv with a vim.loop
-- fallback because the rename landed in 0.10 and this config runs on remote hosts with whatever nvim they
-- happen to have.
local host_prefix = (function()
  if (vim.env.SSH_CONNECTION or '') == '' and (vim.env.SSH_TTY or '') == '' then
    return ''
  end
  local uv = vim.uv or vim.loop
  local host = uv and uv.os_gethostname() or ''
  -- The short form, as kitty and title.zsh use: a fully qualified name eats the width the path needs.
  host = host:gsub('%..*$', '')
  if host == '' then
    return ''
  end
  return host .. ': '
end)()

local function set_titlestring(cwd, branch)
  local title = host_prefix .. 'nvim ' .. shorten(vim.fn.fnamemodify(cwd, ':~'))
  if branch and branch ~= '' then
    title = title .. ' (' .. branch .. ')'
  end
  -- Assign a literal, not a %{} expression: nvim only re-emits the title when
  -- titlestring changes, so an expression would never refresh on branch switch.
  vim.o.titlestring = title:gsub('%%', '%%%%')
end

-- Repaint from what we already know. Cheap enough for frequent events.
local function repaint()
  local cwd = vim.fn.getcwd()
  set_titlestring(cwd, vim.b.gitsigns_head or branch_cache[cwd])
end

-- git runs async so startup and :cd never block on it.
local function update(cwd)
  cwd = cwd or vim.fn.getcwd()
  repaint()

  local function apply(branch)
    vim.schedule(function()
      branch_cache[cwd] = branch
      if cwd == vim.fn.getcwd() then
        set_titlestring(cwd, branch)
        -- An idle nvim won't flush the new title until the next redraw.
        vim.cmd('redraw')
      end
    end)
  end

  -- Matches zsh/title.zsh: the branch name, falling back to a short sha when
  -- detached. symbolic-ref rather than describe, since describe prefers a tag
  -- pointing at HEAD over the branch name.
  vim.system(
    { 'git', '-C', cwd, 'symbolic-ref', '--quiet', '--short', 'HEAD' },
    { text = true },
    function(head)
      if head.code == 0 then
        apply(vim.trim(head.stdout))
        return
      end
      vim.system(
        { 'git', '-C', cwd, 'rev-parse', '--short', 'HEAD' },
        { text = true },
        function(sha)
          apply(sha.code == 0 and vim.trim(sha.stdout) or '')
        end
      )
    end
  )
end

function M.setup()
  vim.o.title = true
  update()

  local group = vim.api.nvim_create_augroup('config_title', { clear = true })

  -- Only re-run git when the branch may actually have changed.
  vim.api.nvim_create_autocmd({ 'DirChanged', 'FocusGained' }, {
    group = group,
    callback = function()
      update()
    end,
  })

  -- gitsigns_head is buffer-local, so track the active buffer without shelling out.
  vim.api.nvim_create_autocmd({ 'BufEnter', 'User' }, {
    group = group,
    pattern = { '*', 'GitSignsUpdate' },
    callback = repaint,
  })
end

return M
