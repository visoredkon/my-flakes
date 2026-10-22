{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.fish).overrideAttrs optimization.withCMakeClangMold
