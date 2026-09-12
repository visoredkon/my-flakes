{
  optimization,
  pkgs,
}:

pkgs.delta.overrideAttrs (optimization.withRustOptimizations { })
