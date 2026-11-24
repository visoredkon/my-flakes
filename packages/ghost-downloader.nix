{
  lib,
  pkgs,
  release,
  urlTemplate,
  ...
}:

let
  inherit (release) version;

  src = pkgs.fetchurl {
    inherit (release) sha256;
    url = builtins.replaceStrings [ "{version}" ] [ version ] urlTemplate;
  };

  ytDlp = pkgs.python313Packages.yt-dlp.overridePythonAttrs (_: rec {
    version = "2026.11.23";
    src = pkgs.fetchFromGitHub {
      owner = "yt-dlp";
      repo = "yt-dlp";
      tag = version;
      hash = "sha256-BpxnzY9GOs9sTv/ZWAwYiiJS7VfaMtp5HHOtXDAGgc0=";
    };
  });

  ytDlpPython = pkgs.python313.withPackages (_: [ ytDlp ]);
  ytDlpSite = "${ytDlpPython}/${pkgs.python313.sitePackages}";

  gsettings = pkgs.writeShellScriptBin "gsettings" ''
    readPortalScheme() {
      output=$(${pkgs.glib.bin}/bin/gdbus call --session \
        --dest org.freedesktop.portal.Desktop \
        --object-path /org/freedesktop/portal/desktop \
        --method org.freedesktop.portal.Settings.Read \
        org.freedesktop.appearance color-scheme 2>/dev/null || true)

      case "$output" in
        *"uint32 1"*) echo "prefer-dark" ;;
        *"uint32 2"*) echo "prefer-light" ;;
      esac
    }

    if [ "$1" = "get" ] && [ "$2" = "org.gnome.desktop.interface" ] && [ "$3" = "color-scheme" ]; then
      scheme="$(readPortalScheme)"

      if [ -n "$scheme" ]; then
        printf "'%s'\n" "$scheme"
        exit 0
      fi
    fi

    exec ${pkgs.glib.bin}/bin/gsettings "$@"
  '';

  runtimePath = lib.makeBinPath [
    gsettings
    pkgs.ffmpeg-headless
    pkgs.n-m3u8dl-re
    pkgs.quickjs-ng
  ];

  syncFeatures = pkgs.writeShellApplication {
    name = "ghost-downloader-sync-features";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = ''
      seedDir="$1"
      wrapper="$2"

      if [ -z "''${HOME:-}" ]; then
        exit 0
      fi

      homeDir="$HOME"

      case "''${XDG_DATA_HOME:-}" in
        /*) dataHome="$XDG_DATA_HOME" ;;
        *) dataHome="$homeDir/.local/share" ;;
      esac

      dataDir="$dataHome/GhostDownloader"
      featuresDir="$dataDir/features"

      manifestVersion() {
        sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -n 1
      }

      normalizeVersion() {
        normalized="$(printf '%s' "$1" | sed -E 's/^[vV]//; s/\.\.+.*$//; s/[^0-9.].*$//; s/(^|\.)0+([0-9])/\1\2/g')"

        case "$normalized" in
          .*) normalized="" ;;
        esac

        while [ "''${normalized%.0}" != "$normalized" ]; do
          normalized="''${normalized%.0}"
        done

        case "$normalized" in
          "" | 0) normalized="" ;;
        esac

        printf '%s' "$normalized"
      }

      if [ -d "$featuresDir" ]; then
        chmod -R u+w "$featuresDir" || true
      fi

      if [ -d "$seedDir" ]; then
        mkdir -p "$featuresDir"

        for seedPack in "$seedDir"/*; do
          [ -d "$seedPack" ] || continue
          name="$(basename "$seedPack")"

          case "$name" in
            .* | *_pending) continue ;;
          esac

          [ -f "$seedPack/manifest.toml" ] || continue

          seedVersion="$(manifestVersion "$seedPack/manifest.toml")"
          [ -n "$seedVersion" ] || continue

          userPack="$featuresDir/$name"
          userVersion=""

          if [ -f "$userPack/manifest.toml" ]; then
            userVersion="$(manifestVersion "$userPack/manifest.toml")"
          fi

          seedNorm="$(normalizeVersion "$seedVersion")"
          userNorm="$(normalizeVersion "$userVersion")"

          if [ -n "$userVersion" ]; then
            newest="$(printf '%s\n%s\n' "$userNorm" "$seedNorm" | sort -V | tail -n 1)"
            if [ "$newest" = "$userNorm" ]; then
              continue
            fi
          fi

          tmpPack="$featuresDir/.$name.new"
          oldPack="$featuresDir/.$name.old"

          rm -rf "$tmpPack" "$oldPack"
          cp -r "$seedPack" "$tmpPack"
          chmod -R u+w "$tmpPack"

          if [ -e "$userPack" ]; then
            mv "$userPack" "$oldPack"
          fi

          mv "$tmpPack" "$userPack"
          rm -rf "$oldPack"
        done
      fi

      ytDlpDir="$dataDir/YtDlp"
      mkdir -p "$ytDlpDir"

      if [ -L "$ytDlpDir/yt_dlp" ] || [ ! -e "$ytDlpDir/yt_dlp" ]; then
        if [ -d "${ytDlpSite}/yt_dlp" ]; then
          ln -sfn "${ytDlpSite}/yt_dlp" "$ytDlpDir/yt_dlp"
        fi
      fi

      for ytDlpConfig in "$featuresDir/yt_dlp_pack/config.py" "$featuresDir/yt_dlp_pack_pending/config.py"; do
        [ -f "$ytDlpConfig" ] || continue
        chmod u+w "$ytDlpConfig" 2>/dev/null || true

        if ! grep -Fq 'not (self.installFolder() / "yt_dlp").is_symlink()' "$ytDlpConfig"; then
          sed -i -E 's#^([[:space:]]*)return \(self\.installFolder\(\) / "yt_dlp" / "__init__\.py"\)\.is_file\(\)$#\1return not (self.installFolder() / "yt_dlp").is_symlink() and (self.installFolder() / "yt_dlp" / "__init__.py").is_file()#' "$ytDlpConfig" || true
          grep -Fq 'not (self.installFolder() / "yt_dlp").is_symlink()' "$ytDlpConfig" || echo "ghost-downloader: failed to patch $ytDlpConfig" >&2
        fi
      done

      for launcher in \
        "$homeDir/.local/share/applications/com.xychr.ghostdownloader.desktop" \
        "$homeDir/.config/autostart/com.xychr.ghostdownloader.desktop" \
        "$homeDir/.local/share/dbus-1/services/com.xychr.ghostdownloader.service"; do
        [ -f "$launcher" ] || continue

        if ! grep -Fq "\"$wrapper\"" "$launcher" && grep -Eq '"(/[^"]*/(bin/ghost-downloader|lib/ghost-downloader/Ghost-Downloader-3\.bin))"' "$launcher"; then
          chmod u+w "$launcher" 2>/dev/null || true
          sed -i -E "s#\"[^\"]*(/bin/ghost-downloader|/lib/ghost-downloader/Ghost-Downloader-3\.bin)\"#\"$wrapper\"#g" "$launcher" || true
        fi
      done

      ghd="$homeDir/.local/bin/ghd"

      if [ -L "$ghd" ] && [ "$(readlink "$ghd")" != "$wrapper" ]; then
        ln -sfn "$wrapper" "$ghd"
      fi
    '';
  };
