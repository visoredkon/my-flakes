{
  optimization,
  pkgs,
  release,
  ...
}:

(optimization.llvmStdenvWithArgs {
  cavaSupport = false;
  gpsSupport = false;
} pkgs.waybar).overrideAttrs
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
