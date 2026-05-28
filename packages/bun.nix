{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

assert release ? sourceSha256 && release.sourceSha256 != "";

let
  completionsArchive = pkgs.fetchurl {
    sha256 = release.sourceSha256;
    url = "https://github.com/oven-sh/bun/archive/refs/tags/bun-v${release.version}.tar.gz";
  };
in
mkPrebuilt {
  pname = "bun";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = ".";

  buildInputs = with pkgs; [
    gcc-unwrapped.lib
  ];
  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    installShellFiles
    unzip
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 bun-linux-x64/bun "$out/bin/bun"

    runHook postInstall
  '';

  postFixup = ''
    mkdir -p completions

    tar --extract --file "${completionsArchive}" --directory completions --strip-components=2 \
      "bun-bun-v${release.version}/completions/bun.bash" \
      "bun-bun-v${release.version}/completions/bun.zsh" \
      "bun-bun-v${release.version}/completions/bun.fish"

    installShellCompletion \
      --bash completions/bun.bash \
      --fish completions/bun.fish \
      --zsh completions/bun.zsh
  '';
}
