{
  lib,
  pkgs,
  release,
  urlTemplate,
  ...
}:

let
  pname = "zcode";
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
    install -m 444 -D ${appimageContents}/zcode.desktop $out/share/applications/zcode.desktop

    install -m 444 -D ${appimageContents}/zcode.png \
      $out/share/icons/hicolor/1024x1024/apps/zcode.png

    substituteInPlace $out/share/applications/zcode.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=zcode'
  '';

  meta = {
    description = "ZCode desktop app";
    homepage = "https://zcode.z.ai";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "zcode";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
