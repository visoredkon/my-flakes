{
  coreutils,
  curl,
  gawk,
  git,
  jq,
  lib,
  nix,
  packageMetadata,
  writeShellApplication,
}:

let
  metaJson = builtins.toJSON (
    lib.mapAttrs (_: v: {
      baseUrl = v.baseUrl;
      urlTemplate = v.urlTemplate;
    }) packageMetadata
  );
in
writeShellApplication {
  name = "update-release";
  runtimeInputs = [
    coreutils
    curl
    gawk
    git
    jq
    nix
  ];
  text = ''
    set -euo pipefail

    COMMIT=false
    PUSH=false
    updates=()
    updated_packages=()

    display_version() {
      if [[ -n "$1" ]]; then
        echo "$1"
      else
        echo "unknown"
      fi
    }

    join_packages() {
      local joined=""
      local pkg=""
      for pkg in "$@"; do
        if [[ -z "$joined" ]]; then
          joined="$pkg"
        else
          joined="$joined, $pkg"
        fi
      done
      echo "$joined"
    }

    usage() {
      cat <<'EOF'
    Usage: update-release [OPTIONS]

    OPTIONS:
      --commit             Commit updated release.nix and flake.lock
      --push               Push after committing (implies --commit)
      -h, --help           Show this help message
    EOF
    }

    while [[ $# -gt 0 ]]; do
      case $1 in
      --commit)
        COMMIT=true
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --push)
        COMMIT=true
        PUSH=true
        shift
        ;;
      *)
        usage
        exit 1
        ;;
      esac
    done

    git pull

    meta='${metaJson}'
    package_names=$(jq -r 'keys[]' <<<"$meta")

    for pkg in $package_names; do
      baseUrl=$(jq -r --arg pkg "$pkg" '.[$pkg].baseUrl' <<<"$meta")
      urlTemplate=$(jq -r --arg pkg "$pkg" '.[$pkg].urlTemplate' <<<"$meta")
      releaseFile="releases/$pkg.nix"

      echo "==> Updating $pkg..." >&2

      if [[ "$baseUrl" == *"github.com"* ]]; then
        repoBase="''${baseUrl%/releases/download}"
        redirect=$(curl -sSL -o /dev/null -w '%{url_effective}' "$repoBase/releases/latest" 2>/dev/null || true)
        tag=$(basename "$redirect" 2>/dev/null || true)
        version="''${tag#v}"
      elif [[ "$baseUrl" == *"downloads.claude.ai"* ]]; then
        version=$(curl -fsSL "$baseUrl/latest" 2>/dev/null | tr -d '\r\n' || true)
      elif [[ "$baseUrl" == *"prod.download.cli.kiro.dev"* ]]; then
        manifest=$(curl -fsSL "$baseUrl/latest/manifest.json" 2>/dev/null || true)
        version=$(jq -r '.version' <<<"$manifest")
      else
        echo "Automatic version discovery not supported for $pkg" >&2
        continue
      fi

      if [[ -z "$version" ]]; then
        echo "Failed to determine version for $pkg" >&2
        continue
      fi

      current_version=$(awk -F'"' '/version =/ {print $2}' "$releaseFile" 2>/dev/null || true)

      if [[ "$current_version" == "$version" ]]; then
        echo "==> $pkg already at version $version" >&2
        continue
      fi

      echo "==> Updating $pkg from $current_version to $version..." >&2

      url="''${urlTemplate//\{version\}/$version}"
      tmp=$(mktemp)

      if ! curl -L -s -o "$tmp" "$url"; then
        echo "Error: Failed to download $pkg version $version" >&2
        rm -f "$tmp"
        continue
      fi

      sha=$(sha256sum "$tmp" | awk '{print $1}')
      rm -f "$tmp"

      cat > "$releaseFile" <<EO
    { sha256 = "$sha"; version = "$version"; }
    EO

      updates+=("$pkg:$(display_version "$current_version"):$version")
      updated_packages+=("$pkg")
      echo "==> Wrote $releaseFile" >&2
    done

    echo "==> Formatting files..." >&2
    nix --extra-experimental-features "nix-command flakes" fmt 2>/dev/null || true

    echo "==> Updating flake.lock..." >&2
    nix --extra-experimental-features "nix-command flakes" flake update 2>/dev/null || true

    if [[ "$COMMIT" == "true" ]]; then
      echo "==> Committing changes..." >&2
      git add releases/ flake.lock

      if git diff --cached --quiet; then
        echo "==> No staged changes to commit" >&2
      else
        update_count=''${#updates[@]}
        if [[ "$update_count" -eq 0 ]]; then
          commit_subject="build(release): refresh release metadata"
        elif [[ "$update_count" -eq 1 ]]; then
          IFS=':' read -r pkg from_version to_version <<<"''${updates[0]}"
          commit_subject="build(release): bump $pkg $from_version -> $to_version"
        elif [[ "$update_count" -le 3 ]]; then
          commit_subject="build(release): bump $(join_packages "''${updated_packages[@]}")"
        else
          commit_subject="build(release): bump $update_count packages"
        fi

        commit_message_file=$(mktemp)
        {
          echo "$commit_subject"
          echo
          if [[ "$update_count" -eq 0 ]]; then
            echo "Updated release artifacts and lockfile."
          else
            echo "Updated release artifacts:"
            for update in "''${updates[@]}"; do
              IFS=':' read -r pkg from_version to_version <<<"$update"
              echo "- $pkg: $from_version -> $to_version"
            done
          fi
        } > "$commit_message_file"

        git commit -F "$commit_message_file"
        rm -f "$commit_message_file"

        if [[ "$PUSH" == "true" ]]; then
          echo "==> Pushing changes..." >&2
          git push
        fi
      fi
    fi

    echo "==> Done" >&2
  '';
}
