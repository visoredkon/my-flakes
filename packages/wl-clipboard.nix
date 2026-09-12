{
  optimization,
  pkgs,
}:

(pkgs.wl-clipboard.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  optimization.withMesonClangMold
