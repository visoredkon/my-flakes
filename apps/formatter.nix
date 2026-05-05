{
  formatTargets,
  nixfmt,
  writeShellApplication,
}:

writeShellApplication {
  name = "fmt";
  runtimeInputs = [ nixfmt ];
  text = ''
    set -euo pipefail

    if [ "$#" -gt 0 ]; then
      exec nixfmt "$@"
    fi

    exec nixfmt ${formatTargets}
  '';
}
