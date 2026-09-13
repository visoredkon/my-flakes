{
  optimization,
  pkgs,
}:

(pkgs.fd.override { stdenv = pkgs.llvmPackages.stdenv; }).overrideAttrs
  optimization.withRustOptimizations
