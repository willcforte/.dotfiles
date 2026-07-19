local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'GruvboxLight'
local is_mac = wezterm.target_triple:find('apple') ~= nil
local regular_weight = is_mac and 375 or 'Medium'

-- Load this font straight from its file rather than via the system
-- fontconfig lookup: fontconfig mis-resolves this font's named instances at
-- the default (non-condensed) width, silently landing on an oblique cut
-- for supposedly-upright text. Pointing font_dirs at it makes WezTerm use
-- its own internal font scanner instead, which resolves the same file
-- correctly.
config.font_dirs = { wezterm.home_dir .. '/.nix-profile/share/fonts/truetype' }
config.font = wezterm.font('Berkeley Mono Variable', {
  weight = regular_weight,
})
config.font_size = 18

config.font_rules = {
  {
    intensity = 'Bold',
    italic = false,
    font = wezterm.font('Berkeley Mono Variable', { weight = 'Bold' }),
  },
  {
    intensity = 'Half',
    italic = false,
    font = wezterm.font('Berkeley Mono Variable', { weight = regular_weight }),
  },
}
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
