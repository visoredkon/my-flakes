{
  pkgs,
  wl-clipboard,
  ...
}:

pkgs.espanso-wayland.override { inherit wl-clipboard; }
