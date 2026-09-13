{
  optimization,
  pkgs,
  release,
  ...
}:

assert release ? rev && release.rev != "";
assert release ? sourceSha256 && release.sourceSha256 != "";

(pkgs.waybar.override {
  cavaSupport = false;
  gpsSupport = false;
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  (
    old:
    let
      base = optimization.withMesonClangMoldMode "thin" old;
    in
    base
    // {
      src = pkgs.fetchFromGitHub {
        owner = "Alexays";
        repo = "Waybar";
        inherit (release) rev;
        hash = release.sourceSha256;
      };

      mesonFlags = base.mesonFlags ++ [
        "-Dtests=disabled"
        "-Dwwan=disabled"
      ];
    }
  )
