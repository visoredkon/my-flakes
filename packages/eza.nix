{
  optimization,
  pkgs,
}:

pkgs.eza.overrideAttrs optimization.withRustOptimizations
