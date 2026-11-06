{
  lib,
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "herdr-app";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = "herdr-app";

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  buildInputs = with pkgs; [
    stdenv.cc.cc.lib
    libxcb
    libxkbcommon
    wayland
    vulkan-loader
  ];

  runtimeDependencies = with pkgs; [
    wayland
    vulkan-loader
  ];

  installPhase = ''
        runHook preInstall

        install -Dm755 herdr-app "$out/bin/herdr-app"
        install -Dm444 herdr-app.svg "$out/share/icons/hicolor/scalable/apps/herdr-app.svg"
        install -Dm444 LICENSE "$out/share/licenses/herdr-app/LICENSE"
        install -Dm444 THIRD-PARTY-NOTICES "$out/share/licenses/herdr-app/THIRD-PARTY-NOTICES"

        mkdir -p "$out/share/applications"
        cat > "$out/share/applications/herdr-app.desktop" <<'EOF'
    [Desktop Entry]
    Type=Application
    Name=Herdr
    Comment=Terminals and coding agents that keep running
    Exec=herdr-app
    Icon=herdr-app
    Terminal=false
    Categories=Development;
    StartupWMClass=herdr-app
    EOF

        runHook postInstall
  '';

  meta = {
    description = "Desktop app for terminals and coding agents (Herdr 2)";
    homepage = "https://github.com/herdrdev/herdr-app";
    license = lib.licenses.asl20;
    mainProgram = "herdr-app";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
