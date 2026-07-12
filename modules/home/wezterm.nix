_: {
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wezterm = require('wezterm')
      return {
        font = wezterm.font('JetBrainsMono Nerd Font'),
        font_size = 12.0,
        color_scheme = 'Catppuccin Mocha',
        window_background_opacity = 0.95,
        window_padding = { left = 8, right = 8, top = 8, bottom = 8 },
        default_cursor_style = 'SteadyBlock',
        window_close_confirmation = 'NeverPrompt',
        hide_tab_bar_if_only_one_tab = true,
        enable_wayland = true,
        mux_enable_ssh_agent = false,
      }
    '';
  };
}
