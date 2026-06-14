{
  pkgs,
  release,
  ...
}:

assert release ? sha256 && release.sha256 != "";
assert release ? url && release.url != "";
assert release ? version && release.version != "";

let
  pname = "antigravity";
  inherit (release) version;

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

    nativeBuildInputs = with pkgs; [
      asar
      autoPatchelfHook
      copyDesktopItems
    ];

    desktopItems = [ antigravity-desktop ];

    buildInputs = with pkgs; [
      alsa-lib
      at-spi2-atk
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libglvnd
      libnotify
      libpulseaudio
      libuuid
      libX11
      libXScrnSaver
      libXcomposite
      libXcursor
      libXdamage
      libXext
      libXfixes
      libXi
      libXrandr
      libXrender
      libXtst
      libxcb
      libxkbcommon
      libxshmfence
      mesa
      nspr
      nss
      pango
      systemd
    ];

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

    sourceRoot = "Antigravity-x64";
  };
in
pkgs.buildFHSEnv {
  name = pname;

  targetPkgs =
    pkgs: with pkgs; [
      alsa-lib
      antigravity-base
      at-spi2-atk
      atk
      cairo
      coreutils
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gsettings-desktop-schemas
      gtk3
      libdrm
      libglvnd
      libGL
      libGLU
      libnotify
      libpulseaudio
      libuuid
      libX11
      libXScrnSaver
      libXcomposite
      libXcursor
      libXdamage
      libXext
      libXfixes
      libXi
      libXrandr
      libXrender
      libXtst
      libxcb
      libxkbcommon
      libxshmfence
      mesa
      nspr
      nss
      pango
      systemd
      xdg-utils
    ];

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

  meta = { };
}
