--- === RestoreWindows ===
---
--- Restore window locations of tracked apps on screen changes or app launches.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "RestoreWindows"
obj.version = "0.1"
obj.author = "Matthew Fallshaw <m@fallshaw.me>"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/matthewfallshaw/RestoreWindows.spoon"

--- RestoreWindows.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
local logger = hs.logger.new("RestoreWindows")

--- RestoreWindows.locationFunction
--- Variable
--- Function to select which position set to restore windows to
---
--- Notes:
---  * The function should take no arguments and return a string matching a location in RestoreWindows.appLayouts
obj.locationFunction = nil

--- RestoreWindows.appLayouts
--- Variable
--- A table mapping applications, locations and screen layouts
---
--- Notes:
---  * A table mapping locations to applications to either a table to be used by hs.layout.apply (with app name prepended) or a string to be run as Applescript
--- 
--- Example:
---  ```
---    spoon.RestoreWindows.appLayouts = {
---      ["*"] = {
---             -- {window title, screen name, unit rect, frame rect, full-frame rect}
---        Morty = {nil, "Color LCD", hs.geometry.unitrect(0,0,0.7,1), nil, nil},
---      },
---      Canning = {
---        MacVim = {nil, "SyncMaster", hs.layout.left50, nil, nil},
---        Terminal = {nil, "SyncMaster", hs.layout.right50, nil, nil},
---        ["Google Chrome"] = [[
---    tell script "Raise in Chrome Library.scpt"
---      restoreChromeWindow("https://mail.google.com/mail/u/0/", " - Gmail", "Gmail", {0, 23}, {1111, 873}, "ui=2")
---    end tell
---      ]],
---      },
---      Fitzroy = {
---        MacVim = {nil, "DELL 2408WFP", hs.layout.left50, nil, nil},
---        Terminal = {nil, "DELL 2408WFP", hs.layout.right50, nil, nil},
---        ["Google Chrome"] = [[
---    tell script "Raise in Chrome Library.scpt"
---      restoreChromeWindow("https://mail.google.com/mail/u/0/", " - Gmail", "Gmail", {0, 23}, {1111, 873}, "ui=2")
---    end tell
---      ]],
---      },
---      Roaming = {
---        MacVim = {nil, "Color LCD", hs.layout.left50, nil, nil},
---        Terminal = {nil, "Color LCD", hs.layout.right50, nil, nil},
---        ["Google Chrome"] = [[
---    tell script "Raise in Chrome Library.scpt"
---      restoreChromeWindow("https://mail.google.com/mail/u/0/", " - Gmail", "Gmail", {0, 23}, {1111, 873}, "ui=2")
---    end tell
---      ]],
---      },
---    }
---  ```
obj.appLayouts = {}

--- RestoreWindows.restoreOrChooser()
--- Function
--- Run once in 500ms, triggers `restoreWindows`. Run twice in 500ms, displays a chooser of available actions.
---
--- Parameters:
---  * None
---
--- Returns:
---  * nil
function obj:restoreOrChooser()
  if not self.double_tap_timer then
    self.double_tap_timer = hs.timer.doAfter(0.5, function() self:restoreWindows(); self.double_tap_timer = nil end)
  else
    self.double_tap_timer:stop()
    self.double_tap_timer = nil
    if self.chooser:isVisible() then
      self.chooser:hide()
    else
      self.chooser:show()
    end
  end
  return nil
end

--- RestoreWindows.restoreWindows()
--- Function
--- Restore all tracked windows to their places.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The RestoreWindows object
function obj:restoreWindows()
  local loc = self:location()
  local layouts = self:appLayoutsForCurrentLocation()
  for app, layout in pairs(layouts) do
    self:applyLayout(app, layout)
  end
  return self
end

--- RestoreWindows.restoreFrontmost()
--- Function
--- Restores the position of the frontmost window.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The frontmost application
function obj:restoreFrontmost()
  local frontmostApplication = hs.window.frontmostWindow():application()
  local appname = frontmostApplication:name()
  self:applyLayout(appname, self:appLayoutsForCurrentLocation()[appname])
  return frontmostApplication
end

--- RestoreWindows.reportFrontmost()
--- Function
--- Reports the current position of the frontmost window to the hs.console. Merge this with your appLayouts to store the current window position.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The frontmost window
function obj:reportFrontmost()
  local previous_loglevel = logger.level
  logger.level = 'info'

  local frontmost = hs.window.frontmostWindow()
  local rect = frontmost:frame()
  local unitrect = rect:toUnitRect(hs.screen.mainScreen():frame())
  
  local for_layout = "RestoreWindows.appLayouts\n  ".. obj:location().. [[ = {
    ]].. hs.application.frontmostApplication():name() ..[[ = {nil, "]].. hs.screen.mainScreen():name() ..[[", hs.geometry.unitrect(]].. unitrect._x ..", ".. unitrect._y ..", ".. unitrect._w ..", ".. unitrect._h ..[[), nil, nil},
  }]]
  local for_absolute_frame = "Absolute frame:\n  x:".. rect._x ..", y:".. rect._y ..", w:".. rect._w ..", h:".. rect._h

  hs.pasteboard.setContents(for_layout)
  hs.alert("Active window position saved to pasteboard, details in Hammerspoon console")
  logger.i("\n".. for_layout .. "\n" .. for_absolute_frame)

  logger.level = previous_loglevel
  return frontmost
