{
  lib,
  mkPrebuilt,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "herdr-core";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 herdr-core "$out/bin/herdr-core"
    ln -s herdr-core "$out/bin/hc"

    install -Dm444 LICENSE "$out/share/licenses/herdr-core/LICENSE"
    install -Dm444 THIRD-PARTY-NOTICES "$out/share/licenses/herdr-core/THIRD-PARTY-NOTICES"

    runHook postInstall
  '';

  meta = {
    description = "Terminals for coding agents; headless runtime (`hc`)";
    homepage = "https://github.com/herdrdev/herdr-core";
    license = lib.licenses.asl20;
    mainProgram = "herdr-core";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
