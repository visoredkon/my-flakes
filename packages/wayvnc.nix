{
  optimization,
  pkgs,
}:

(pkgs.wayvnc.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  optimization.withMesonClangMold
