{
  optimization,
  pkgs,
}:

(pkgs.starship.override { stdenv = pkgs.llvmPackages.stdenv; }).overrideAttrs
  optimization.withRustOptimizations
