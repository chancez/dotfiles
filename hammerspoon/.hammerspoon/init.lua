local VimMode = hs.loadSpoon('VimMode')
local vim = VimMode:new()

vim
  :disableForApp('Code')
  :disableForApp('MacVim')
  :disableForApp('kitty')
  :disableForApp('iTerm2')
  :disableForApp('zoom.us')
  :enterWithSequence('jk')
  :bindHotKeys({ enter = { {'ctrl'}, ';'} })
  :bindHotKeys({ enter = { {'ctrl'}, 'escape'} })
  -- :bindHotKeys({ enter = { {}, 'escape'} })
