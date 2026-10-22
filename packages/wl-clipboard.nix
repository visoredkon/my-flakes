{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.wl-clipboard).overrideAttrs optimization.withMesonClangMold
