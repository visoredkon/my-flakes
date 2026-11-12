{
  lib,
  pkgs,
  release,
  urlTemplate,
  ...
}:

let
  pname = "learnharness";
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
    install -m 444 -D ${appimageContents}/learnharness.desktop $out/share/applications/learnharness.desktop

    install -m 444 -D ${appimageContents}/learnharness.png \
      $out/share/icons/hicolor/512x512/apps/learnharness.png

    substituteInPlace $out/share/applications/learnharness.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=learnharness'
  '';

  meta = {
    description = "An agent harness for learning: adaptive teaching, practice, and a persistent knowledge graph.";
    homepage = "https://github.com/amosblomqvist/learnharness";
    license = lib.licenses.agpl3Only;
    mainProgram = "learnharness";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
