-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- performance
vim.loader.enable()

-- set options (mapleader) before loading lazy
require 'config.options'
require 'config.commands'
require 'config.autocmds'
require 'config.mappings'

require("lazy").setup("plugins", {
  -- do not automatically check for plugin updates
  checker = {
    enabled = false
  },
  rocks = {
    enabled = false
  },
  change_detection = {
    enabled = true,
    notify = false,
  },
  dev = {
    path = "~/projects",
    patterns = { "chancez" }
  },
})
