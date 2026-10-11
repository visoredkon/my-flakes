{
  lib,
  pkgs,
  release,
  urlTemplate,
  ...
}:

assert release ? sha256 && release.sha256 != "";
assert release ? version && release.version != "";

let
  pname = "openchamber-desktop";
  inherit (release) version;

  src = pkgs.fetchurl {
    inherit (release) sha256;
    url = builtins.replaceStrings [ "{version}" ] [ release.version ] urlTemplate;
  };

  appimageContents = pkgs.appimageTools.extract { inherit pname version src; };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/openchamber.desktop $out/share/applications/openchamber-desktop.desktop
    install -m 444 -D ${appimageContents}/openchamber.svg $out/share/icons/hicolor/scalable/apps/openchamber-desktop.svg

    substituteInPlace $out/share/applications/openchamber-desktop.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=openchamber-desktop' \
      --replace-fail 'Icon=openchamber' 'Icon=openchamber-desktop'
  '';

  meta = {
    description = "Desktop runtime for OpenChamber";
    homepage = "https://github.com/openchamber/openchamber";
    license = lib.licenses.mit;
    mainProgram = "openchamber-desktop";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
