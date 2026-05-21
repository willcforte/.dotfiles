local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'GruvboxDark'
config.font = wezterm.font 'Iosevka Nerd Font'
config.font_size = 20
config.initial_cols = 100
config.initial_rows = 24

return config
