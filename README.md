# [Abandoned] RestoreWindows.spoon

(Abandoned. I no longer use this spoon, preferring 
https://github.com/matthewfallshaw/dotfiles/blob/master/hammerspoon/stay.lua .)

A Spoon for Hammerspoon. Restore tracked window locations on screen changes.


## Install

Copy directory as RestoreWindows.spoon to ~/.hammerspoon/Spoons/
Include `hs.loadSpoon("RestoreWindows")` in your ~/.hammerspoon/init.lua before any other `spoon.RestoreWindows` code.


## Use

In your ~/.hammerspoon/init.lua you might include something like:

    spoon.RestoreWindows:bindHotkeys({
      restore = {{"⌘", "⌥", "⌃", "⇧"}, "s"}
    })