end

obj.hotkeys = {}

function obj:init()
  self.screenWatcher = hs.screen.watcher.new(function(...) self:screenWatcherCallback(...) end)
  self.appWatcher = hs.application.watcher.new(function(...) self:applicationWatcherCallback(...) end)

  self.chooser = hs.chooser.new(function(choice) logger.i(hs.inspect(choice)); if choice then self.actions[choice.action]() end end)
  self.chooser:rows(3)
  self.chooser:searchSubText(true)
  self.chooser:choices({
    { text = "Restore frontmost",
      subText = "Restore the location of the frontmost window",
      action = "restoreFrontmost",
    },
    { text = "Report frontmost",
      subText = "Report the location of the frontmost window, so that you can update your config to keep it there",
      action = "reportFrontmost",
    },
    {
      text = "Restore windows",
      subText = "Restore windows to their appointed places",
      action = "restoreWindows",
    },
  })

  self.actions = {
    restoreOrChooser = function() self:restoreOrChooser() end,
    restoreWindows          = function() self:restoreWindows() end,
    restoreFrontmost = function() self:restoreFrontmost() end,
    reportFrontmost  = function() self:reportFrontmost() end,
  }


  return self
end

--- RestoreWindows:start()
--- Method
--- Starts RestoreWindows
---
--- Parameters:
---  * None
---
--- Returns:
---  * The RestoreWindows object
function obj:start()
  self.screenWatcher:start()
  self.appWatcher:start()
  return self
end

--- RestoreWindows:stop()
--- Method
--- Stops RestoreWindows
---
--- Parameters:
---  * None
---
--- Returns:
---  * The RestoreWindows object
function obj:stop()
  self.screenWatcher:stop()
  self.appWatcher:stop()
  return self
end

--- RestoreWindows.raise(appname, title_match, frame)
--- Function
--- Raises the appname window with supplied title and frame
---
--- Parameters:
---  * appname - The name of the application
---  * title_match - string.match for the window title
---  * frame - hs.geometry.rect to search for the window
---
--- Returns:
---  * The RestoreWindows object
function obj.raise(appname, title)
  logger.i("RestoreWindows.raise(".. appname ..", ".. title)
  hs.application.get(appname):getWindow(title):focus()
end

--- RestoreWindows:bindHotkeys(mapping)
--- Method
--- Binds hotkey for RestoreWindows
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * restoreOrChooser - Single tap for restoreWindows, double tap for an action chooser
---   * restoreWindows - Restore windows to positions for spoon.RestoreWindows:location()
---   * restoreFrontmost - Restore just the windows of the frontmost application
---   * reportFrontmost - Report the position of the frontmost window (which you might add to your appLayouts)
--- 
--- Returns:
---  * The RestoreWindows object
function obj:bindHotkeys(mapping)
  for k,v in pairs(mapping) do
    assert(self.actions[k], "Hotkey requested for undefined action '%s'", name)
    if self.hotkeys[k] then self.hotkeys[k]:delete() end
    local mods, hotkey = mapping[k][1], mapping[k][2]
    self.hotkeys[k] = hs.hotkey.bind(mods, hotkey, self.actions[k])
  end
  return self
end

-- private variables and methods -----------------------------------------
function obj:appLayoutsForCurrentLocation()
  local loc = self:location()
  for k,v in pairs(self.appLayouts["*"] or {}) do
    self.appLayouts[loc][k] = v
  end
  return self.appLayouts[loc]
end

function obj:applyLayout(app_name, layout)
  if hs.application.get(app_name) then
    logger.i("Restoring windows for ".. app_name .." at ".. self:location())
    if type(layout) == "table" then
      hs.layout.apply({{app_name, layout[1], layout[2], layout[3], layout[4], layout[5]}}, string.match)
    elseif type(layout) == "string" then
      hs.osascript.applescript(layout)
    end
  end
end

function obj:screenWatcherCallback()
  self:restoreWindows()
end

function obj:applicationWatcherCallback(appname, event, app)
  if event == hs.application.watcher.launched and self.appLayouts[self:location()][appname] then
    self:applyLayout(appname, self.appLayouts[self:location()][appname])
  end
end

function obj:location()
  local loc_error = "RestoreWindows.locationFunction needs to be a function that will return a string matching a location in RestoreWindows.appLayouts"
  assert(self.locationFunction, loc_error)
  assert(type(self.locationFunction) == "function", loc_error)

  local loc = self.locationFunction()
  if not self.appLayouts[loc] then logger.i("No layouts for location ".. loc) end
  return loc
end

return obj
