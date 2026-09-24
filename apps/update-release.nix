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
    lib.mapAttrs (
      _: v:
      {
        inherit (v) baseUrl urlTemplate;
      }
      // lib.optionalAttrs (v ? releaseFields) { inherit (v) releaseFields; }
      // lib.optionalAttrs (v ? needsVscodeVersion) { inherit (v) needsVscodeVersion; }
      // lib.optionalAttrs (v ? vscodeProductPath) { inherit (v) vscodeProductPath; }
    ) packageMetadata
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
    uptodate_packages=()

    start_seconds=$SECONDS

    use_color=false
    if [[ -t 2 && -z "''${NO_COLOR:-}" ]]; then
      use_color=true
    fi

    if [[ "$use_color" == "true" ]]; then
      c_reset=$'\e[0m'
      c_bold=$'\e[1m'
      c_green=$'\e[32m'
      c_yellow=$'\e[33m'
      c_red=$'\e[31m'
      c_cyan=$'\e[36m'
      c_dim=$'\e[2m'
    else
      c_reset=""
      c_bold=""
      c_green=""
      c_yellow=""
      c_red=""
      c_cyan=""
      c_dim=""
    fi

    status_line() {
      local kind="$1"
      shift
      local code="$c_reset"

      case "$kind" in
      ok)
        code="$c_green"
        ;;
      update)
        code="$c_yellow"
        ;;
      fail)
        code="$c_red"
        ;;
      phase)
        code="$c_cyan"
        ;;
      detail)
        code="$c_dim"
        ;;
      header)
        code="$c_bold"
        ;;
      esac

      if [[ "$use_color" == "true" ]]; then
        printf '%b%s%b\n' "$code" "$*" "$c_reset" >&2
      else
        printf '%s\n' "$*" >&2
      fi
    }

    short_url() {
      local trimmed="''${1#https://}"
      trimmed="''${trimmed#http://}"

      if (( ''${#trimmed} > 90 )); then
        echo "''${trimmed:0:50}...''${trimmed: -37}"
      else
        echo "$trimmed"
      fi
    }

    human_bytes() {
      numfmt --to=iec "$1" 2>/dev/null || echo "$1"
    }

    note_fetch() {
      local url="$1"
      local size="''${2:-}"

      if [[ -n "$size" ]]; then
        echo "fetch $(short_url "$url") ($size) ... done" >&2
      else
        echo "fetch $(short_url "$url") ... done" >&2
      fi
    }

    fetch_binary() {
      local url="$1"
      local dest="$2"

      if ! curl_retry -L -sS -o "$dest" "$url"; then
        return 1
      fi

      local bytes
      bytes=$(stat -c%s "$dest" 2>/dev/null || echo "")

      if [[ -n "$bytes" ]]; then
        note_fetch "$url" "$(human_bytes "$bytes")"
      else
        note_fetch "$url"
      fi
    }

    prefetch_source() {
      local url="$1"
      local hash

      hash=$(nix-prefetch-url --unpack "$url" || true)

      if [[ -z "$hash" ]]; then
        return 1
      fi

      note_fetch "$url"
      echo "$hash"
    }

    record_uptodate() {
      printf 'uptodate\n%s\n' "$1" > "$result_file"
    }

    run_phase() {
      local label="$1"
      shift
      local phase_start=$SECONDS
      local output
      local code=0

      output=$("$@" 2>&1) || code=$?

      if [[ -n "$output" ]]; then
        printf '%s\n' "$output" | grep -v "Git tree.*is dirty" >&2 || true
      fi

      local phase_elapsed=$((SECONDS - phase_start))

      if (( code == 0 )); then
        status_line phase "[phase] $label ... ok (''${phase_elapsed}s)"
        return 0
      else
        status_line fail "[phase] $label ... failed (''${phase_elapsed}s)"
        return "$code"
      fi
    }

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
      job_log="$job_dir/$job_id.log"
      : > "$result_file"
      : > "$job_log"
      job_packages+=("$pkg")
      job_status_files+=("$status_file")
      job_result_files+=("$result_file")
      job_log_files+=("$job_log")
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

    display_revision() {
      case "$1" in
      elephant | libfprint | waybar)
        short_rev "$2"
        ;;
      *)
        display_version "$2"
        ;;
      esac
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

      if ! curl_retry -L -sS -o "$tmp" "$url"; then
        rm -f "$tmp"
        echo ""
        return 1
      fi

      local sha
      sha=$(sha256sum "$tmp" | awk '{print $1}' || true)

      local bytes
      bytes=$(stat -c%s "$tmp" 2>/dev/null || echo "")

      rm -f "$tmp"

      if [[ -z "$sha" ]]; then
        echo ""
        return 1
      fi

      if [[ -n "$bytes" ]]; then
        note_fetch "$url" "$(human_bytes "$bytes")"
      else
        note_fetch "$url"
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
      ' "$release_file" || true
    }

    release_fields_for_package() {
      case "$1" in
      bootdev | typescript)
        echo "sourceSha256 vendorHash version"
        ;;
      pvetui)
        echo "rev sourceSha256 vendorHash version"
        ;;
      elephant)
        echo "rev sourceSha256 vendorHash"
        ;;
      libfprint | waybar)
        echo "rev sourceSha256"
        ;;
      *)
        jq -r --arg pkg "$1" '.[$pkg].releaseFields // ["sha256", "version"] | join(" ")' <<<"$meta"
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
      from_version=$(display_revision "$pkg" "$from_version")
      to_version=$(display_revision "$pkg" "$to_version")
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

      printf 'updated\n%s\n%s\n' "$from" "$to" > "$result_file"
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

    git pull || {
      echo "Error: git pull failed, aborting" >&2
      exit 1
    }

    job_dir=$(mktemp -d)
    job_parent_pid="$BASHPID"
    job_pids=()
    job_packages=()
    job_status_files=()
    job_result_files=()
    job_log_files=()
    job_id=0

    cleanup_jobs() {
      if [[ "$BASHPID" == "$job_parent_pid" ]]; then
        rm -rf "$job_dir"
      fi
    }

    trap cleanup_jobs EXIT

    max_jobs=$(nproc || echo 6)
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
      status_line detail "=> check $target ..."

      (
        exec > "$job_log" 2>&1
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
      needsVscodeVersion=$(jq -r --arg pkg "$pkg" '.[$pkg].needsVscodeVersion // false' <<<"$meta")
      vscodeProductPath=$(jq -r --arg pkg "$pkg" '.[$pkg].vscodeProductPath // empty' <<<"$meta")
      releaseFile="releases/$pkg.nix"
      url=""
      version=""

      echo "check $pkg from $baseUrl" >&2

      if [[ "$baseUrl" == *"antigravity-auto-updater"* ]]; then
        metadata=$(curl_retry -fsSL "$baseUrl/api/update/linux-x64/stable/latest" || true)
        url=$(jq -r '.url // ""' <<<"$metadata")
        version=$(gawk 'match($0, /\/([^/]+)\/linux-x64\//, m) { print m[1] }' <<<"$url")
        vscodeVersion=$(jq -r '.productVersion // ""' <<<"$metadata")
      elif [[ "$baseUrl" == *"antigravity-cli-auto-updater"* ]]; then
        metadata=$(curl_retry -fsSL "$baseUrl/manifests/linux_amd64.json" || true)
        url=$(jq -r '.url // ""' <<<"$metadata")
        version=$(jq -r '.version // ""' <<<"$metadata")
      elif [[ "$baseUrl" == *"downloads.claude.ai"* ]]; then
        version=$(curl_retry -fsSL "$baseUrl/latest" | tr -d '\r\n' || true)
      elif [[ "$baseUrl" == *"github.com"* ]]; then
        repoBase="''${baseUrl%/releases/download}"
        redirect=$(curl_retry -sSL -o /dev/null -w '%{url_effective}' "$repoBase/releases/latest" || true)
        tag=$(basename "$redirect" || true)
        case "$pkg" in
          bun)
            version="''${tag#bun-v}"
            ;;
          *)
            version="''${tag#v}"
            ;;
        esac
      elif [[ "$baseUrl" == *"prod.download.cli.kiro.dev"* ]]; then
        manifest=$(curl_retry -fsSL "$baseUrl/latest/manifest.json" || true)
        version=$(jq -r '.version // ""' <<<"$manifest")
      elif [[ "$baseUrl" == *"prod.download.desktop.kiro.dev"* ]]; then
        metadata=$(curl_retry -fsSL "$baseUrl/stable/metadata-linux-x64-stable.json" || true)
        version=$(jq -r '.currentRelease // ""' <<<"$metadata")
      elif [[ "$baseUrl" == *"releases.warp.dev"* ]]; then
        redirect=$(curl_retry -sL --max-redirs 10 -o /dev/null -w '%{url_effective}' 'https://app.warp.dev/download?package=pacman' || true)
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
        record_uptodate "$version"
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

      if ! fetch_binary "$url" "$tmp"; then
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
      if [[ "$needsVscodeVersion" == "true" && -n "$vscodeProductPath" ]]; then
        vscodeVersion=$(tar -Oxzf "$tmp" "$vscodeProductPath" | jq -r '.vsCodeVersion // ""' || true)
      fi

      if [[ "$pkg" == "mise" ]]; then
        sourceSha=$(download_source_sha256 "https://github.com/jdx/mise/archive/refs/tags/v$version.tar.gz") || true
        sourceSha=$(nix hash convert --hash-algo sha256 --to sri "$sourceSha" || true)
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
        completionsSha=$(nix hash convert --hash-algo sha256 --to sri "$completionsSha" || true)
        if [[ -z "$completionsSha" ]]; then
          add_failure "$pkg" "failed to determine completionsSha256"
          rm -f "$tmp"
          return 1
        fi
      fi

      if [[ "$needsVscodeVersion" == "true" && -z "$vscodeVersion" ]]; then
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
        record_uptodate "$version"
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
      sourceSha=$(prefetch_source "$sourceUrl" || true)
      if [[ -z "$sourceSha" ]]; then
        add_failure "$pkg" "failed to compute sourceSha256"
        return 1
      fi
      sourceSha=$(nix hash convert --hash-algo sha256 --to sri "$sourceSha" || true)

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
          add_failure "$pkg" "could not figure out vendorHash, set it by hand or run nix build .#$pkg"
          return 1
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
        record_uptodate "$rev"
        return 0
      fi

      echo "$pkg: $(display_version "$current_rev") -> $(short_rev "$rev")" >&2

      sourceUrl="https://github.com/$repoOwner/$repoName/archive/$rev.tar.gz"
      sourceSha=""
      sourceSha=$(prefetch_source "$sourceUrl" || true)
      if [[ -z "$sourceSha" ]]; then
        add_failure "$pkg" "failed to compute sourceSha256"
        return 1
      fi
      sourceSha=$(nix hash convert --hash-algo sha256 --to sri "$sourceSha" || true)

      case "$pkg" in
      elephant)
        vendorHashPlaceholder="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        vendorHash=$(release_field_value "$releaseFile" "vendorHash")
        if [[ -z "$vendorHash" || "$vendorHash" == "$vendorHashPlaceholder" ]]; then
          vendorHash="$vendorHashPlaceholder"
        fi
        ;;
      esac

      if ! validate_release_values "$pkg"; then
        return 1
      fi

      if ! write_release_file "$pkg" "$releaseFile"; then
        add_failure "$pkg" "failed to write $releaseFile"
        return 1
      fi

      case "$pkg" in
      elephant)
        if ! refresh_vendor_hash "$pkg" "$releaseFile"; then
          return 1
        fi
        ;;
      esac

      record_update "$current_rev" "$rev"
    }

    meta='${metaJson}'
    goPackages='${goPackagesJson}'
    branchSources='${branchSourcesJson}'
    package_names=$(jq -r 'keys[]' <<<"$meta")

    total_packages=0
    total_packages=$((total_packages + $(jq 'keys | length' <<<"$meta")))
    total_packages=$((total_packages + $(jq 'keys | length' <<<"$goPackages")))
    total_packages=$((total_packages + $(jq 'keys | length' <<<"$branchSources")))

    status_line header "update-release: checking $total_packages packages ($max_jobs parallel jobs)"
    printf '\n' >&2

    for pkg in $package_names; do
      spawn_job update_package "$pkg"
    done

    for pkg in $(jq -r 'keys[]' <<<"$goPackages"); do
      spawn_job update_go_package "$pkg"
    done

    for pkg in $(jq -r 'keys[]' <<<"$branchSources"); do
      spawn_job update_branch_package "$pkg"
    done

    for pid in "''${running_pids[@]}"; do
      wait "$pid" 2>/dev/null || true
    done

    printf '\n' >&2
    status_line header "--- packages ---"

    for job_index in "''${!job_pids[@]}"; do
      pkg="''${job_packages[$job_index]}"
      status_file="''${job_status_files[$job_index]}"
      result_file="''${job_result_files[$job_index]}"
      log_file="''${job_log_files[$job_index]}"
      message=""

      wait "''${job_pids[$job_index]}" 2>/dev/null || true

      message=$(cat "$status_file" 2>/dev/null || true)
      if [[ "$message" != "success" ]]; then
        if [[ -z "$message" ]]; then
          message="failed to update package"
        fi
        collect_job_failure "$pkg" "$message"
        status_line fail "fail $pkg: $message"
        status_line detail "  log excerpt ($log_file):"
        tail -n 5 "$log_file" 2>/dev/null | awk '{print "  " $0}' >&2 || true
        continue
      fi

      mapfile -t job_result < "$result_file"
      kind="''${job_result[0]:-}"

      if [[ "$kind" == "updated" && "''${#job_result[@]}" -eq 3 ]]; then
        from_raw="''${job_result[1]}"
        to_raw="''${job_result[2]}"
        updates+=("$pkg:$(display_version "$from_raw"):$to_raw")
        updated_packages+=("$pkg")
        from_disp=$(display_revision "$pkg" "$from_raw")
        to_disp=$(display_revision "$pkg" "$to_raw")
        status_line update "update $pkg: $from_disp -> $to_disp"
        grep -E "^(fetch |wrote |vendorHash unchanged|found vendorHash|get vendorHash)" "$log_file" 2>/dev/null | awk '{print "  " $0}' >&2 || true
      elif [[ "$kind" == "uptodate" && "''${#job_result[@]}" -eq 2 ]]; then
        current_raw="''${job_result[1]}"
        current_disp=$(display_revision "$pkg" "$current_raw")
        uptodate_packages+=("$pkg")
        status_line ok "ok $pkg $current_disp (up-to-date)"
      else
        message="failed to parse package update result"
        collect_job_failure "$pkg" "$message"
        status_line fail "fail $pkg: $message"
        tail -n 5 "$log_file" 2>/dev/null | awk '{print "  " $0}' >&2 || true
        continue
      fi
    done

    printf '\n' >&2
    status_line header "--- summary ---"

    if (( ''${#updated_packages[@]} > 0 )); then
      status_line update "updated (''${#updated_packages[@]}): $(join_packages "''${updated_packages[@]}")"
    else
      status_line update "updated (0): -"
    fi

    if (( ''${#uptodate_packages[@]} > 0 )); then
      status_line ok "up-to-date (''${#uptodate_packages[@]}): $(join_packages "''${uptodate_packages[@]}")"
    else
      status_line ok "up-to-date (0): -"
    fi

    if (( ''${#failurePackages[@]} > 0 )); then
      status_line fail "failed (''${#failurePackages[@]}): $(join_packages "''${failurePackages[@]}")"
    else
      status_line fail "failed (0): -"
    fi

    if [[ "''${#failurePackages[@]}" -gt 0 ]]; then
      printf '\n' >&2
      status_line fail "failed:"
      for failureIndex in "''${!failurePackages[@]}"; do
        status_line fail "- ''${failurePackages[$failureIndex]}: ''${failureMessages[$failureIndex]}"
      done
      exit 1
    fi

    printf '\n' >&2
    status_line header "--- phases ---"

    if ! run_phase "flake.lock update" nix flake update; then
      status_line detail "Warning: flake update failed, continuing with existing flake.lock"
    fi

    if ! run_phase "format (nix fmt)" nix fmt; then
      status_line detail "Warning: fmt failed, continuing with unformatted files"
    fi

    run_phase "lint checks" nix build --no-link \
      ".#checks.x86_64-linux.embedded-lint" \
      ".#checks.x86_64-linux.format" \
      ".#checks.x86_64-linux.linter" \
      ".#checks.x86_64-linux.yamllint"

    if [[ "$COMMIT" == "true" ]]; then
      echo "" >&2
      echo "stage releases, formatted files, and flake.lock for commit" >&2
      git add flake.lock flake.nix apps/ packages/ releases/

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

    printf '\n' >&2
    total_elapsed=$((SECONDS - start_seconds))
    status_line header "done in ''${total_elapsed}s"
  '';
}
