{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.fd).overrideAttrs optimization.withRustOptimizations
