{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.starship).overrideAttrs optimization.withRustOptimizations
