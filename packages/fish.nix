{
  optimization,
  pkgs,
}:

(pkgs.fish.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  optimization.withCMakeClangMold
