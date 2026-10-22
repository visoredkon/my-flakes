{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.grim).overrideAttrs optimization.withMesonClangMold
