{
  optimization,
  pkgs,
}:

(pkgs.delta.override { stdenv = pkgs.llvmPackages.stdenv; }).overrideAttrs
  optimization.withRustOptimizations
