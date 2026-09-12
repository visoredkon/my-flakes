{
  optimization,
  pkgs,
}:

(pkgs.slurp.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  optimization.withMesonClangMold
