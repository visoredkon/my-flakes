{
  formatTargets,
  pkgs,
}:

pkgs.writeShellApplication {
  name = "fmt";
  runtimeInputs = with pkgs; [ nixfmt ];
  text = ''
    set -euo pipefail

    if [ "$#" -gt 0 ]; then
      exec nixfmt "$@"
    fi

    exec nixfmt ${formatTargets}
  '';
}
