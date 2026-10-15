{
  optimization,
  pkgs,
  rofi-unwrapped ? null,
  theme ? null,
  plugins ? [ ],
  symlink-dmenu ? false,
  ...
}:

pkgs.rofi.override {
  inherit plugins theme symlink-dmenu;
  rofi-unwrapped =
    if rofi-unwrapped != null then
      rofi-unwrapped
    else
      (pkgs.rofi-unwrapped.override {
        stdenv = pkgs.llvmPackages.stdenv;
      }).overrideAttrs
        optimization.withMesonClangMold;
}
