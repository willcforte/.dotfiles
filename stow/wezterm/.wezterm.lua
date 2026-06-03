local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'GruvboxDark'
config.font = wezterm.font 'Iosevka Term SS18'
config.font_size = 18
config.initial_cols = 100
config.initial_rows = 24

config.hide_tab_bar_if_only_one_tab = true
config.hide_mouse_cursor_when_typing = false

return config
