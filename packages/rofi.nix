{
  optimization,
  pkgs,
}:

pkgs.rofi.override {
  rofi-unwrapped = pkgs.rofi-unwrapped.overrideAttrs optimization.withMesonClangMold;
}
