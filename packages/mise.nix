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
    url = "https://github.com/jdx/mise/archive/refs/tags/v${release.version}.tar.gz";
  };
  usageBin = pkgs.lib.getExe pkgs.usage;
in
mkPrebuilt {
  pname = "mise";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = ".";

  buildInputs = with pkgs; [
    gcc-unwrapped.lib
  ];
  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    installShellFiles
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 mise/bin/mise "$out/bin/mise"

    runHook postInstall
  '';

  postFixup = ''
    mkdir -p completions

    tar --extract --file "${completionsArchive}" --directory completions --strip-components=2 \
      "mise-${release.version}/completions/_mise" \
      "mise-${release.version}/completions/mise.bash" \
      "mise-${release.version}/completions/mise.fish"

    substituteInPlace completions/{mise.bash,mise.fish} \
      --replace-fail "type -P usage" "type -P ${usageBin}"

    substituteInPlace completions/_mise \
      --replace-fail "type -p usage" "type -p ${usageBin}"

    substituteInPlace completions/{_mise,mise.bash,mise.fish} \
      --replace-fail "usage complete-word" "${usageBin} complete-word"

    installShellCompletion \
      --bash completions/mise.bash \
      --fish completions/mise.fish \
      --zsh completions/_mise
  '';
}
