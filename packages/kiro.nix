{
  pkgs,
  release,
  urlTemplate,
  ...
}:

assert release ? sha256 && release.sha256 != "";
assert release ? version && release.version != "";
assert release ? vscodeVersion && release.vscodeVersion != "";

let
  base = pkgs.buildVscode {
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
  };

  patched = base.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      for f in $out/share/applications/kiro*.desktop; do
        substituteInPlace "$f" --replace-fail "Keywords=vscode" "Keywords="
        substituteInPlace "$f" --replace-fail "Comment=Code Editing. Redefined." "Comment=Agentic development environment for shipping real engineering work with AI agents"
      done
    '';
  });
in
patched.fhs
