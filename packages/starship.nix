{
  optimization,
  pkgs,
}:

pkgs.starship.overrideAttrs (optimization.withRustOptimizations { lto = "fat"; })
