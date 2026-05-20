{
  pkgs,
  release,
  urlTemplate,
  ...
}:

assert release ? sha256 && release.sha256 != "";
assert release ? version && release.version != "";
assert release ? vscodeVersion && release.vscodeVersion != "";

(pkgs.buildVscode {
  executableName = "kiro";
  inherit (release) version vscodeVersion;
  longName = "Kiro";
  meta = { };
  pname = "kiro";
  shortName = "kiro";
  src = pkgs.fetchurl {
    inherit (release) sha256;
    url = builtins.replaceStrings [ "{version}" ] [ release.version ] urlTemplate;
  };

  commandLineArgs = "--password-store=gnome-libsecret";
  sourceRoot = "Kiro";
  tests = { };
  updateScript = null;
}).fhs
