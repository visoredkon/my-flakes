{
  pkgs,
  release,
  ...
}:

(pkgs.buildVscode {
  pname = "antigravity";
  inherit (release) version vscodeVersion;
  executableName = "antigravity";
  iconName = "antigravity";
  libraryName = "antigravity";
  longName = "Antigravity";
  shortName = "Antigravity";
  src = pkgs.fetchurl {
    inherit (release) sha256 url;
  };
  sourceRoot = "Antigravity";
  commandLineArgs = "--password-store=gnome-libsecret";
  customizeFHSEnv =
    args:
    args
    // {
      extraBwrapArgs = (args.extraBwrapArgs or [ ]) ++ [ "--tmpfs /opt/google/chrome" ];
      extraBuildCommands = (args.extraBuildCommands or "") + ''
        mkdir -p "$out/opt/google/chrome"
      '';
      runScript = pkgs.writeShellScript "antigravity-wrapper" ''
        for candidate in google-chrome-stable google-chrome chromium-browser chromium; do
          if target=$(command -v "$candidate"); then
            ${pkgs.coreutils}/bin/ln -sf "$target" /opt/google/chrome/chrome
            break
          fi
        done
        exec ${args.runScript} "$@"
      '';
    };
  meta = { };
  tests = { };
  updateScript = null;
}).fhs
