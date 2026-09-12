{
  optimization,
  pkgs,
}:

pkgs.easyeffects.overrideAttrs (
  old:
  (optimization.withMesonClangMold old)
  // {
    doCheck = false;
  }
)
