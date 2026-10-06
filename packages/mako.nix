{
  optimization,
  pkgs,
}:

(pkgs.mako.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  optimization.withMesonClangMold
