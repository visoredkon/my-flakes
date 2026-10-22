{
  pkgs,
  release,
  ...
}:

let
  pname = "antigravity";
  inherit (release) version;

  sharedLibraryNames = [
    "alsa-lib"
    "at-spi2-atk"
    "atk"
    "cairo"
    "cups"
    "dbus"
    "expat"
    "fontconfig"
    "freetype"
    "gdk-pixbuf"
    "glib"
    "gtk3"
    "libdrm"
    "libglvnd"
    "libnotify"
    "libpulseaudio"
    "libuuid"
    "libX11"
    "libxcb"
    "libXcomposite"
    "libXcursor"
    "libXdamage"
    "libXext"
    "libXfixes"
    "libXi"
    "libxkbcommon"
    "libXrandr"
    "libXrender"
    "libXScrnSaver"
    "libxshmfence"
    "libXtst"
    "mesa"
    "nspr"
    "nss"
    "pango"
    "systemd"
  ];

  fhsLibraryNames = [
    "coreutils"
    "gsettings-desktop-schemas"
    "libGL"
    "libGLU"
    "xdg-utils"
  ];

  resolveLibraries = pkgs: names: map (name: pkgs.${name}) names;

  antigravity-desktop = pkgs.makeDesktopItem {
    name = pname;
    desktopName = "Antigravity";
    genericName = "Agentic Development Platform";
    comment = "AI-powered agentic development platform";
    exec = "${pname} %F";
    icon = pname;
    startupNotify = true;
    categories = [
      "Utility"
      "TextEditor"
      "Development"
      "IDE"
    ];
  };

  antigravity-base = pkgs.stdenvNoCC.mkDerivation {
    pname = "${pname}-base";
    inherit version;

    src = pkgs.fetchurl {
      inherit (release) sha256 url;
    };

    dontBuild = true;
    sourceRoot = "Antigravity-x64";

    buildInputs = resolveLibraries pkgs sharedLibraryNames;

    nativeBuildInputs = with pkgs; [
      asar
      autoPatchelfHook
      copyDesktopItems
    ];

    desktopItems = [ antigravity-desktop ];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/opt/antigravity"
      cp -r * "$out/opt/antigravity"
      chmod +x "$out/opt/antigravity/antigravity"

      mkdir -p "$out/bin"
      ln -s "$out/opt/antigravity/antigravity" "$out/bin/antigravity"

      mkdir -p "$out/opt/antigravity/asar-extract"
      asar extract "$out/opt/antigravity/resources/app.asar" "$out/opt/antigravity/asar-extract"

      mkdir -p "$out/share/pixmaps" "$out/share/icons/hicolor/512x512/apps"
      cp "$out/opt/antigravity/asar-extract/icon.png" "$out/share/pixmaps/${pname}.png"
      cp "$out/opt/antigravity/asar-extract/icon.png" "$out/share/icons/hicolor/512x512/apps/${pname}.png"

      rm -rf "$out/opt/antigravity/asar-extract"

      runHook postInstall
    '';
  };
in
pkgs.buildFHSEnv {
  name = pname;

  targetPkgs =
    pkgs:
    resolveLibraries pkgs sharedLibraryNames
    ++ resolveLibraries pkgs fhsLibraryNames
    ++ [ antigravity-base ];

  extraBwrapArgs = [
    "--tmpfs /opt/google/chrome"
  ];

  extraBuildCommands = ''
    mkdir -p "$out/opt/google/chrome"
  '';

  extraInstallCommands = ''
    ln -s "${antigravity-base}/share" "$out/"
  '';

  runScript = pkgs.writeShellScript "antigravity-fhs-wrapper" ''
    export ELECTRON_DISABLE_SANDBOX=1
    for candidate in google-chrome-stable google-chrome chromium-browser chromium; do
      if target=$(command -v "$candidate"); then
        ${pkgs.coreutils}/bin/ln -sf "$target" /opt/google/chrome/chrome
        break
      fi
    done
    exec antigravity "$@"
  '';
}
