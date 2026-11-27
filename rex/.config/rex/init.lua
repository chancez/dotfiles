-- Migrated from kitty (~/.config/kitty/kitty.conf). kitty_mod is cmd.

-- Session picker moves to cmd+p; cmd+k focuses the pane above, as in kitty.
rex.bind("cmd+p", "session.switch")

-- Tabs
rex.bind("cmd+9", "client.tab.goto", { index = 9 })
rex.bind("ctrl+shift+,", "client.tab.move", { direction = "backward" })
rex.bind("ctrl+shift+.", "client.tab.move", { direction = "forward" })
rex.bind("cmd+w", "client.tab.close")

-- Prompts
rex.bind("ctrl+cmd+p", "client.prompt.previous")
rex.bind("ctrl+cmd+n", "client.prompt.next")
rex.bind("ctrl+shift+p", "client.prompt.previous")
rex.bind("ctrl+shift+n", "client.prompt.next")

-- Windows and splits
rex.bind("cmd+n", "client.window.new")
rex.bind("cmd+enter", "pane.split", { direction = "down" })
rex.bind("cmd+o", "pane.split", { direction = "down" })
rex.bind("cmd+e", "pane.split", { direction = "right" })
rex.bind("shift+cmd+w", "pane.close")

-- Focus and move panes
rex.bind("cmd+h", "pane.focus", { direction = "left" })
rex.bind("cmd+j", "pane.focus", { direction = "down" })
rex.bind("cmd+k", "pane.focus", { direction = "up" })
rex.bind("cmd+l", "pane.focus", { direction = "right" })
rex.bind("shift+cmd+h", "pane.move", { direction = "left" })
rex.bind("shift+cmd+j", "pane.move", { direction = "down" })
rex.bind("shift+cmd+k", "pane.move", { direction = "up" })
rex.bind("shift+cmd+l", "pane.move", { direction = "right" })

-- Resize
rex.bind("ctrl+cmd+h", "pane.resize", { direction = "left" })
rex.bind("ctrl+cmd+j", "pane.resize", { direction = "down" })
rex.bind("ctrl+cmd+k", "pane.resize", { direction = "up" })
rex.bind("ctrl+cmd+l", "pane.resize", { direction = "right" })

rex.mode("resize", { exclusive = true })
rex.bind("cmd+r", "client.mode.enter", { name = "resize" })
rex.bind("resize/h", "pane.resize", { direction = "left" })
rex.bind("resize/j", "pane.resize", { direction = "down" })
rex.bind("resize/k", "pane.resize", { direction = "up" })
rex.bind("resize/l", "pane.resize", { direction = "right" })
rex.bind("resize/left", "pane.resize", { direction = "left" })
rex.bind("resize/down", "pane.resize", { direction = "down" })
rex.bind("resize/up", "pane.resize", { direction = "up" })
rex.bind("resize/right", "pane.resize", { direction = "right" })
rex.bind("resize/cmd+j", "pane.focus", { direction = "down" })
rex.bind("resize/cmd+k", "pane.focus", { direction = "up" })
rex.bind("resize/cmd+l", "pane.focus", { direction = "right" })
rex.bind("resize/esc", "client.mode.exit")
rex.bind("resize/enter", "client.mode.exit")
rex.bind("resize/q", "client.mode.exit")
