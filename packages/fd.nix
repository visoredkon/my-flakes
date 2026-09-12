{
  optimization,
  pkgs,
}:

pkgs.fd.overrideAttrs (optimization.withRustOptimizations { })
