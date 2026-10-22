{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.wayvnc).overrideAttrs optimization.withMesonClangMold
