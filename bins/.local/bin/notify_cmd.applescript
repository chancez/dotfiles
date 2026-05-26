#!/usr/bin/env osascript

on run argv
  tell application "System Events"
    set frontApp to name of first application process whose frontmost is true
    # Only show notifications if the frontmost app is not kitty, to avoid
    # showing notifications for everything you do.
    if frontApp is not "kitty" then
      set notifTitle to item 1 of argv
      set notifBody to "succeeded"
      set errorCode to item 2 of argv
      if errorCode is not "0"
        set notifBody to "failed with error code " & errorCode
      end if
      display notification notifBody with title notifTitle
    end if
  end tell
end run
