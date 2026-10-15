{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

let
  binDeps = with pkgs; [
    bubblewrap
    desktop-file-utils
    ffmpeg
    ffmpegthumbnailer
    imagemagick
    libraw
    squashfsTools
    util-linux
    xdg-utils
  ];
in
mkPrebuilt {
  pname = "strata";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = "strata-${release.version}-x86_64-unknown-linux-gnu";

  buildInputs =
    with pkgs;
    [
      cairo
      fontconfig
      gcc-unwrapped.lib
      gdk-pixbuf
      glib
      graphene
      gsettings-desktop-schemas
      gst_all_1.gst-libav
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gstreamer
      gtk4
      gtksourceview5
      gvfs
      hicolor-icon-theme
      pango
      poppler
    ]
    ++ binDeps;

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    wrapGAppsHook4
  ];

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : "${pkgs.lib.makeBinPath binDeps}"
    )
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 strata "$out/bin/strata"
    install -Dm644 io.github.lgse.Strata.desktop "$out/share/applications/io.github.lgse.Strata.desktop"
    install -Dm644 io.github.lgse.Strata.svg "$out/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg"
    install -Dm644 io.github.lgse.Strata.FileManager1.service "$out/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service"

    substituteInPlace "$out/share/applications/io.github.lgse.Strata.desktop" \
      --replace-fail 'Exec=strata' "Exec=$out/bin/strata"
    substituteInPlace "$out/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service" \
      --replace-fail 'Exec=/usr/bin/strata' "Exec=$out/bin/strata"

    runHook postInstall
  '';
}
