{
  lib,
  release,
  urlTemplate,
  mkAppImage,
  ...
}:

mkAppImage {
  pname = "zcode";
  inherit release urlTemplate;

  installCommands = appimageContents: ''
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
