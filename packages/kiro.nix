{
  pkgs,
  release,
  urlTemplate,
  ...
}:

(pkgs.buildVscode {
  pname = "kiro";
  inherit (release) version vscodeVersion;
  executableName = "kiro";
  longName = "Kiro";
  shortName = "kiro";
  src = pkgs.fetchurl {
    url = builtins.replaceStrings [ "{version}" ] [ release.version ] urlTemplate;
    inherit (release) sha256;
  };
  sourceRoot = "Kiro";
  commandLineArgs = "--password-store=gnome-libsecret";
  meta = { };
  tests = { };
  updateScript = null;
}).fhs
