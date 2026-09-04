#!/usr/bin/env bash
#
# registry.sh - maintenance helper for the Alchemy vcpkg registry.
#
# Run `scripts/registry.sh help` for the command list, or see README.md for
# the full add-a-port / update-a-port workflow.
#
# scripts/registry.ps1 is the PowerShell twin of this script. The two are
# meant to stay command-for-command identical; change both together.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

# vcpkg resolves the registry from these two directories rather than from a
# vcpkg clone's own ports/versions. Relative paths keep this working under
# both Git Bash (where vcpkg.exe would otherwise see an MSYS path) and Linux.
VCPKG_REG=(--x-builtin-ports-root=./ports --x-builtin-registry-versions-dir=./versions)

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_B=$'\033[1m'; C_R=$'\033[31m'; C_Y=$'\033[33m'; C_G=$'\033[32m'
    C_D=$'\033[2m'; C_N=$'\033[0m'
else
    C_B=''; C_R=''; C_Y=''; C_G=''; C_D=''; C_N=''
fi

info() { printf '%s==>%s %s\n' "${C_B}" "${C_N}" "$*"; }
ok()   { printf '%sok%s      %s\n' "${C_G}" "${C_N}" "$*"; }
warn() { printf '%swarn%s    %s\n' "${C_Y}" "${C_N}" "$*" >&2; }
err()  { printf '%serror%s   %s\n' "${C_R}" "${C_N}" "$*" >&2; }
die()  { err "$*"; exit 1; }

TMPDIR_SELF=''
# The trap's own status becomes the script's, so preserve the real one. Removing
# the throwaway git repos can fail on Windows read-only objects; that is not an
# error worth reporting from a temp directory.
cleanup() {
    local status=$?
    if [[ -n "${TMPDIR_SELF}" && -d "${TMPDIR_SELF}" ]]; then
        rm -rf "${TMPDIR_SELF}" 2>/dev/null || true
    fi
    return "${status}"
}
trap cleanup EXIT
mktmp() {
    if [[ -z "${TMPDIR_SELF}" ]]; then
        TMPDIR_SELF="$(mktemp -d 2>/dev/null || mktemp -d -t registry)"
    fi
    printf '%s' "${TMPDIR_SELF}"
}

# ---------------------------------------------------------------- discovery --

# Locate vcpkg: $VCPKG wins, then $VCPKG_ROOT, then PATH. Prints nothing when
# there is none, so that optional uses can fall back instead of aborting.
locate_vcpkg() {
    if [[ -n "${VCPKG:-}" ]]; then
        printf '%s' "${VCPKG}"
        return 0
    fi
    if [[ -n "${VCPKG_ROOT:-}" ]]; then
        # VCPKG_ROOT is often a Windows path with backslashes.
        local root="${VCPKG_ROOT//\\//}"
        local cand
        for cand in "${root}/vcpkg" "${root}/vcpkg.exe"; do
            [[ -x "${cand}" ]] && { printf '%s' "${cand}"; return 0; }
        done
    fi
    command -v vcpkg 2>/dev/null || true
}

VCPKG_BIN=''
have_vcpkg() {
    [[ -n "${VCPKG_BIN}" ]] || VCPKG_BIN="$(locate_vcpkg)"
    [[ -n "${VCPKG_BIN}" ]]
}
vcpkg() {
    have_vcpkg ||
        die 'vcpkg not found. Set VCPKG_ROOT, set VCPKG to the executable, or put vcpkg on PATH.'
    "${VCPKG_BIN}" "$@"
}

