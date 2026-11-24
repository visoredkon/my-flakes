{
  lib,
  release,
  urlTemplate,
  mkAppImage,
  ...
}:

mkAppImage {
  pname = "learnharness";
  inherit release urlTemplate;

  installCommands = appimageContents: ''
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