in
pkgs.stdenv.mkDerivation {
  pname = "ghost-downloader";
  inherit version src;

  sourceRoot = ".";
  noDumpEnvVars = true;

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = with pkgs; [
    stdenv.cc.cc.lib
    zstd
    libGL
    libxkbcommon
    dbus
    fontconfig
    freetype
    glib
    libxcb
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm
    libxcb-cursor
    wayland
    cups
    krb5
    gtk3
  ];

  installPhase = ''
    mkdir -p $out/lib/ghost-downloader
    mkdir -p $out/bin
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/256x256/apps

    cp -a . $out/lib/ghost-downloader

    rm -f $out/lib/ghost-downloader/PySide6/qt-plugins/imageformats/libqtiff.so
    rm -f $out/lib/ghost-downloader/PySide6/qt-plugins/platforms/libqeglfs.so
    rm -f $out/lib/ghost-downloader/PySide6/qt-plugins/platforms/libqlinuxfb.so
    rm -rf $out/lib/ghost-downloader/PySide6/qt-plugins/egldeviceintegrations
    rm -f $out/lib/ghost-downloader/libQt6EglFSDeviceIntegration.so.6
    rm -f $out/lib/ghost-downloader/libQt6EglFsKmsSupport.so.6
    rm -f $out/lib/ghost-downloader/libQt6VirtualKeyboardQml.so.6

    makeWrapper $out/lib/ghost-downloader/Ghost-Downloader-3.bin $out/bin/ghost-downloader \
      --prefix PATH : "${runtimePath}" \
      --set PYTHONPATH "${ytDlpSite}" \
      --prefix QT_PLUGIN_PATH : "$out/lib/ghost-downloader/PySide6/qt-plugins" \
      --set APPIMAGE "$out/bin/ghost-downloader" \
      --run "${syncFeatures}/bin/ghost-downloader-sync-features $out/lib/ghost-downloader/features $out/bin/ghost-downloader || echo 'ghost-downloader: feature sync failed' >&2" \
      --set QT_QPA_PLATFORMTHEME gtk3 \
      --unset QT_STYLE_OVERRIDE

    install -m 444 ${./ghost-downloader-logo.png} $out/share/icons/hicolor/256x256/apps/ghost-downloader.png

    cat > $out/share/applications/com.xychr.ghostdownloader.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Ghost Downloader
    Comment=The only downloader you need
    Exec=ghost-downloader %U
    Icon=ghost-downloader
    Terminal=false
    Categories=Network;
    StartupNotify=false
    EOF
  '';

  meta = {
    description = "The only downloader you need";
    homepage = "https://github.com/XiaoYouChR/Ghost-Downloader-3";
    license = lib.licenses.gpl3Only;
    mainProgram = "ghost-downloader";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
