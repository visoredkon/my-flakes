{
  optimization,
  pkgs,
}:

pkgs.zoxide.overrideAttrs optimization.withRustOptimizations
