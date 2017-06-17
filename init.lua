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
---    -- restoreChromeWindow(target_url_start, target_title_end, target_tab_name, target_position, target_size, target_url_exclude)
---
---    tell script "Raise in Chrome Library.scpt"
---      restoreChromeWindow("https://mail.google.com/mail/u/0/", " - Gmail", "Gmail", {0, 23}, {1111, 873}, "ui=2")
---      restoreChromeWindow("https://drive.google.com/drive/u/0/", " - Google Drive", "Personal Docs", {-1526, -481}, {1190, 1080}, "")
---    end tell
---      ]],
---      },
---      Fitzroy = {
---        MacVim = {nil, "DELL 2408WFP", hs.layout.left50, nil, nil},
---        Terminal = {nil, "DELL 2408WFP", hs.layout.right50, nil, nil},
---        ["Google Chrome"] = [[
---    -- restoreChromeWindow(target_url_start, target_title_end, target_tab_name, target_position, target_size, target_url_exclude)
---
---    tell script "Raise in Chrome Library.scpt"
---      restoreChromeWindow("https://mail.google.com/mail/u/0/", " - Gmail", "Gmail", {0, 23}, {1111, 873}, "ui=2")
---      restoreChromeWindow("https://drive.google.com/drive/u/0/", " - Google Drive", "Personal Docs", {-1526, -300}, {1190, 1200}, "")
---    end tell
---      ]],
---      },
---      Roaming = {
---        MacVim = {nil, "Color LCD", hs.layout.left50, nil, nil},
---        Terminal = {nil, "Color LCD", hs.layout.right50, nil, nil},
---        ["Google Chrome"] = [[
---    -- restoreChromeWindow(target_url_start, target_title_end, target_tab_name, target_position, target_size)
---
---    tell script "Raise in Chrome Library.scpt"
---      restoreChromeWindow("https://mail.google.com/mail/u/0/", " - Gmail", "Gmail", {0, 23}, {1111, 873}, "ui=2")
---      restoreChromeWindow("https://drive.google.com/drive/u/0/", " - Google Drive", "Personal Docs", {0, 23}, {1111, 873})
---    end tell
---      ]],
---      },
---    }
---  ```
obj.appLayouts = {}

--- RestoreWindows.reportFrontmost()
--- Function
--- Reports the current position of the frontmost window to the hs.console. Merge this with your appLayouts to restore the window to this position.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The RestoreWindows object
function obj.reportFrontmost()
  local previous_loglevel = logger.level
  logger.level = 'info'

  unitrect = hs.window.frontmostWindow():frame():toUnitRect(hs.screen.mainScreen():frame())
  
  local frontmost = "\n  ".. obj.location().. [[ = {
    ]].. hs.application.frontmostApplication():name() ..[[ = {nil, "]].. hs.screen.mainScreen():name() ..[[", hs.geometry.unitrect(]].. unitrect._x ..", ".. unitrect._y ..", ".. unitrect._w ..", ".. unitrect._h ..[[), nil, nil},
  }]]
  logger.i(frontmost)
  hs.alert(frontmost)
  hs.pasteboard.setContents(frontmost)

  logger.level = previous_loglevel
  return obj
end

obj.hotkeys = {}

function obj:init()
  self.screenWatcher = hs.screen.watcher.new(self.screenWatcherCallback)
  self.appWatcher = hs.application.watcher.new(self.applicationWatcherCallback)
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

--- RestoreWindows:bindHotkeys(mapping)
--- Method
--- Binds hotkey for RestoreWindows
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * restore - Restore windows to positions for spoon.RestoreWindows:location()
--- 
--- Returns:
---  * The RestoreWindows object
function obj:bindHotkeys(mapping)
  methods = {
    restore = self.screenWatcherCallback,
    reportFrontmost = self.reportFrontmost,
  }
  for k,v in pairs(mapping) do
    assert(methods[k], "Hotkey requested for undefined action '%s'", name)
    if self.hotkeys[k] then self.hotkeys[k]:delete() end
    local mods, hotkey = mapping[k][1], mapping[k][2]
    self.hotkeys[k] = hs.hotkey.bind(mods, hotkey, methods[k])
  end
  return self
end

-- private variables and methods -----------------------------------------
function obj:appLayoutsForCurrentLocation()
  local loc = self.location()
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

function obj.screenWatcherCallback()
  local loc = obj:location()
  local layouts = obj:appLayoutsForCurrentLocation()
  for app, layout in pairs(layouts) do
    obj:applyLayout(app, layout)
  end
end

function obj.applicationWatcherCallback(appname, event, app)
  if event == hs.application.watcher.launched and obj.appLayouts[obj.location()][appname] then
    obj:applyLayout(appname, obj.appLayouts[obj:location()][appname])
  end
end

function obj.location()
  logger.i(hs.inspect(obj.locationFunction))
  local loc_error = "RestoreWindows.locationFunction needs to be a function that will return a string matching a location in RestoreWindows.appLayouts"
  assert(obj.locationFunction, loc_error)
  assert(type(obj.locationFunction) == "function", loc_error)

  local loc = obj.locationFunction()
  if not obj.appLayouts[loc] then logger.w("No layouts for location ".. loc) end
  return loc
end

return obj
