{
  optimization,
  pkgs,
}:

pkgs.ripgrep.overrideAttrs optimization.withRustOptimizations
