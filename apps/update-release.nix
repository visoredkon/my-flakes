{
  lib,
  packageMetadata,
  goPackagesConfig ? { },
  branchSourcesConfig ? { },
  pkgs,
  ...
}:

let
  metaJson = builtins.toJSON (
    lib.mapAttrs (_: v: { inherit (v) baseUrl urlTemplate; }) packageMetadata
  );
  goPackagesJson = builtins.toJSON goPackagesConfig;
  branchSourcesJson = builtins.toJSON branchSourcesConfig;
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
    ++ lib.optionals (goPackagesConfig != { } || branchSourcesConfig != { }) [ gh ];
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

    short_rev() {
      echo "''${1:0:7}"
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
      bootdev | elephant | typescript)
        echo "sourceSha256 vendorHash version"
        ;;
      pvetui)
        echo "rev sourceSha256 vendorHash version"
        ;;
      kiro)
        echo "sha256 version vscodeVersion"
        ;;
      libfprint | waybar)
        echo "rev sourceSha256"
        ;;
      mise)
        echo "sha256 sourceSha256 version"
        ;;
      tinymist)
        echo "completionsSha256 sha256 version"
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
      rev)
        echo "$rev"
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
      if [[ "''${pkg:-}" == "libfprint" || "''${pkg:-}" == "waybar" ]]; then
        from_version=$(short_rev "$from_version")
        to_version=$(short_rev "$to_version")
      fi
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

    record_update() {
      local from="$1"
      local to="$2"

      printf '%s\n%s\n' "$from" "$to" > "$result_file"
      echo "wrote $releaseFile" >&2
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

    spawn_job() {
      local update_func="$1"
      local target="$2"

      prepare_job "$target"

      (
        local pkg="$target"
        job_failed=false
        "$update_func" "$pkg"

        if [[ "$job_failed" == "true" ]]; then
          exit 1
        fi
        printf '%s\n' success > "$status_file"
      ) &
      job_pids+=("$!")
      running_pids+=("$!")
      throttle_jobs
    }

    update_package() {
      local pkg="$1"
      baseUrl=$(jq -r --arg pkg "$pkg" '.[$pkg].baseUrl' <<<"$meta")
      urlTemplate=$(jq -r --arg pkg "$pkg" '.[$pkg].urlTemplate' <<<"$meta")
      releaseFile="releases/$pkg.nix"
      url=""
      version=""

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
      elif [[ "$baseUrl" == *"releases.warp.dev"* ]]; then
        redirect=$(curl_retry -sL --max-redirs 10 -o /dev/null -w '%{url_effective}' 'https://app.warp.dev/download?package=pacman' 2>/dev/null || true)
        version=$(echo "$redirect" | gawk 'match($0, /\/v([^\/]+)\//, m) { print m[1] }' || true)
      else
        add_failure "$pkg" "automatic version discovery not supported"
        return 1
      fi

      if [[ -z "$version" ]]; then
        add_failure "$pkg" "failed to determine version"
        return 1
      fi

      current_version=$(release_field_value "$releaseFile" "version")

      if [[ "$current_version" == "$version" ]]; then
        if ! validate_release_file "$pkg" "$releaseFile"; then
          return 1
        fi

        echo "$pkg already on $version" >&2
        return 0
      fi

      echo "$pkg: $current_version -> $version" >&2

      if [[ -z "$url" ]]; then
        url="''${urlTemplate//\{version\}/$version}"
      fi

      if [[ -z "$url" ]]; then
        add_failure "$pkg" "failed to determine download URL"
        return 1
      fi

      tmp=$(mktemp)

      if ! curl_retry -L -s -o "$tmp" "$url"; then
        add_failure "$pkg" "failed to download binary version $version"
        rm -f "$tmp"
        return 1
      fi

      sha=""
      sha=$(sha256sum "$tmp" | awk '{print $1}' || true)
      if [[ -z "$sha" ]]; then
        add_failure "$pkg" "failed to compute sha256 for $url"
        rm -f "$tmp"
        return 1
      fi

      vscodeVersion=""
      if [[ "$pkg" == "kiro" ]]; then
        vscodeVersion=$(tar -Oxzf "$tmp" "Kiro/resources/app/product.json" 2>/dev/null | jq -r '.vsCodeVersion // ""' 2>/dev/null || true)
      fi

      if [[ "$pkg" == "mise" ]]; then
        sourceSha=$(download_source_sha256 "https://github.com/jdx/mise/archive/refs/tags/v$version.tar.gz") || true
        if [[ -z "$sourceSha" ]]; then
          add_failure "$pkg" "failed to determine sourceSha256"
          rm -f "$tmp"
          return 1
        fi
      fi

      completionsSha=""
      if [[ "$pkg" == "tinymist" ]]; then
        completionsUrl="https://github.com/Myriad-Dreamin/tinymist/releases/download/v$version/tinymist-completions.tar.gz"
        completionsSha=$(download_source_sha256 "$completionsUrl") || true
        completionsSha=$(nix hash to-sri --type sha256 "$completionsSha" 2>/dev/null || true)
        if [[ -z "$completionsSha" ]]; then
          add_failure "$pkg" "failed to determine completionsSha256"
          rm -f "$tmp"
          return 1
        fi
      fi

      if [[ "$pkg" == "antigravity" || "$pkg" == "kiro" ]] && [[ -z "$vscodeVersion" ]]; then
        add_failure "$pkg" "failed to determine vscodeVersion"
        rm -f "$tmp"
        return 1
      fi

      rm -f "$tmp"

      if ! validate_release_values "$pkg"; then
        return 1
      fi

      if ! write_release_file "$pkg" "$releaseFile"; then
        add_failure "$pkg" "failed to write $releaseFile"
        return 1
      fi

      record_update "$current_version" "$version"
    }

    update_go_package() {
      local pkg="$1"
      releaseFile="releases/$pkg.nix"
      version=""
      repoOwner=$(jq -r --arg pkg "$pkg" '.[$pkg].repoOwner' <<<"$goPackages")
      repoName=$(jq -r --arg pkg "$pkg" '.[$pkg].repoName' <<<"$goPackages")

      echo "check go package $pkg ($repoOwner/$repoName)" >&2

      current_tag=$(gh api "repos/$repoOwner/$repoName/tags" --jq '.[0]' || true)
      tag=$(jq -r '.name // ""' <<<"$current_tag")
      version="''${tag#v}"

      if [[ -z "$version" ]]; then
        add_failure "$pkg" "failed to determine version via gh api"
        return 1
      fi

      current_version=$(release_field_value "$releaseFile" "version")

      if [[ "$current_version" == "$version" ]]; then
        if ! validate_release_file "$pkg" "$releaseFile"; then
          return 1
        fi

        echo "$pkg already on $version" >&2
        return 0
      fi

      echo "$pkg: $current_version -> $version" >&2

      if [[ "$pkg" == "pvetui" ]]; then
        rev=$(jq -r '.commit.sha // ""' <<<"$current_tag")
        if [[ -z "$rev" ]]; then
          add_failure "$pkg" "failed to determine rev via gh api"
          return 1
        fi
      fi

      sourceUrl="https://github.com/$repoOwner/$repoName/archive/refs/tags/v$version.tar.gz"
      sourceSha=""
      sourceSha=$(nix-prefetch-url --unpack "$sourceUrl" 2>/dev/null || true)
      if [[ -z "$sourceSha" ]]; then
        add_failure "$pkg" "failed to compute sourceSha256"
        return 1
      fi
      sourceSha=$(nix hash to-sri --type sha256 "$sourceSha" 2>/dev/null || true)

      vendorHash=""
      vendorHashPlaceholder="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      vendorHash=$(release_field_value "$releaseFile" "vendorHash")
      if [[ -z "$vendorHash" || "$vendorHash" == "$vendorHashPlaceholder" ]]; then
        vendorHash="$vendorHashPlaceholder"
      fi

      if ! validate_release_values "$pkg"; then
        return 1
      fi

      if ! write_release_file "$pkg" "$releaseFile"; then
        add_failure "$pkg" "failed to write $releaseFile"
        return 1
      fi

      if ! refresh_vendor_hash "$pkg" "$releaseFile"; then
        return 1
      fi

      record_update "$current_version" "$version"
    }

    refresh_vendor_hash() {
      local pkg="$1"
      local release_file="$2"
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
          if ! write_release_file "$pkg" "$release_file"; then
            add_failure "$pkg" "failed to write $release_file"
            return 1
          fi
        else
          echo "could not figure out vendorHash, set it by hand or run nix build .#$pkg" >&2
        fi
      fi
    }

    update_branch_package() {
      local pkg="$1"
      releaseFile="releases/$pkg.nix"
      repoOwner=$(jq -r --arg pkg "$pkg" '.[$pkg].owner' <<<"$branchSources")
      repoName=$(jq -r --arg pkg "$pkg" '.[$pkg].repo' <<<"$branchSources")
      branch=$(jq -r --arg pkg "$pkg" '.[$pkg].branch' <<<"$branchSources")

      echo "check branch package $pkg ($repoOwner/$repoName@$branch)" >&2

      rev=$(gh api "repos/$repoOwner/$repoName/commits/$branch" --jq '.sha' || true)

      if [[ -z "$rev" ]]; then
        add_failure "$pkg" "failed to determine rev via gh api"
        return 1
      fi

      current_rev=$(release_field_value "$releaseFile" "rev")

      if [[ "$current_rev" == "$rev" ]]; then
        if ! validate_release_file "$pkg" "$releaseFile"; then
          return 1
        fi

        echo "$pkg already on $rev" >&2
        return 0
      fi

      echo "$pkg: $(display_version "$current_rev") -> $(short_rev "$rev")" >&2

      sourceUrl="https://github.com/$repoOwner/$repoName/archive/$rev.tar.gz"
      sourceSha=""
      sourceSha=$(nix-prefetch-url --unpack "$sourceUrl" 2>/dev/null || true)
      if [[ -z "$sourceSha" ]]; then
        add_failure "$pkg" "failed to compute sourceSha256"
        return 1
      fi
      sourceSha=$(nix hash to-sri --type sha256 "$sourceSha" 2>/dev/null || true)

      if ! validate_release_values "$pkg"; then
        return 1
      fi

      if ! write_release_file "$pkg" "$releaseFile"; then
        add_failure "$pkg" "failed to write $releaseFile"
        return 1
      fi

      record_update "$current_rev" "$rev"
    }

    meta='${metaJson}'
    package_names=$(jq -r 'keys[]' <<<"$meta")

    for pkg in $package_names; do
      spawn_job update_package "$pkg"
    done

    goPackages='${goPackagesJson}'
    for pkg in $(jq -r 'keys[]' <<<"$goPackages"); do
      spawn_job update_go_package "$pkg"
    done

    branchSources='${branchSourcesJson}'
    for pkg in $(jq -r 'keys[]' <<<"$branchSources"); do
      spawn_job update_branch_package "$pkg"
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
    if ! nix --extra-experimental-features "nix-command flakes" flake update; then
      echo "Warning: flake update failed, continuing with existing flake.lock" >&2
    fi

    echo "format" >&2
    if ! nix --extra-experimental-features "nix-command flakes" fmt; then
      echo "Warning: fmt failed, continuing with unformatted files" >&2
    fi

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
