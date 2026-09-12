{
  optimization,
  pkgs,
}:

(pkgs.grim.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  optimization.withMesonClangMold
