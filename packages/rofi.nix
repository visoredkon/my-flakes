{
  optimization,
  pkgs,
}:

pkgs.rofi.override {
  rofi-unwrapped =
    (pkgs.rofi-unwrapped.override {
      stdenv = pkgs.llvmPackages.stdenv;
    }).overrideAttrs
      optimization.withMesonClangMold;
}
