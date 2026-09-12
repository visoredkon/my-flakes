{
  optimization,
  pkgs,
}:

(pkgs.fastfetch.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  optimization.withCMakeClangMold
