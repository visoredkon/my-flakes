{
  optimization,
  pkgs,
}:

pkgs.walker.overrideAttrs optimization.withRustOptimizations
