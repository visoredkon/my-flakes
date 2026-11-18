{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "opencode";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = ".";

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 package/bin/opencode "$out/bin/opencode"

    wrapProgram "$out/bin/opencode" \
      --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [
        pkgs.wayland
        pkgs.libxcb
        pkgs.libxau
        pkgs.libxdmcp
      ]}

    runHook postInstall
  '';
}