ports() {
    local d
    for d in ports/*/; do
        [[ -d "${d}" ]] && basename "${d}"
    done
}

require_port() {
    [[ -d "ports/$1" ]] || die "no such port: $1 (see \`$0 list\`)"
}

# versions/<first letter>-/<name>.json
version_file() { printf 'versions/%s-/%s.json' "${1:0:1}" "$1"; }

# --------------------------------------------------------- manifest parsing --

# The manifests are hand-maintained JSON and no jq is assumed, so read and
# write the individual fields with anchored regexes. That also means edits
# preserve the surrounding formatting verbatim.

manifest_version_key() {
    grep -oE '"version(-semver|-string|-date)?"[[:space:]]*:' "$1" | head -1 |
        sed -E 's/"[[:space:]]*:$//; s/^"//'
}

manifest_version() {
    grep -oE '"version(-semver|-string|-date)?"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" |
        head -1 | sed -E 's/.*:[[:space:]]*"//; s/"$//'
}

manifest_port_version() {
    local v
    v="$(grep -oE '"port-version"[[:space:]]*:[[:space:]]*[0-9]+' "$1" | head -1 |
        grep -oE '[0-9]+$' || true)"
    printf '%s' "${v:-0}"
}

manifest_name() {
    grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" | head -1 |
        sed -E 's/.*:[[:space:]]*"//; s/"$//'
}

# --------------------------------------------------------- portfile parsing --

# Print the body of the first vcpkg_from_github(...) call in a portfile.
# Comments are stripped first so that a '(' inside a comment cannot throw off
# the depth count. Only the first call is considered: a few portfiles (tracy)
# fetch a second, vendored repo, and that one is not the port's own source.
github_block() {
    awk '
        { line = $0; sub(/#.*/, "", line) }
        !inblock && line ~ /vcpkg_from_github[[:space:]]*\(/ {
            inblock = 1
            depth = 0
        }
        inblock {
            n = gsub(/\(/, "(", line); depth += n
            n = gsub(/\)/, ")", line); depth -= n
            print line
            if (depth <= 0) exit
        }
    ' "$1"
}

# Value of a single-token argument (REPO / REF / SHA512) in the block on stdin.
block_arg() {
    grep -oE "^[[:space:]]*$1[[:space:]]+\S+" | head -1 |
        sed -E "s/^[[:space:]]*$1[[:space:]]+//; s/^\"//; s/\"$//"
}

# Patch filenames listed under PATCHES, in order. Entries that do not resolve
# to a file inside the port directory (for example "${SOURCE_PATH}/..." paths,
# which are applied to a nested source tree) are skipped.
block_patches() {
    local port="$1" line name
    github_block "ports/${port}/portfile.cmake" |
        sed -n '/^[[:space:]]*PATCHES[[:space:]]*$/,$p' | tail -n +2 |
        while IFS= read -r line; do
            line="${line%%#*}"
            line="$(printf '%s' "${line}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"//; s/"$//')"
            [[ -z "${line}" || "${line}" == ")" ]] && continue
            name="${line}"
            [[ -f "ports/${port}/${name}" ]] && printf '%s\n' "${name}"
        done
}

# ------------------------------------------------------------------ helpers --

# Normalise a version or tag for comparison: lowercase, drop the common tag
# prefixes, and strip leading zeros from numeric components so that FAudio's
# calendar tag 26.09 compares equal to the manifest version 26.9.
norm_version() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' |
        sed -E 's/^(v|release-|curl-|emojibase-data@)//; s/_/./g; s/(^|[.-])0+([0-9])/\1\2/g'
}

