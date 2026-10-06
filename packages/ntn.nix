{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "ntn";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = "ntn-x86_64-unknown-linux-musl";

  installPhase = ''
    runHook preInstall

    install -Dm755 ntn "$out/bin/ntn"

    runHook postInstall
  '';
}
