{
  optimization,
  pkgs,
}:

(pkgs.kitty.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  optimization.moldEnv