gh_api() {
    if command -v gh >/dev/null 2>&1; then
        gh api "$1" 2>/dev/null || true
    else
        local auth=()
        [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
        curl -fsSL -H 'Accept: application/vnd.github+json' \
            ${auth[@]+"${auth[@]}"} "https://api.github.com/$1" 2>/dev/null || true
    fi
}

json_field() { grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed -E 's/.*:[[:space:]]*"//; s/"$//'; }

download() {
    local url="$1" out="$2"
    curl -fsSL --retry 3 -o "${out}" "${url}" ||
        die "download failed: ${url}"
}

# Prefer `vcpkg hash`, which is the implementation vcpkg itself checks against.
sha512_of() {
    local out
    if have_vcpkg && out="$(vcpkg hash "$1" 2>/dev/null)" &&
        [[ "${out}" =~ ^[0-9a-f]{128}$ ]]; then
        printf '%s\n' "${out}"
        return 0
    fi
    if command -v sha512sum >/dev/null 2>&1; then
        sha512sum "$1" | cut -d' ' -f1
    else
        shasum -a 512 "$1" | cut -d' ' -f1
    fi
}

git_dirty() { [[ -n "$(git status --porcelain -- "$@")" ]]; }

# Expand a portfile REF template against a version. Returns non-zero if the
# template uses anything other than ${VERSION}, in which case the caller must
# be given an explicit ref.
expand_ref() {
    local tmpl="$1" version="$2" out
    out="${tmpl//\$\{VERSION\}/${version}}"
    [[ "${out}" == *'${'* ]] && return 1
    printf '%s' "${out}"
}

# ----------------------------------------------------------------- commands --

cmd_list() {
    printf '%-30s %-16s %-12s %s\n' PORT VERSION PORT-VERSION SOURCE
    local p m repo
    for p in $(ports); do
        m="ports/${p}/vcpkg.json"
        [[ -f "${m}" ]] || continue
        repo="$(github_block "ports/${p}/portfile.cmake" 2>/dev/null | block_arg REPO || true)"
        printf '%-30s %-16s %-12s %s\n' \
            "${p}" "$(manifest_version "${m}")" "$(manifest_port_version "${m}")" \
            "${repo:-${C_D}non-github${C_N}}"
    done
}

cmd_verify() {
    local fix=0 a
    for a in "$@"; do
        case "${a}" in
            --fix) fix=1 ;;
            *) die "verify: unknown option ${a}" ;;
        esac
    done

    local failures=0
    info 'Checking port layout'
    local p m name vf
    for p in $(ports); do
        m="ports/${p}/vcpkg.json"
        if [[ ! -f "${m}" ]]; then
            err "ports/${p}: missing vcpkg.json"; failures=$((failures + 1)); continue
        fi
        [[ -f "ports/${p}/portfile.cmake" ]] ||
            { err "ports/${p}: missing portfile.cmake"; failures=$((failures + 1)); }
        name="$(manifest_name "${m}")"
        [[ "${name}" == "${p}" ]] ||
            { err "ports/${p}: manifest name is \"${name}\""; failures=$((failures + 1)); }
        vf="$(version_file "${p}")"
        [[ -f "${vf}" ]] ||
            { err "ports/${p}: no version file at ${vf}"; failures=$((failures + 1)); }
        grep -qE "\"${p}\"[[:space:]]*:" versions/baseline.json ||
            { err "ports/${p}: not in versions/baseline.json"; failures=$((failures + 1)); }
    done

    info 'Checking for orphaned version files'
    local f base
    for f in versions/*-/*.json; do
        [[ -f "${f}" ]] || continue
        base="$(basename "${f}" .json)"
        [[ -d "ports/${base}" ]] ||
            { err "${f}: no matching port"; failures=$((failures + 1)); }
    done

    # format-manifest and x-add-version both rewrite files in place, so they
    # can only be used as a check when there is nothing else in the tree to
    # confuse with their output.
    if git_dirty ports versions && (( ! fix )); then
        warn 'working tree has uncommitted changes under ports/ or versions/'
        warn 'skipping manifest-format and version-database checks'
        warn 'commit or stash first, or re-run with --fix to keep the rewrites'
    else
        info 'Checking manifest formatting'
        local fmt_out
        fmt_out="$(vcpkg "${VCPKG_REG[@]}" format-manifest --all 2>&1)" || true
        if grep -q 'error:' <<<"${fmt_out}"; then
            err 'format-manifest reported problems:'
            printf '%s\n' "${fmt_out}" >&2
            failures=$((failures + 1))
        fi

        info 'Checking version database'
        local add_out
        add_out="$(vcpkg "${VCPKG_REG[@]}" x-add-version --all 2>&1)" || true
        # x-add-version --all reports a port whose tree changed without a
        # version bump on stdout but still exits 0, so the text is the only
        # reliable signal. The single-port form does set a failing status.
        if grep -q 'error:' <<<"${add_out}"; then
            err 'version database does not match the committed ports:'
            printf '%s\n' "${add_out}" >&2
            err 'bump the version (or port-version) for the port named above, then re-run add-version'
            failures=$((failures + 1))
        fi

        local changed
        changed="$(git status --porcelain -- ports versions)"
        if [[ -n "${changed}" ]]; then
            if (( fix )); then
                warn 'the following files were brought up to date:'
                printf '%s\n' "${changed}" >&2
            else
                err 'registry is out of date; these files would change:'
                printf '%s\n' "${changed}" >&2
                err "re-run with --fix, or run \`$0 add-version <port>\` after a port edit"
                git checkout -- ports versions
                failures=$((failures + 1))
            fi
        fi
    fi

    if (( failures )); then
        err "${failures} problem(s) found"
        return 1
    fi
    ok 'registry is consistent'
}

cmd_outdated() {
    local -a targets
    if (( $# )); then
        targets=("$@")
    else
        mapfile -t targets < <(ports)
    fi

    printf '%-30s %-16s %-20s %s\n' PORT CURRENT UPSTREAM NOTE
    local p m repo ref cur latest note body
    for p in "${targets[@]}"; do
        require_port "${p}"
        m="ports/${p}/vcpkg.json"
        cur="$(manifest_version "${m}")"
        repo="$(github_block "ports/${p}/portfile.cmake" 2>/dev/null | block_arg REPO || true)"

        if [[ -z "${repo}" ]]; then
            printf '%-30s %-16s %-20s %s\n' "${p}" "${cur}" '-' 'not a github source; check by hand'
            continue
        fi

        ref="$(github_block "ports/${p}/portfile.cmake" | block_arg REF || true)"
        if [[ "${ref}" =~ ^[0-9a-f]{40}$ ]]; then
            printf '%-30s %-16s %-20s %s\n' "${p}" "${cur}" '-' "pinned to a commit in ${repo}"
            continue
        fi

        body="$(gh_api "repos/${repo}/releases/latest")"
        latest="$(printf '%s' "${body}" | json_field tag_name)"
        note='latest release'
        if [[ -z "${latest}" ]]; then
            # No published releases, or the repo only tags. The tags endpoint is
            # not version-sorted, so treat this as a hint rather than an answer.
            body="$(gh_api "repos/${repo}/tags?per_page=1")"
            latest="$(printf '%s' "${body}" | json_field name)"
            note='most recent tag (unsorted; verify)'
        fi
        if [[ -z "${latest}" ]]; then
            printf '%-30s %-16s %-20s %s\n' "${p}" "${cur}" '?' "could not query ${repo}"
            continue
        fi

        if [[ "$(norm_version "${cur}")" == "$(norm_version "${latest}")" ]]; then
            printf '%-30s %-16s %-20s %s\n' "${p}" "${cur}" "${latest}" "${C_G}up to date${C_N}"
        else
            printf '%-30s %-16s %-20s %s\n' "${p}" "${cur}" "${latest}" "${C_Y}differs${C_N} - ${note}"
        fi
    done
}

cmd_hash() {
    [[ $# -ge 1 ]] || die "usage: $0 hash <url> | $0 hash <owner/repo> <ref>"
    local url tmp
    if [[ $# -eq 2 ]]; then
        url="https://github.com/$1/archive/$2.tar.gz"
    else
        url="$1"
    fi
    tmp="$(mktmp)/archive"
    info "Downloading ${url}"
    download "${url}" "${tmp}"
    sha512_of "${tmp}"
}

cmd_patches() {
    [[ $# -ge 1 ]] || die "usage: $0 patches <port> [ref]"
    local port="$1"; shift
    require_port "${port}"

    local pf="ports/${port}/portfile.cmake"
    local repo ref version
    repo="$(github_block "${pf}" | block_arg REPO || true)"
    [[ -n "${repo}" ]] || die "${port}: no vcpkg_from_github(REPO ...) to fetch from"

    if (( $# )); then
        ref="$1"
    else
        version="$(manifest_version "ports/${port}/vcpkg.json")"
        ref="$(expand_ref "$(github_block "${pf}" | block_arg REF)" "${version}")" || die \
            "${port}: REF is computed in the portfile; pass the ref explicitly, e.g. \`$0 patches ${port} <ref>\`"
    fi

    local -a patchlist
    mapfile -t patchlist < <(block_patches "${port}")
    if (( ${#patchlist[@]} == 0 )); then
        ok "${port}: no port-local patches to test"
        return 0
    fi

    local tmp work url
    tmp="$(mktmp)"
    url="https://github.com/${repo}/archive/${ref}.tar.gz"
    info "Fetching ${url}"
    download "${url}" "${tmp}/src.tar.gz"

    work="${tmp}/work"
    mkdir -p "${work}"
    tar -xzf "${tmp}/src.tar.gz" -C "${work}"
    local top
    top="$(find "${work}" -mindepth 1 -maxdepth 1 -type d | head -1)"
    [[ -n "${top}" ]] || die "archive did not contain a source directory"

    # A throwaway repo so `git apply` behaves exactly as it does inside vcpkg.
    git -C "${top}" init -q .
    git -C "${top}" add -A
    git -C "${top}" -c user.email=maint@local -c user.name=maint commit -qm upstream

    local failures=0 patch
    for patch in "${patchlist[@]}"; do
        # Same flags vcpkg_extract_source_archive uses to apply PATCHES.
        if git -C "${top}" apply --ignore-whitespace --whitespace=nowarn \
            "${ROOT}/ports/${port}/${patch}" 2>"${tmp}/err"; then
            ok "${patch}"
        else
            err "${patch}"
            sed 's/^/        /' "${tmp}/err" >&2
            failures=$((failures + 1))
        fi
    done

    if (( failures )); then
        err "${failures} of ${#patchlist[@]} patch(es) do not apply to ${repo}@${ref}"
        return 1
    fi
    ok "all ${#patchlist[@]} patch(es) apply to ${repo}@${ref}"
}

cmd_bump() {
    [[ $# -ge 2 ]] || die "usage: $0 bump <port> <new-version> [--ref <ref>] [--sha512 <hash>] [--keep-port-version] [--dry-run]"
    local port="$1" version="$2"; shift 2
    require_port "${port}"

    local ref='' sha='' keep=0 dry=0
    while (( $# )); do
        case "$1" in
            --ref) ref="$2"; shift 2 ;;
            --sha512) sha="$2"; shift 2 ;;
            --keep-port-version) keep=1; shift ;;
            --dry-run) dry=1; shift ;;
            *) die "bump: unknown option $1" ;;
        esac
    done

    local m="ports/${port}/vcpkg.json" pf="ports/${port}/portfile.cmake"
    local key cur
    key="$(manifest_version_key "${m}")"
    cur="$(manifest_version "${m}")"
    [[ -n "${key}" ]] || die "${port}: no version field in vcpkg.json"

    # Only a portfile carrying exactly one *literal* SHA512 can be rewritten
    # unambiguously. Ports that select an archive per platform (cef-bin) pass a
    # variable instead, and each candidate hash has to be updated by hand.
    local -a shalines
    mapfile -t shalines < <(grep -E '^[[:space:]]*SHA512[[:space:]]+' "${pf}" || true)
    if (( ${#shalines[@]} != 1 )); then
        die "${port}: portfile has ${#shalines[@]} SHA512 entries; update ${pf} by hand"
    fi
    local curhash
    curhash="$(printf '%s' "${shalines[0]}" | sed -E 's/^[[:space:]]*SHA512[[:space:]]+//; s/[[:space:]]*$//')"
    if [[ ! "${curhash}" =~ ^[0-9a-fA-F]{128}$ ]]; then
        die "${port}: portfile's SHA512 is \`${curhash}\`, not a literal hash; update ${pf} by hand"
    fi

    if [[ -z "${sha}" ]]; then
        local repo
        repo="$(github_block "${pf}" | block_arg REPO || true)"
        [[ -n "${repo}" ]] || die "${port}: not a github source; pass --sha512 explicitly"
        if [[ -z "${ref}" ]]; then
            ref="$(expand_ref "$(github_block "${pf}" | block_arg REF)" "${version}")" || die \
                "${port}: REF is computed in the portfile; pass --ref explicitly"
        fi
        local tmp url
        tmp="$(mktmp)/archive"
        url="https://github.com/${repo}/archive/${ref}.tar.gz"
        info "Fetching ${url}"
        download "${url}" "${tmp}"
        sha="$(sha512_of "${tmp}")"
    fi

    info "${port}: ${cur} -> ${version}"
    printf '  %-12s %s\n' "${key}" "${version}"
    printf '  %-12s %s\n' 'SHA512' "${sha}"
    (( keep )) || printf '  %-12s %s\n' 'port-version' 'reset to 0 (field removed)'

    if (( dry )); then
        warn 'dry run; no files written'
        return 0
    fi

    # Targeted, formatting-preserving edits: the version value, the optional
    # port-version line, and the single SHA512 argument.
    sed -i -E "0,/\"${key}\"[[:space:]]*:/s|(\"${key}\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")|\1${version}\2|" "${m}"
    (( keep )) || sed -i -E '/^[[:space:]]*"port-version"[[:space:]]*:[[:space:]]*[0-9]+[[:space:]]*,?[[:space:]]*$/d' "${m}"
    sed -i -E "s|^([[:space:]]*SHA512[[:space:]]+)\S+|\1${sha}|" "${pf}"

    # Round-trips the manifest through vcpkg's own formatter, which doubles as
    # a syntax check on the edit above.
    vcpkg "${VCPKG_REG[@]}" format-manifest "${m}" >/dev/null ||
        die "${m} is no longer valid; check the edit"

    ok "${m} and ${pf} updated (not staged)"
    info 'Next:'
    printf '  %s patches %s %s\n' "$0" "${port}" "${ref:-<ref>}"
    printf '  %s build %s\n' "$0" "${port}"
    printf '  git add ports/%s && git commit\n' "${port}"
    printf '  %s add-version %s\n' "$0" "${port}"
}

cmd_add_version() {
    [[ $# -ge 1 ]] || die "usage: $0 add-version <port>|--all [--overwrite]"
    local -a args
    local target="$1"; shift
    local overwrite=0 a
    for a in "$@"; do
        case "${a}" in
            --overwrite) overwrite=1 ;;
            *) die "add-version: unknown option ${a}" ;;
        esac
    done

    # x-add-version hashes the working tree, so a dirty port directory records
    # a git-tree that is not in history until those exact contents are committed.
    if [[ "${target}" == "--all" ]]; then
        args=(--all)
        git_dirty ports && warn 'ports/ has uncommitted changes; commit them first so the recorded git-tree exists in history'
    else
        require_port "${target}"
        args=("${target}")
        git_dirty "ports/${target}" &&
            warn "ports/${target} has uncommitted changes; commit them first so the recorded git-tree exists in history"
    fi
    (( overwrite )) && args+=(--overwrite-version)

    vcpkg "${VCPKG_REG[@]}" x-add-version "${args[@]}"
    ok 'version database updated; commit versions/ to finish'
}

cmd_build() {
    [[ $# -ge 1 ]] || die "usage: $0 build <port> [--triplet <triplet>] [extra vcpkg args...]"
    local port="$1"; shift
    require_port "${port}"

    local -a extra
    while (( $# )); do
        case "$1" in
            --triplet) extra+=("--triplet=$2"); shift 2 ;;
            --triplet=*) extra+=("$1"); shift ;;
            *) extra+=("$1"); shift ;;
        esac
    done

    info "Building ${port}"
    vcpkg install "${port}" "--overlay-ports=${ROOT}/ports" ${extra[@]+"${extra[@]}"}
}

cmd_format() {
    if [[ $# -eq 0 || "$1" == "--all" ]]; then
        vcpkg "${VCPKG_REG[@]}" format-manifest --all
        ok 'all manifests formatted'
    else
        require_port "$1"
        vcpkg "${VCPKG_REG[@]}" format-manifest "ports/$1/vcpkg.json"
        ok "ports/$1/vcpkg.json formatted"
    fi
}

cmd_help() {
    cat <<EOF
${C_B}registry.sh${C_N} - maintenance helper for the Alchemy vcpkg registry

  ${C_B}list${C_N}
      Every port with its version, port-version, and upstream repo.

  ${C_B}verify${C_N} [--fix]
      Check the registry is internally consistent: port layout, baseline
      coverage, orphaned version files, manifest formatting, and that the
      version database matches the committed ports. Without --fix nothing is
      written; the check needs a clean working tree to be meaningful.

  ${C_B}outdated${C_N} [port...]
      Compare each port against its upstream GitHub release or tag.

  ${C_B}hash${C_N} <url> | ${C_B}hash${C_N} <owner/repo> <ref>
      SHA512 of a source archive, in the form portfiles expect.

  ${C_B}patches${C_N} <port> [ref]
      Download the port's upstream source and test-apply its PATCHES with the
      same git flags vcpkg uses. Defaults to the port's current version.

  ${C_B}bump${C_N} <port> <version> [--ref R] [--sha512 H] [--keep-port-version] [--dry-run]
      Rewrite the port's version and SHA512 in place, resetting port-version.
      Downloads the archive to compute the hash unless --sha512 is given.
      Leaves the changes unstaged; does not commit.

  ${C_B}add-version${C_N} <port>|--all [--overwrite]
      Record the port's current git-tree in versions/ and versions/baseline.json.
      Run this after committing a port change.

  ${C_B}build${C_N} <port> [--triplet T] [vcpkg args...]
      Build the port from this registry via an overlay.

  ${C_B}format${C_N} [port|--all]
      Run vcpkg format-manifest.

Environment:
  VCPKG_ROOT   vcpkg checkout to use (or VCPKG for the executable itself)
  GITHUB_TOKEN used by 'outdated' when the gh CLI is not installed
  NO_COLOR     disable colored output

See README.md for the full update-a-port workflow.
EOF
}

# --------------------------------------------------------------------- main --

main() {
    local cmd="${1:-help}"
    [[ $# -gt 0 ]] && shift
    case "${cmd}" in
        list)                 cmd_list "$@" ;;
        verify|check)         cmd_verify "$@" ;;
        outdated)             cmd_outdated "$@" ;;
        hash)                 cmd_hash "$@" ;;
        patches)              cmd_patches "$@" ;;
        bump)                 cmd_bump "$@" ;;
        add-version)          cmd_add_version "$@" ;;
        build|install)        cmd_build "$@" ;;
        format)               cmd_format "$@" ;;
        help|-h|--help)       cmd_help ;;
        *) err "unknown command: ${cmd}"; echo >&2; cmd_help >&2; exit 1 ;;
    esac
}

main "$@"
