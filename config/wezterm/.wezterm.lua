local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'GruvboxLight'
config.font = wezterm.font 'Iosevka Term SS18'
config.font_size = 18
config.initial_cols = 100
config.initial_rows = 24

config.hide_tab_bar_if_only_one_tab = true
config.hide_mouse_cursor_when_typing = false

-- 'SystemBeep' is a no-op on Linux, so play the bell ourselves via the bell event.
config.audible_bell = 'SystemBeep'
wezterm.on('bell', function(window, pane)
  wezterm.log_info('bell fired')
  wezterm.background_child_process {
    '/bin/sh', '-c',
    '/usr/bin/paplay /usr/share/sounds/freedesktop/stereo/bell.oga 2>/tmp/wez-bell.log',
  }
end)

-- Brief background flash on bell (visual bell).
config.visual_bell = {
  fade_in_function = 'EaseIn',
  fade_in_duration_ms = 75,
  fade_out_function = 'EaseOut',
  fade_out_duration_ms = 150,
}
config.colors = {
  visual_bell = '#504945', -- gruvbox bg2: visible flash against the dark bg
}

-- Temporary fix for title bar not showing on Wayland
config.enable_wayland = false

config.keys = {
  -- Send SIGINT
  { key = 'c', mods = 'SUPER', action = wezterm.action.SendKey { key = 'c', mods = 'CTRL' } },
  -- Copy selection
  { key = 'c', mods = 'CTRL', action = wezterm.action.CopyTo 'Clipboard' },
  -- Paste
  { key = 'v', mods = 'CTRL', action = wezterm.action.PasteFrom 'Clipboard' },
}

return config
