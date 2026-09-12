{
  optimization,
  pkgs,
}:

(pkgs.swappy.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  optimization.withMesonClangMold
