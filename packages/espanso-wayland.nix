{
  pkgs,
  securityWrapperPath ? null,
  wl-clipboard,
  ...
}:

pkgs.espanso-wayland.override { inherit securityWrapperPath wl-clipboard; }
