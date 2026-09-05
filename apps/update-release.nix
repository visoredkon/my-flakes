{
  lib,
  packageMetadata,
  goPackagesConfig ? { },
  pkgs,
  ...
}:

let
  metaJson = builtins.toJSON (
    lib.mapAttrs (_: v: { inherit (v) baseUrl urlTemplate; }) packageMetadata
  );
  goPackagesJson = builtins.toJSON goPackagesConfig;
in
pkgs.writeShellApplication {
  name = "update-release";
  runtimeInputs =
    with pkgs;
    [
      coreutils
      curl
      gawk
      git
      gnupg
      gnutar
      jq
      nix
    ]
    ++ lib.optionals (goPackagesConfig != { }) [ gh ];
  text = ''
    set -euo pipefail

    COMMIT=false
    PUSH=false
    failurePackages=()
    failureMessages=()
    updates=()
    updated_packages=()

    add_failure() {
      local pkg="$1"
      local message="$2"

      if [[ -n "''${job_failed+x}" ]]; then
        job_failed=true
        printf '%s\n' "$message" > "$status_file"
      else
        failurePackages+=("$pkg")
        failureMessages+=("$message")
      fi
      echo "Error: $pkg: $message" >&2
    }

    prepare_job() {
      local pkg="$1"
      job_id=$((job_id + 1))
      status_file="$job_dir/$job_id.status"
      result_file="$job_dir/$job_id.result"
      : > "$result_file"
      job_packages+=("$pkg")
      job_status_files+=("$status_file")
      job_result_files+=("$result_file")
    }

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

    download_source_sha256() {
      local url="$1"
      local tmp

      tmp=$(mktemp)

      if ! curl_retry -L -s -o "$tmp" "$url"; then
        rm -f "$tmp"
        echo ""
        return 1
      fi

      local sha
      sha=$(sha256sum "$tmp" | awk '{print $1}' || true)
      rm -f "$tmp"

      if [[ -z "$sha" ]]; then
        echo ""
        return 1
      fi

      echo "$sha"
    }

    release_field_value() {
      local release_file="$1"
      local field="$2"

      gawk -v field="$field" '
        match($0, field "[[:space:]]*=[[:space:]]*\"([^\"]*)\"", groups) {
          print groups[1]
          exit
        }
      ' "$release_file" 2>/dev/null || true
    }

    release_fields_for_package() {
      case "$1" in
      antigravity)
        echo "sha256 url version vscodeVersion"
        ;;
      antigravity-cli)
        echo "sha256 url version"
        ;;
      bootdev)
        echo "sourceSha256 vendorHash version"
        ;;
      kiro)
        echo "sha256 version vscodeVersion"
        ;;
      mise)
        echo "sha256 sourceSha256 version"
        ;;
      tinymist)
        echo "completionsSha256 sha256 version"
        ;;
      typescript-language-server)
        echo "sha256 version"
        ;;
      *)
        echo "sha256 version"
        ;;
      esac
    }

    release_value_for_field() {
      case "$1" in
      completionsSha256)
        echo "$completionsSha"
        ;;
      sha256)
        echo "$sha"
        ;;
      sourceSha256)
        echo "$sourceSha"
        ;;
      url)
        echo "$url"
        ;;
      vendorHash)
        echo "$vendorHash"
        ;;
      version)
        echo "$version"
        ;;
      vscodeVersion)
        echo "$vscodeVersion"
        ;;
      *)
        echo ""
        ;;
      esac
    }

    parse_update() {
      IFS=':' read -r pkg from_version to_version <<<"$1"
    }

    usage() {
      cat <<'EOF'
    Usage: update-release [OPTIONS] [DIR]

    OPTIONS:
      --commit             Commit updated release.nix and flake.lock
      --push               Push after committing (implies --commit)
      -h, --help           Show this help message
    EOF
    }

    validate_release_file() {
      local pkg="$1"
      local release_file="$2"
      local field=""
      local value=""

      for field in $(release_fields_for_package "$pkg"); do
        value=$(release_field_value "$release_file" "$field")
        if [[ -z "$value" ]]; then
          add_failure "$pkg" "missing $field in $release_file"
          return 1
        fi
      done

      return 0
    }

    validate_release_values() {
      local pkg="$1"
      local field=""
      local value=""

      for field in $(release_fields_for_package "$pkg"); do
        value=$(release_value_for_field "$field")
        if [[ -z "$value" ]]; then
          add_failure "$pkg" "missing $field for release output"
          return 1
        fi
      done

      return 0
    }

    write_release_file() {
      local pkg="$1"
      local release_file="$2"
      local field=""
      local line="{ "
      local value=""

      for field in $(release_fields_for_package "$pkg"); do
        value=$(release_value_for_field "$field")
        line="$line$field = \"$value\"; "
      done

      line="$line}"
      printf '%s\n' "$line" > "$release_file"
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
        if [[ "$1" != -* ]]; then
          root="$1"
          shift
        else
          usage
          exit 1
        fi
        ;;
      esac
    done

    root="''${root:-$(pwd)}"
    cd "$root" || exit 1

    git pull || echo "git pull failed, continuing anyway" >&2

    job_dir=$(mktemp -d)
    job_parent_pid="$BASHPID"
    job_pids=()
    job_packages=()
    job_status_files=()
    job_result_files=()
    job_id=0

    cleanup_jobs() {
      if [[ "$BASHPID" == "$job_parent_pid" ]]; then
        rm -rf "$job_dir"
      fi
    }

    trap cleanup_jobs EXIT

    max_jobs=$(nproc 2>/dev/null || echo 6)
    if [[ "$max_jobs" -gt 6 ]]; then
      max_jobs=6
    fi
    if [[ "$max_jobs" -lt 1 ]]; then
      max_jobs=1
    fi

    running_pids=()

    throttle_jobs() {
      while (( ''${#running_pids[@]} >= max_jobs )); do
        if ! wait -n 2>/dev/null; then
          wait "''${running_pids[0]}" 2>/dev/null || true
        fi
        local tmp_pids=()
        local pid
        for pid in "''${running_pids[@]}"; do
          if kill -0 "$pid" 2>/dev/null; then
            tmp_pids+=("$pid")
          fi
        done
        running_pids=("''${tmp_pids[@]}")
      done
    }

    curl_retry() {
      curl --retry 5 --retry-delay 2 --retry-all-errors --connect-timeout 10 "$@"
    }

    collect_job_failure() {
      local pkg="$1"
      local message="$2"

      failurePackages+=("$pkg")
      failureMessages+=("$message")
    }

    meta='${metaJson}'
    package_names=$(jq -r 'keys[]' <<<"$meta")

    for pkg in $package_names; do
      prepare_job "$pkg"

      (
        job_failed=false

        for job_pkg in $pkg; do
          pkg="$job_pkg"
          baseUrl=$(jq -r --arg pkg "$pkg" '.[$pkg].baseUrl' <<<"$meta")
          urlTemplate=$(jq -r --arg pkg "$pkg" '.[$pkg].urlTemplate' <<<"$meta")
          releaseFile="releases/$pkg.nix"
          completionsSha=""
          sha=""
          sourceSha=""
          url=""
          version=""
          vscodeVersion=""

          echo "check $pkg from $baseUrl" >&2

          if [[ "$baseUrl" == *"antigravity-auto-updater"* ]]; then
            metadata=$(curl_retry -fsSL "$baseUrl/api/update/linux-x64/stable/latest" 2>/dev/null || true)
            url=$(jq -r '.url // ""' <<<"$metadata")
            version=$(gawk 'match($0, /\/([^/]+)\/linux-x64\//, m) { print m[1] }' <<<"$url")
            vscodeVersion=$(jq -r '.productVersion // ""' <<<"$metadata")
          elif [[ "$baseUrl" == *"antigravity-cli-auto-updater"* ]]; then
            metadata=$(curl_retry -fsSL "$baseUrl/manifests/linux_amd64.json" 2>/dev/null || true)
            url=$(jq -r '.url // ""' <<<"$metadata")
            version=$(jq -r '.version // ""' <<<"$metadata")
          elif [[ "$baseUrl" == *"downloads.claude.ai"* ]]; then
            version=$(curl_retry -fsSL "$baseUrl/latest" 2>/dev/null | tr -d '\r\n' || true)
          elif [[ "$baseUrl" == *"github.com"* ]]; then
            repoBase="''${baseUrl%/releases/download}"
            redirect=$(curl_retry -sSL -o /dev/null -w '%{url_effective}' "$repoBase/releases/latest" 2>/dev/null || true)
            tag=$(basename "$redirect" 2>/dev/null || true)
            case "$pkg" in
              bun)
                version="''${tag#bun-v}"
                ;;
              *)
                version="''${tag#v}"
                ;;
            esac
          elif [[ "$baseUrl" == *"prod.download.cli.kiro.dev"* ]]; then
            manifest=$(curl_retry -fsSL "$baseUrl/latest/manifest.json" 2>/dev/null || true)
            version=$(jq -r '.version // ""' <<<"$manifest")
          elif [[ "$baseUrl" == *"prod.download.desktop.kiro.dev"* ]]; then
            metadata=$(curl_retry -fsSL "$baseUrl/stable/metadata-linux-x64-stable.json" 2>/dev/null || true)
            version=$(jq -r '.currentRelease // ""' <<<"$metadata")
          elif [[ "$baseUrl" == *"registry.npmjs.org"* ]]; then
            pkgName=$(basename "$baseUrl")
            metadata=$(curl_retry -fsSL "https://registry.npmjs.org/$pkgName/latest" 2>/dev/null || true)
            version=$(jq -r '.version // ""' <<<"$metadata")
          elif [[ "$baseUrl" == *"releases.warp.dev"* ]]; then
            redirect=$(curl_retry -sL --max-redirs 10 -o /dev/null -w '%{url_effective}' 'https://app.warp.dev/download?package=pacman' 2>/dev/null || true)
            version=$(echo "$redirect" | gawk 'match($0, /\/v([^\/]+)\//, m) { print m[1] }' || true)
          else
            add_failure "$pkg" "automatic version discovery not supported"
            continue
          fi

          if [[ -z "$version" ]]; then
            add_failure "$pkg" "failed to determine version"
            continue
          fi

          current_version=$(release_field_value "$releaseFile" "version")

          if [[ "$current_version" == "$version" ]]; then
            if ! validate_release_file "$pkg" "$releaseFile"; then
              continue
            fi

            echo "$pkg already on $version" >&2
            continue
          fi

          echo "$pkg: $current_version -> $version" >&2

          if [[ -z "$url" ]]; then
            url="''${urlTemplate//\{version\}/$version}"
          fi

          if [[ -z "$url" ]]; then
            add_failure "$pkg" "failed to determine download URL"
            continue
          fi

          tmp=$(mktemp)

          if ! curl_retry -L -s -o "$tmp" "$url"; then
            add_failure "$pkg" "failed to download binary version $version"
            rm -f "$tmp"
            continue
          fi

          sha=$(sha256sum "$tmp" | awk '{print $1}' || true)
          if [[ -z "$sha" ]]; then
            add_failure "$pkg" "failed to compute sha256 for $url"
            rm -f "$tmp"
            continue
          fi

          if [[ "$pkg" == "kiro" ]]; then
            vscodeVersion=$(tar -Oxzf "$tmp" "Kiro/resources/app/product.json" 2>/dev/null | jq -r '.vsCodeVersion // ""' 2>/dev/null || true)
          fi

          if [[ "$pkg" == "mise" ]]; then
            sourceSha=$(download_source_sha256 "https://github.com/jdx/mise/archive/refs/tags/v$version.tar.gz") || true
            if [[ -z "$sourceSha" ]]; then
              add_failure "$pkg" "failed to determine sourceSha256"
              rm -f "$tmp"
              continue
            fi
          fi

          if [[ "$pkg" == "tinymist" ]]; then
            completionsUrl="https://github.com/Myriad-Dreamin/tinymist/releases/download/v$version/tinymist-completions.tar.gz"
            completionsSha=$(download_source_sha256 "$completionsUrl") || true
            completionsSha=$(nix hash to-sri --type sha256 "$completionsSha" 2>/dev/null || true)
            if [[ -z "$completionsSha" ]]; then
              add_failure "$pkg" "failed to determine completionsSha256"
              rm -f "$tmp"
              continue
            fi
          fi

          if [[ "$pkg" == "antigravity" || "$pkg" == "kiro" ]] && [[ -z "$vscodeVersion" ]]; then
            add_failure "$pkg" "failed to determine vscodeVersion"
            rm -f "$tmp"
            continue
          fi

          rm -f "$tmp"

          if ! validate_release_values "$pkg"; then
            continue
          fi

          if ! write_release_file "$pkg" "$releaseFile"; then
            add_failure "$pkg" "failed to write $releaseFile"
            continue
          fi

          printf '%s\n%s\n' "$current_version" "$version" > "$result_file"
          echo "wrote $releaseFile" >&2
        done

        if [[ "$job_failed" == "true" ]]; then
          exit 1
        fi
        printf '%s\n' success > "$status_file"
      ) &
      job_pids+=("$!")
      running_pids+=("$!")
      throttle_jobs
    done

    goPackages='${goPackagesJson}'
    for pkg in $(jq -r 'keys[]' <<<"$goPackages"); do
      prepare_job "$pkg"

      (
        job_failed=false

        for job_pkg in $pkg; do
          pkg="$job_pkg"
          releaseFile="releases/$pkg.nix"
          sourceSha=""
          vendorHash=""
          version=""
          repoOwner=$(jq -r --arg pkg "$pkg" '.[$pkg].repoOwner' <<<"$goPackages")
          repoName=$(jq -r --arg pkg "$pkg" '.[$pkg].repoName' <<<"$goPackages")

          echo "check go package $pkg ($repoOwner/$repoName)" >&2

          tag=$(gh api "repos/$repoOwner/$repoName/tags" --jq '.[0].name' || true)
          version="''${tag#v}"

          if [[ -z "$version" ]]; then
            add_failure "$pkg" "failed to determine version via gh api"
            continue
          fi

          current_version=$(release_field_value "$releaseFile" "version")

          if [[ "$current_version" == "$version" ]]; then
            if ! validate_release_file "$pkg" "$releaseFile"; then
              continue
            fi

            echo "$pkg already on $version" >&2
            continue
          fi

          echo "$pkg: $current_version -> $version" >&2

          sourceUrl="https://github.com/$repoOwner/$repoName/archive/refs/tags/v$version.tar.gz"
          sourceSha=$(nix-prefetch-url --unpack "$sourceUrl" 2>/dev/null || true)
          if [[ -z "$sourceSha" ]]; then
            add_failure "$pkg" "failed to compute sourceSha256"
            continue
          fi
          sourceSha=$(nix hash to-sri --type sha256 "$sourceSha" 2>/dev/null || true)

          vendorHashPlaceholder="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
          vendorHash=$(release_field_value "$releaseFile" "vendorHash")
          if [[ -z "$vendorHash" || "$vendorHash" == "$vendorHashPlaceholder" ]]; then
            vendorHash="$vendorHashPlaceholder"
          fi

          if ! validate_release_values "$pkg"; then
            continue
          fi

          if ! write_release_file "$pkg" "$releaseFile"; then
            add_failure "$pkg" "failed to write $releaseFile"
            continue
          fi

          echo "get vendorHash for $pkg, need build" >&2
          if buildOutput=$(nix build --no-link ".#$pkg" 2>&1); then
            echo "vendorHash unchanged" >&2
          else
            correctHash=""
            if echo "$buildOutput" | grep -q "hash mismatch in fixed-output derivation.*go-modules"; then
              correctHash=$(echo "$buildOutput" | grep "got:" | awk '{print $NF}' | tail -1 || true)
            fi

            if [[ -n "$correctHash" ]]; then
              vendorHash="$correctHash"
              echo "found vendorHash: $vendorHash" >&2
              if ! write_release_file "$pkg" "$releaseFile"; then
                add_failure "$pkg" "failed to write $releaseFile"
                continue
              fi
            else
              echo "could not figure out vendorHash, set it by hand or run nix build .#$pkg" >&2
            fi
          fi

          printf '%s\n%s\n' "$current_version" "$version" > "$result_file"
          echo "wrote $releaseFile" >&2
        done

        if [[ "$job_failed" == "true" ]]; then
          exit 1
        fi
        printf '%s\n' success > "$status_file"
      ) &
      job_pids+=("$!")
      running_pids+=("$!")
      throttle_jobs
    done

    for pid in "''${running_pids[@]}"; do
      wait "$pid" 2>/dev/null || true
    done

    for job_index in "''${!job_pids[@]}"; do
      pkg="''${job_packages[$job_index]}"
      status_file="''${job_status_files[$job_index]}"
      result_file="''${job_result_files[$job_index]}"
      message=""

      wait "''${job_pids[$job_index]}" 2>/dev/null || true

      message=$(cat "$status_file" 2>/dev/null || true)
      if [[ "$message" != "success" ]]; then
        if [[ -z "$message" ]]; then
          message="failed to update package"
          echo "Error: $pkg: $message" >&2
        fi
        collect_job_failure "$pkg" "$message"
        continue
      fi

      if [[ -s "$result_file" ]]; then
        mapfile -t job_result < "$result_file"
        if [[ "''${#job_result[@]}" -ne 2 ]]; then
          message="failed to parse package update result"
          echo "Error: $pkg: $message" >&2
          collect_job_failure "$pkg" "$message"
          continue
        fi
        updates+=("$pkg:$(display_version "''${job_result[0]}"):''${job_result[1]}")
        updated_packages+=("$pkg")
      fi
    done

    if [[ "''${#failurePackages[@]}" -gt 0 ]]; then
      echo "failed:" >&2
      for failureIndex in "''${!failurePackages[@]}"; do
        echo "- ''${failurePackages[$failureIndex]}: ''${failureMessages[$failureIndex]}" >&2
      done
      exit 1
    fi

    echo "update flake.lock to latest inputs" >&2
    nix --extra-experimental-features "nix-command flakes" flake update || true

    echo "format" >&2
    nix --extra-experimental-features "nix-command flakes" fmt || true

    if [[ "''${#updates[@]}" -eq 0 ]]; then
      echo "nothing new" >&2
    fi

    if [[ "$COMMIT" == "true" ]]; then
      echo "stage releases and flake.lock for commit" >&2
      git add releases/ flake.lock

      if git diff --cached --quiet; then
        echo "nothing to commit" >&2
      else
        update_count=''${#updates[@]}
        if [[ "$update_count" -eq 0 ]]; then
          commit_subject="chore(version): refresh release metadata"
        elif [[ "$update_count" -eq 1 ]]; then
          parse_update "''${updates[0]}"
          commit_subject="chore(version): bump $pkg $from_version -> $to_version"
        elif [[ "$update_count" -le 3 ]]; then
          commit_subject="chore(version): bump $(join_packages "''${updated_packages[@]}")"
        else
          commit_subject="chore(version): bump $update_count packages"
        fi

        commit_message_file=$(mktemp)
        {
          echo "$commit_subject"
          echo
          if [[ "$update_count" -eq 0 ]]; then
            echo "sync lockfile and release metadata"
          else
            echo "bumped:"
            for update in "''${updates[@]}"; do
              parse_update "$update"
              echo "- $pkg: $from_version -> $to_version"
            done
          fi
        } > "$commit_message_file"

        git commit -F "$commit_message_file"
        rm -f "$commit_message_file"

        if [[ "$PUSH" == "true" ]]; then
          echo "push to origin" >&2
          git push
        fi
      fi
    fi

    echo "done" >&2
  '';
}
