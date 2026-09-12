{
  optimization,
  pkgs,
}:

pkgs.bat.overrideAttrs (optimization.withRustOptimizations { })
