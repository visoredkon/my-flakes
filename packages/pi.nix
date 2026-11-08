{
  lib,
  pkgs,
  release,
  wl-clipboard,
  ...
}:

let
  src = pkgs.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${release.version}";
    hash = release.sourceSha256;
  };

  modelCatalogPin = lib.importJSON (src + "/nix/model-catalog.json");

  modelCatalog = pkgs.fetchurl {
    name = "pi-model-catalog.json";
    url = "https://pi.dev/api/models/revisions/${modelCatalogPin.revision}?types=chat,image,classifier";
    sha256 = lib.removePrefix "sha256-" modelCatalogPin.revision;
  };

  wlClipboard = wl-clipboard.overrideAttrs (_: {
    postInstall = "";
  });
in
pkgs.stdenv.mkDerivation {
  pname = "pi";
  inherit (release) version;

  inherit src;

  npmDeps = pkgs.importNpmLock { npmRoot = src; };
  npmRebuildFlags = [ "--ignore-scripts" ];
  dontStrip = true;

  nativeBuildInputs = with pkgs; [
    bun
    importNpmLock.npmConfigHook
    jq
    makeWrapper
    nodejs
  ];

  buildInputs = with pkgs; [ stdenv.cc.cc.lib ];

  buildPhase = ''
    runHook preBuild

    node packages/ai/scripts/hydrate-model-catalog.ts ${modelCatalog}
    npm run build:offline

    pushd packages/coding-agent || exit
    bun build --compile --aot \
      --target=bun-linux-x64 \
      --minify --sourcemap=linked \
      --trim \
      --no-compile-autoload-bunfig --no-compile-autoload-dotenv \
      ./dist/bun/cli.js ./src/utils/image-resize-worker.ts ./src/extensions/codemode/worker.ts \
      --outfile dist/pi
    npm run copy-binary-assets
    popd || exit

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -Dm755 packages/coding-agent/dist/pi $out/bin/pi

    cp -R packages/coding-agent/dist/theme $out/bin/
    cp -R packages/coding-agent/dist/assets $out/bin/
    cp -R packages/coding-agent/dist/export-html $out/bin/
    cp -R packages/coding-agent/dist/README.md $out/bin/
    cp -R packages/coding-agent/dist/CHANGELOG.md $out/bin/
    cp -R packages/coding-agent/dist/docs $out/bin/
    cp -R packages/coding-agent/dist/examples $out/bin/
    install -Dm644 packages/coding-agent/dist/photon_rs_bg.wasm $out/bin/
    install -Dm644 packages/coding-agent/dist/package.json $out/bin/

    mv $out/bin/pi $out/bin/pi-real
    makeWrapper $out/bin/pi-real $out/bin/pi \
      --prefix PATH : ${
        with pkgs;
        lib.makeBinPath [
          bash
          fd
          git
          ripgrep
          which
          wlClipboard
        ]
      }

    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    export PI_OFFLINE=1
    export PI_SKIP_VERSION_CHECK=1
    test "$(jq -r .version $out/bin/package.json)" = "${release.version}"
    test -f $out/bin/README.md
    test -f $out/bin/CHANGELOG.md
    test -d $out/bin/docs
    test -d $out/bin/examples
    ${pkgs.fd}/bin/fd --version >/dev/null
    ${pkgs.ripgrep}/bin/rg --version >/dev/null
    test "$(PATH=$out/bin:${pkgs.bash}/bin:${pkgs.fd}/bin:${pkgs.git}/bin:${pkgs.ripgrep}/bin:${pkgs.which}/bin:${wlClipboard}/bin command -v bash)" = "${pkgs.bash}/bin/bash"
    test "$(PATH=$out/bin:${pkgs.git}/bin command -v git)" = "${pkgs.git}/bin/git"
    test "$(PATH=$out/bin:${pkgs.which}/bin command -v which)" = "${pkgs.which}/bin/which"
    help=$($out/bin/pi --help)
    printf '%s\n' "$help" | grep -Fq 'pi - AI coding assistant'
    ! printf '%s\n' "$help" | grep -Fq 'Bun is a fast JavaScript runtime'
    runHook postInstallCheck
  '';

  meta = {
    description = "Minimal extensible agent harness with interactive TUI, print/JSON mode, RPC, and TS SDK";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = [ "x86_64-linux" ];
  };
}
