{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "warp-terminal";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = ".";

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
    zstd
  ];

  buildInputs = with pkgs; [
    alsa-lib
    curl
    fontconfig
    stdenv.cc.cc
    zlib
    xz
  ];

  runtimeDependencies = with pkgs; [
    libglvnd
    libxkbcommon
    stdenv.cc.libc
    vulkan-loader
    xdg-utils
    wayland
    libx11
    libxcb
    libxcursor
    libxi
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r opt usr/* $out

    substituteInPlace $out/bin/warp-terminal \
      --replace-fail '#!/bin/bash' '#!${pkgs.bash}/bin/bash' \
      --replace-fail /opt/ $out/opt/

    runHook postInstall
  '';

  postFixup = ''
    patchelf \
      --add-needed libfontconfig.so.1 \
      $out/opt/warpdotdev/warp-terminal/warp
  '';

  meta = {
    description = "Warp is an agentic development environment, born out of the terminal";
    homepage = "https://www.warp.dev";
    license = pkgs.lib.licenses.unfree;
    mainProgram = "warp-terminal";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with pkgs.lib.sourceTypes; [ binaryNativeCode ];
  };
}
