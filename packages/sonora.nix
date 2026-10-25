{
  lib,
  pkgs,
  release,
  urlTemplate,
  ...
}:

let
  pname = "sonora";
  inherit (release) version;

  src = pkgs.fetchurl {
    inherit (release) sha256;
    url = builtins.replaceStrings [ "{version}" ] [ release.version ] urlTemplate;
  };

  assets = pkgs.fetchurl {
    sha256 = release.sourceSha256;
    url = "https://github.com/sonorahq/sonora/archive/refs/tags/v${version}.tar.gz";
  };

  runtimeLibraries = with pkgs; [
    alsa-lib
    dbus
    fontconfig
    freetype
    glib-networking
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    sqlite
    stdenv.cc.cc.lib
    vulkan-loader
    wayland
    webkitgtk_4_1
  ];

  gstPluginPath = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" (
    with pkgs.gst_all_1;
    [
      gstreamer
      gst-plugins-base
      gst-plugins-good
    ]
  );

  alsaPlugins = pkgs.symlinkJoin {
    name = "sonora-alsa-plugins";
    paths = [
      "${pkgs.pipewire}/lib/alsa-lib"
      "${pkgs.alsa-plugins}/lib/alsa-lib"
    ];
  };
in
pkgs.stdenv.mkDerivation {
  inherit pname version src;

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = with pkgs; [
    gnutar
    makeWrapper
    patchelf
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/sonora"

    assetsDir=$(mktemp -d)
    tar --extract --gzip --file "${assets}" --directory "$assetsDir"
    linuxAssets="$assetsDir/${pname}-${version}/assets/linux"

    install -Dm444 "$linuxAssets/sonora.desktop" "$out/share/applications/sonora.desktop"
    install -Dm444 "$linuxAssets/sonora.svg" "$out/share/icons/hicolor/scalable/apps/sonora.svg"
    for icon in "$linuxAssets"/icons/hicolor/*/apps/sonora.png; do
      size="$(basename "$(dirname "$(dirname "$icon")")")"
      install -Dm444 "$icon" "$out/share/icons/hicolor/$size/apps/sonora.png"
    done

    runHook postInstall
  '';

  postFixup = ''
    patchelf \
      --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" \
      --add-rpath "${lib.makeLibraryPath runtimeLibraries}" \
      "$out/bin/sonora"
    wrapProgram "$out/bin/sonora" \
      --set ALSA_PLUGIN_DIR ${alsaPlugins} \
      --prefix GIO_EXTRA_MODULES : ${pkgs.glib-networking}/lib/gio/modules \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${gstPluginPath}
  '';

  meta = {
    description = "A native music streaming client, built with Rust and GPUI";
    homepage = "https://github.com/sonorahq/sonora";
    license = with lib.licenses; [
      gpl3Plus
      ofl
      isc
    ];
    mainProgram = "sonora";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
