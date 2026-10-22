{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.neovim-unwrapped).overrideAttrs optimization.withCMakeClangMold
