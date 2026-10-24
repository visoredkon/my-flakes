{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

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

  completions = {
    archive = completionsArchive;
    stripComponents = 2;
    prefix = "mise-${release.version}/completions/";
    files = {
      bash = "mise.bash";
      fish = "mise.fish";
      zsh = "_mise";
    };
  };

  dontBuild = true;
  sourceRoot = ".";

  nativeBuildInputs = with pkgs; [
    installShellFiles
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 mise/bin/mise "$out/bin/mise"

    runHook postInstall
  '';

  postFixup = ''
    substituteInPlace completions/{mise.bash,mise.fish} \
      --replace-quiet "type -P usage" "type -P ${usageBin}"

    substituteInPlace completions/_mise \
      --replace-quiet "type -p usage" "type -p ${usageBin}"

    substituteInPlace completions/{_mise,mise.bash,mise.fish} \
      --replace-quiet "usage complete-word" "${usageBin} complete-word"
  '';
}
