{
  optimization,
  pkgs,
  ...
}:

pkgs.rofi.override {
  rofi-unwrapped = (optimization.llvmStdenv pkgs.rofi-unwrapped).overrideAttrs optimization.withMesonClangMold;
}
