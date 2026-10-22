{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.delta).overrideAttrs optimization.withRustOptimizations
