{
  optimization,
  pkgs,
}:

(pkgs.neovim-unwrapped.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  optimization.withCMakeClangMold
