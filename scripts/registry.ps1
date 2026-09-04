#Requires -Version 7.0
<#
.SYNOPSIS
    Maintenance helper for the Alchemy vcpkg registry.

.DESCRIPTION
    Run `scripts\registry.ps1 help` for the command list, or see README.md for
    the full add-a-port / update-a-port workflow.

    scripts/registry.sh is the bash twin of this script. The two are meant to
    stay command-for-command identical; change both together.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Command = 'help',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]] $Args_ = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root = Split-Path -Parent $PSScriptRoot
Push-Location $Root

# vcpkg resolves the registry from these two directories rather than from a
# vcpkg clone's own ports/versions. Relative paths keep the invocation short
# and identical to the bash script's.
$VcpkgReg = @('--x-builtin-ports-root=./ports', '--x-builtin-registry-versions-dir=./versions')

if (-not $env:NO_COLOR -and $Host.UI.SupportsVirtualTerminal) {
    $CB = "`e[1m"; $CR = "`e[31m"; $CY = "`e[33m"; $CG = "`e[32m"; $CD = "`e[2m"; $CN = "`e[0m"
} else {
    $CB = ''; $CR = ''; $CY = ''; $CG = ''; $CD = ''; $CN = ''
}

function Write-Info { param([string] $Message) Write-Host "$CB==>$CN $Message" }
function Write-Ok   { param([string] $Message) Write-Host "${CG}ok$CN      $Message" }
function Write-Warn { param([string] $Message) Write-Host "${CY}warn$CN    $Message" }
function Write-Err  { param([string] $Message) Write-Host "${CR}error$CN   $Message" }
# The trailing `finally` restores the location, so no unwinding is done here.
function Stop-Bad   { param([string] $Message) Write-Err $Message; exit 1 }

$script:TempRoot = $null
function Get-TempRoot {
    if (-not $script:TempRoot) {
        $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("vcpkg-registry-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
    }
    return $script:TempRoot
}
function Remove-TempRoot {
    if ($script:TempRoot -and (Test-Path $script:TempRoot)) {
        # Throwaway git repos hold read-only objects on Windows.
        try { Remove-Item -Recurse -Force $script:TempRoot -ErrorAction Stop } catch { }
    }
}

# ---------------------------------------------------------------- discovery --

# Locate vcpkg: $env:VCPKG wins, then $env:VCPKG_ROOT, then PATH. Returns $null
# when there is none, so that optional uses can fall back instead of aborting.
function Find-Vcpkg {
    if ($env:VCPKG) { return $env:VCPKG }
    if ($env:VCPKG_ROOT) {
        foreach ($name in 'vcpkg.exe', 'vcpkg') {
            $candidate = Join-Path $env:VCPKG_ROOT $name
            if (Test-Path $candidate -PathType Leaf) { return $candidate }
        }
    }
    $onPath = Get-Command vcpkg -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    return $null
}

$script:VcpkgBin = $null
function Test-Vcpkg {
    if (-not $script:VcpkgBin) { $script:VcpkgBin = Find-Vcpkg }
    return [bool] $script:VcpkgBin
}
function Invoke-Vcpkg {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]] $VcpkgArgs)
    if (-not (Test-Vcpkg)) {
        Stop-Bad 'vcpkg not found. Set VCPKG_ROOT, set VCPKG to the executable, or put vcpkg on PATH.'
    }
    & $script:VcpkgBin @VcpkgArgs
}

function Get-Ports {
    Get-ChildItem -Path (Join-Path $Root 'ports') -Directory | Select-Object -ExpandProperty Name | Sort-Object
}

function Assert-Port {
    param([string] $Port)
    if (-not (Test-Path (Join-Path $Root "ports/$Port") -PathType Container)) {
        Stop-Bad "no such port: $Port (see ``registry.ps1 list``)"
    }
}

# versions/<first letter>-/<name>.json
function Get-VersionFile { param([string] $Port) "versions/$($Port.Substring(0,1))-/$Port.json" }

# --------------------------------------------------------- manifest parsing --

# The manifests are hand-maintained JSON. Reading and writing individual fields
# with anchored regexes (rather than a ConvertFrom-Json round trip) keeps edits
# from reordering or reformatting anything the change did not touch.

function Get-ManifestVersionKey {
    param([string] $Path)
    $m = [regex]::Match((Get-Content -Raw $Path), '"(version(?:-semver|-string|-date)?)"\s*:')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}
function Get-ManifestVersion {
    param([string] $Path)
    $m = [regex]::Match((Get-Content -Raw $Path), '"version(?:-semver|-string|-date)?"\s*:\s*"([^"]*)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}
function Get-ManifestPortVersion {
    param([string] $Path)
    $m = [regex]::Match((Get-Content -Raw $Path), '"port-version"\s*:\s*(\d+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return '0'
}
function Get-ManifestName {
    param([string] $Path)
    $m = [regex]::Match((Get-Content -Raw $Path), '"name"\s*:\s*"([^"]*)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

# --------------------------------------------------------- portfile parsing --

# Return the body of the first vcpkg_from_github(...) call in a portfile.
# Comments are stripped first so a '(' inside one cannot throw off the depth
# count. Only the first call is considered: a few portfiles (tracy) fetch a
# second, vendored repo, and that one is not the port's own source.
function Get-GithubBlock {
    param([string] $Port)
    $path = Join-Path $Root "ports/$Port/portfile.cmake"
    if (-not (Test-Path $path)) { return @() }

    $out = [System.Collections.Generic.List[string]]::new()
    $inBlock = $false
    $depth = 0
    foreach ($raw in (Get-Content $path)) {
        $line = $raw -replace '#.*', ''
        if (-not $inBlock) {
            if ($line -match 'vcpkg_from_github\s*\(') { $inBlock = $true; $depth = 0 } else { continue }
        }
        $depth += ([regex]::Matches($line, '\(')).Count
        $depth -= ([regex]::Matches($line, '\)')).Count
        $out.Add($line)
        if ($depth -le 0) { break }
    }
    return $out
}

# Value of a single-token argument (REPO / REF) within a github block.
function Get-BlockArg {
    param([string[]] $Block, [string] $Name)
    foreach ($line in $Block) {
        $m = [regex]::Match($line, "^\s*$Name\s+(\S+)")
        if ($m.Success) { return $m.Groups[1].Value.Trim('"') }
    }
    return ''
}

# Patch filenames listed under PATCHES, in order. Entries that do not resolve to
# a file inside the port directory (for example "${SOURCE_PATH}/..." paths,
# which are applied to a nested source tree) are skipped.
function Get-BlockPatches {
    param([string] $Port)
    $block = Get-GithubBlock $Port
    $result = [System.Collections.Generic.List[string]]::new()
    $seen = $false
    foreach ($line in $block) {
        if (-not $seen) {
            if ($line -match '^\s*PATCHES\s*$') { $seen = $true }
            continue
        }
        $name = $line.Trim().Trim('"')
        if (-not $name -or $name -eq ')') { continue }
        if (Test-Path (Join-Path $Root "ports/$Port/$name") -PathType Leaf) { $result.Add($name) }
    }
    return $result
}

# ------------------------------------------------------------------ helpers --

# Normalise a version or tag for comparison: lowercase, drop the common tag
# prefixes, and strip leading zeros from numeric components so that FAudio's
# calendar tag 26.09 compares equal to the manifest version 26.9.
function ConvertTo-NormalVersion {
    param([string] $Value)
    $v = $Value.ToLowerInvariant()
    $v = $v -replace '^(v|release-|curl-|emojibase-data@)', ''
    $v = $v -replace '_', '.'
    $v = $v -replace '(^|[.\-])0+(\d)', '$1$2'
    return $v
}

function Invoke-GitHubApi {
    param([string] $Path)
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
        try { return (& $gh api $Path 2>$null) -join "`n" } catch { return '' }
    }
    $headers = @{ Accept = 'application/vnd.github+json' }
    if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
    try {
        return (Invoke-WebRequest -Uri "https://api.github.com/$Path" -Headers $headers -UseBasicParsing).Content
    } catch { return '' }
}

function Get-JsonField {
    param([string] $Body, [string] $Field)
    $m = [regex]::Match($Body, "`"$Field`"\s*:\s*`"([^`"]*)`"")
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Save-Url {
    param([string] $Url, [string] $OutFile)
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    } catch {
        Stop-Bad "download failed: $Url"
    }
}

# Prefer `vcpkg hash`, which is the implementation vcpkg itself checks against.
function Get-Sha512 {
    param([string] $Path)
    if (Test-Vcpkg) {
        $out = (& $script:VcpkgBin hash $Path 2>$null) -join ''
        if ($out -match '^[0-9a-f]{128}$') { return $out }
    }
    return (Get-FileHash -Algorithm SHA512 -Path $Path).Hash.ToLowerInvariant()
}

function Test-GitDirty {
    param([string[]] $Paths)
    $out = & git status --porcelain -- @Paths
    return [bool] $out
}

# Expand a portfile REF template against a version. Returns $null if the
# template uses anything other than ${VERSION}, in which case the caller must be
# given an explicit ref.
function Expand-Ref {
    param([string] $Template, [string] $Version)
    $out = $Template -replace '\$\{VERSION\}', $Version
    if ($out -match '\$\{') { return $null }
    return $out
}

# ----------------------------------------------------------------- commands --

function Invoke-List {
    Write-Host ('{0,-30} {1,-16} {2,-12} {3}' -f 'PORT', 'VERSION', 'PORT-VERSION', 'SOURCE')
    foreach ($p in Get-Ports) {
        $m = Join-Path $Root "ports/$p/vcpkg.json"
        if (-not (Test-Path $m)) { continue }
        $repo = Get-BlockArg (Get-GithubBlock $p) 'REPO'
        if (-not $repo) { $repo = "${CD}non-github${CN}" }
        Write-Host ('{0,-30} {1,-16} {2,-12} {3}' -f $p, (Get-ManifestVersion $m), (Get-ManifestPortVersion $m), $repo)
    }
}

function Invoke-Verify {
    param([string[]] $Rest = @())
    $fix = $false
    foreach ($a in $Rest) {
        switch ($a) {
            '--fix' { $fix = $true }
            default { Stop-Bad "verify: unknown option $a" }
        }
    }
    if (-not (Test-Vcpkg)) {
        Stop-Bad 'vcpkg not found. Set VCPKG_ROOT, set VCPKG to the executable, or put vcpkg on PATH.'
    }

    $failures = 0

    Write-Info 'Checking port layout'
    $baseline = Get-Content -Raw (Join-Path $Root 'versions/baseline.json')
    foreach ($p in Get-Ports) {
        $m = Join-Path $Root "ports/$p/vcpkg.json"
        if (-not (Test-Path $m)) { Write-Err "ports/${p}: missing vcpkg.json"; $failures++; continue }
        if (-not (Test-Path (Join-Path $Root "ports/$p/portfile.cmake"))) {
            Write-Err "ports/${p}: missing portfile.cmake"; $failures++
        }
        $name = Get-ManifestName $m
        if ($name -ne $p) { Write-Err "ports/${p}: manifest name is `"$name`""; $failures++ }
        $vf = Get-VersionFile $p
        if (-not (Test-Path (Join-Path $Root $vf))) { Write-Err "ports/${p}: no version file at $vf"; $failures++ }
        if ($baseline -notmatch "`"$([regex]::Escape($p))`"\s*:") {
            Write-Err "ports/${p}: not in versions/baseline.json"; $failures++
        }
    }

    Write-Info 'Checking for orphaned version files'
    foreach ($f in Get-ChildItem -Path (Join-Path $Root 'versions') -Directory -Filter '*-') {
        foreach ($j in Get-ChildItem -Path $f.FullName -Filter '*.json') {
            if (-not (Test-Path (Join-Path $Root "ports/$($j.BaseName)") -PathType Container)) {
                Write-Err "versions/$($f.Name)/$($j.Name): no matching port"; $failures++
            }
        }
    }

    # format-manifest and x-add-version both rewrite files in place, so they can
    # only be used as a check when there is nothing else in the tree to confuse
    # with their output.
    if ((Test-GitDirty @('ports', 'versions')) -and -not $fix) {
        Write-Warn 'working tree has uncommitted changes under ports/ or versions/'
        Write-Warn 'skipping manifest-format and version-database checks'
        Write-Warn 'commit or stash first, or re-run with --fix to keep the rewrites'
    } else {
        Write-Info 'Checking manifest formatting'
        $fmtOut = (& $script:VcpkgBin @VcpkgReg format-manifest --all 2>&1 | Out-String)
        if ($fmtOut -match 'error:') {
            Write-Err 'format-manifest reported problems:'
            Write-Host $fmtOut
            $failures++
        }

        Write-Info 'Checking version database'
        $addOut = (& $script:VcpkgBin @VcpkgReg x-add-version --all 2>&1 | Out-String)
        # x-add-version --all reports a port whose tree changed without a version
        # bump on stdout but still exits 0, so the text is the only reliable
        # signal. The single-port form does set a failing status.
        if ($addOut -match 'error:') {
            Write-Err 'version database does not match the committed ports:'
            Write-Host $addOut
            Write-Err 'bump the version (or port-version) for the port named above, then re-run add-version'
            $failures++
        }

        $changed = & git status --porcelain -- ports versions
        if ($changed) {
            if ($fix) {
                Write-Warn 'the following files were brought up to date:'
                $changed | ForEach-Object { Write-Host $_ }
            } else {
                Write-Err 'registry is out of date; these files would change:'
                $changed | ForEach-Object { Write-Host $_ }
                Write-Err 're-run with --fix, or run `registry.ps1 add-version <port>` after a port edit'
                & git checkout -- ports versions
                $failures++
            }
        }
    }

    if ($failures -gt 0) {
        Write-Err "$failures problem(s) found"

        exit 1
    }
    Write-Ok 'registry is consistent'
}

function Invoke-Outdated {
    param([string[]] $Rest = @())
    $targets = $Rest.Count -gt 0 ? $Rest : (Get-Ports)

    Write-Host ('{0,-30} {1,-16} {2,-20} {3}' -f 'PORT', 'CURRENT', 'UPSTREAM', 'NOTE')
    foreach ($p in $targets) {
        Assert-Port $p
        $m = Join-Path $Root "ports/$p/vcpkg.json"
        $cur = Get-ManifestVersion $m
        $block = Get-GithubBlock $p
        $repo = Get-BlockArg $block 'REPO'

        if (-not $repo) {
            Write-Host ('{0,-30} {1,-16} {2,-20} {3}' -f $p, $cur, '-', 'not a github source; check by hand')
            continue
        }

        $ref = Get-BlockArg $block 'REF'
        if ($ref -match '^[0-9a-f]{40}$') {
            Write-Host ('{0,-30} {1,-16} {2,-20} {3}' -f $p, $cur, '-', "pinned to a commit in $repo")
            continue
        }

        $latest = Get-JsonField (Invoke-GitHubApi "repos/$repo/releases/latest") 'tag_name'
        $note = 'latest release'
        if (-not $latest) {
            # No published releases, or the repo only tags. The tags endpoint is
            # not version-sorted, so treat this as a hint rather than an answer.
            $latest = Get-JsonField (Invoke-GitHubApi "repos/$repo/tags?per_page=1") 'name'
            $note = 'most recent tag (unsorted; verify)'
        }
        if (-not $latest) {
            Write-Host ('{0,-30} {1,-16} {2,-20} {3}' -f $p, $cur, '?', "could not query $repo")
            continue
        }

        if ((ConvertTo-NormalVersion $cur) -eq (ConvertTo-NormalVersion $latest)) {
            Write-Host ('{0,-30} {1,-16} {2,-20} {3}' -f $p, $cur, $latest, "${CG}up to date${CN}")
        } else {
            Write-Host ('{0,-30} {1,-16} {2,-20} {3}' -f $p, $cur, $latest, "${CY}differs${CN} - $note")
        }
    }
}

function Invoke-Hash {
    param([string[]] $Rest = @())
    if ($Rest.Count -lt 1) { Stop-Bad 'usage: registry.ps1 hash <url> | registry.ps1 hash <owner/repo> <ref>' }
    $url = $Rest.Count -ge 2 ? "https://github.com/$($Rest[0])/archive/$($Rest[1]).tar.gz" : $Rest[0]
    $tmp = Join-Path (Get-TempRoot) 'archive'
    Write-Info "Downloading $url"
    Save-Url $url $tmp
    Write-Host (Get-Sha512 $tmp)
}

function Invoke-Patches {
    param([string[]] $Rest = @())
    if ($Rest.Count -lt 1) { Stop-Bad 'usage: registry.ps1 patches <port> [ref]' }
    $port = $Rest[0]
    Assert-Port $port

    $block = Get-GithubBlock $port
    $repo = Get-BlockArg $block 'REPO'
    if (-not $repo) { Stop-Bad "${port}: no vcpkg_from_github(REPO ...) to fetch from" }

    if ($Rest.Count -ge 2) {
        $ref = $Rest[1]
    } else {
        $version = Get-ManifestVersion (Join-Path $Root "ports/$port/vcpkg.json")
        $ref = Expand-Ref (Get-BlockArg $block 'REF') $version
        if (-not $ref) {
            Stop-Bad "${port}: REF is computed in the portfile; pass the ref explicitly, e.g. ``registry.ps1 patches $port <ref>``"
        }
    }

    $patches = Get-BlockPatches $port
    if ($patches.Count -eq 0) { Write-Ok "${port}: no port-local patches to test"; return }

    $tmp = Get-TempRoot
    $url = "https://github.com/$repo/archive/$ref.tar.gz"
    Write-Info "Fetching $url"
    $tarball = Join-Path $tmp 'src.tar.gz'
    Save-Url $url $tarball

    $work = Join-Path $tmp 'work'
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    & tar -xzf $tarball -C $work
    $top = Get-ChildItem -Path $work -Directory | Select-Object -First 1
    if (-not $top) { Stop-Bad 'archive did not contain a source directory' }

    # A throwaway repo so `git apply` behaves exactly as it does inside vcpkg.
    & git -C $top.FullName init -q .
    & git -C $top.FullName add -A
    & git -C $top.FullName -c user.email=maint@local -c user.name=maint commit -qm upstream

    $failures = 0
    foreach ($patch in $patches) {
        $full = Join-Path $Root "ports/$port/$patch"
        # Same flags vcpkg_extract_source_archive uses to apply PATCHES.
        $out = & git -C $top.FullName apply --ignore-whitespace --whitespace=nowarn $full 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Ok $patch
        } else {
            Write-Err $patch
            $out | ForEach-Object { Write-Host "        $_" }
            $failures++
        }
    }

    if ($failures -gt 0) {
        Write-Err "$failures of $($patches.Count) patch(es) do not apply to $repo@$ref"

        exit 1
    }
    Write-Ok "all $($patches.Count) patch(es) apply to $repo@$ref"
}

function Invoke-Bump {
    param([string[]] $Rest = @())
    if ($Rest.Count -lt 2) {
        Stop-Bad 'usage: registry.ps1 bump <port> <new-version> [--ref <ref>] [--sha512 <hash>] [--keep-port-version] [--dry-run]'
    }
    $port = $Rest[0]
    $version = $Rest[1]
    Assert-Port $port

    $ref = ''; $sha = ''; $keep = $false; $dry = $false
    for ($i = 2; $i -lt $Rest.Count; $i++) {
        switch ($Rest[$i]) {
            '--ref' { $ref = $Rest[++$i] }
            '--sha512' { $sha = $Rest[++$i] }
            '--keep-port-version' { $keep = $true }
            '--dry-run' { $dry = $true }
            default { Stop-Bad "bump: unknown option $($Rest[$i])" }
        }
    }

    $m = Join-Path $Root "ports/$port/vcpkg.json"
    $pf = Join-Path $Root "ports/$port/portfile.cmake"
    $key = Get-ManifestVersionKey $m
    $cur = Get-ManifestVersion $m
    if (-not $key) { Stop-Bad "${port}: no version field in vcpkg.json" }

    # Only a portfile carrying exactly one *literal* SHA512 can be rewritten
    # unambiguously. Ports that select an archive per platform (cef-bin) pass a
    # variable instead, and each candidate hash has to be updated by hand.
    $pfText = Get-Content -Raw $pf
    $shaMatches = [regex]::Matches($pfText, '(?m)^[ \t]*SHA512[ \t]+(\S+)[ \t]*$')
    if ($shaMatches.Count -ne 1) {
        Stop-Bad "${port}: portfile has $($shaMatches.Count) SHA512 entries; update ports/$port/portfile.cmake by hand"
    }
    $curHash = $shaMatches[0].Groups[1].Value
    if ($curHash -notmatch '^[0-9a-fA-F]{128}$') {
        Stop-Bad "${port}: portfile's SHA512 is ``$curHash``, not a literal hash; update ports/$port/portfile.cmake by hand"
    }

    if (-not $sha) {
        $repo = Get-BlockArg (Get-GithubBlock $port) 'REPO'
        if (-not $repo) { Stop-Bad "${port}: not a github source; pass --sha512 explicitly" }
        if (-not $ref) {
            $ref = Expand-Ref (Get-BlockArg (Get-GithubBlock $port) 'REF') $version
            if (-not $ref) { Stop-Bad "${port}: REF is computed in the portfile; pass --ref explicitly" }
        }
        $tmp = Join-Path (Get-TempRoot) 'archive'
        $url = "https://github.com/$repo/archive/$ref.tar.gz"
        Write-Info "Fetching $url"
        Save-Url $url $tmp
        $sha = Get-Sha512 $tmp
    }

    Write-Info "${port}: $cur -> $version"
    Write-Host ('  {0,-12} {1}' -f $key, $version)
    Write-Host ('  {0,-12} {1}' -f 'SHA512', $sha)
    if (-not $keep) { Write-Host ('  {0,-12} {1}' -f 'port-version', 'reset to 0 (field removed)') }

    if ($dry) { Write-Warn 'dry run; no files written'; return }

    # Targeted, formatting-preserving edits: the version value, the optional
    # port-version line, and the single SHA512 argument. Each replaces only the
    # first match, which needs the instance Replace(input, replacement, count) --
    # the static four-argument form takes RegexOptions, not a count.
    $manifest = Get-Content -Raw $m
    $manifest = [regex]::new("(`"$key`"\s*:\s*`")[^`"]*(`")").Replace($manifest, "`${1}$version`${2}", 1)
    if (-not $keep) {
        $manifest = [regex]::new('(?m)^[ \t]*"port-version"\s*:\s*\d+\s*,?[ \t]*\r?\n').Replace($manifest, '', 1)
    }
    Set-Content -Path $m -Value $manifest -NoNewline
    Set-Content -Path $pf -Value ([regex]::new('(?m)^([ \t]*SHA512[ \t]+)\S+').Replace($pfText, "`${1}$sha", 1)) -NoNewline

    # Round-trips the manifest through vcpkg's own formatter, which doubles as a
    # syntax check on the edit above.
    Invoke-Vcpkg @VcpkgReg format-manifest $m | Out-Null
    if ($LASTEXITCODE -ne 0) { Stop-Bad "$m is no longer valid; check the edit" }

    Write-Ok "ports/$port/vcpkg.json and ports/$port/portfile.cmake updated (not staged)"
    Write-Info 'Next:'
    $refShown = $ref ? $ref : '<ref>'
    Write-Host "  scripts\registry.ps1 patches $port $refShown"
    Write-Host "  scripts\registry.ps1 build $port"
    Write-Host "  git add ports/$port && git commit"
    Write-Host "  scripts\registry.ps1 add-version $port"
}

function Invoke-AddVersion {
    param([string[]] $Rest = @())
    if ($Rest.Count -lt 1) { Stop-Bad 'usage: registry.ps1 add-version <port>|--all [--overwrite]' }
    $target = $Rest[0]
    $overwrite = $false
    for ($i = 1; $i -lt $Rest.Count; $i++) {
        switch ($Rest[$i]) {
            '--overwrite' { $overwrite = $true }
            default { Stop-Bad "add-version: unknown option $($Rest[$i])" }
        }
    }

    # x-add-version hashes the working tree, so a dirty port directory records a
    # git-tree that is not in history until those exact contents are committed.
    $vcpkgArgs = @()
    if ($target -eq '--all') {
        $vcpkgArgs += '--all'
        if (Test-GitDirty @('ports')) {
            Write-Warn 'ports/ has uncommitted changes; commit them first so the recorded git-tree exists in history'
        }
    } else {
        Assert-Port $target
        $vcpkgArgs += $target
        if (Test-GitDirty @("ports/$target")) {
            Write-Warn "ports/$target has uncommitted changes; commit them first so the recorded git-tree exists in history"
        }
    }
    if ($overwrite) { $vcpkgArgs += '--overwrite-version' }

    Invoke-Vcpkg @VcpkgReg x-add-version @vcpkgArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Ok 'version database updated; commit versions/ to finish'
}

function Invoke-Build {
    param([string[]] $Rest = @())
    if ($Rest.Count -lt 1) { Stop-Bad 'usage: registry.ps1 build <port> [--triplet <triplet>] [extra vcpkg args...]' }
    $port = $Rest[0]
    Assert-Port $port

    $extra = @()
    for ($i = 1; $i -lt $Rest.Count; $i++) {
        if ($Rest[$i] -eq '--triplet') { $extra += "--triplet=$($Rest[++$i])" }
        else { $extra += $Rest[$i] }
    }

    Write-Info "Building $port"
    Invoke-Vcpkg install $port "--overlay-ports=$Root/ports" @extra
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Invoke-Format {
    param([string[]] $Rest = @())
    if ($Rest.Count -eq 0 -or $Rest[0] -eq '--all') {
        Invoke-Vcpkg @VcpkgReg format-manifest --all
        Write-Ok 'all manifests formatted'
    } else {
        Assert-Port $Rest[0]
        Invoke-Vcpkg @VcpkgReg format-manifest "ports/$($Rest[0])/vcpkg.json"
        Write-Ok "ports/$($Rest[0])/vcpkg.json formatted"
    }
}

function Invoke-Help {
    Write-Host @"
${CB}registry.ps1${CN} - maintenance helper for the Alchemy vcpkg registry

  ${CB}list${CN}
      Every port with its version, port-version, and upstream repo.

  ${CB}verify${CN} [--fix]
      Check the registry is internally consistent: port layout, baseline
      coverage, orphaned version files, manifest formatting, and that the
      version database matches the committed ports. Without --fix nothing is
      written; the check needs a clean working tree to be meaningful.

  ${CB}outdated${CN} [port...]
      Compare each port against its upstream GitHub release or tag.

  ${CB}hash${CN} <url> | ${CB}hash${CN} <owner/repo> <ref>
      SHA512 of a source archive, in the form portfiles expect.

  ${CB}patches${CN} <port> [ref]
      Download the port's upstream source and test-apply its PATCHES with the
      same git flags vcpkg uses. Defaults to the port's current version.

  ${CB}bump${CN} <port> <version> [--ref R] [--sha512 H] [--keep-port-version] [--dry-run]
      Rewrite the port's version and SHA512 in place, resetting port-version.
      Downloads the archive to compute the hash unless --sha512 is given.
      Leaves the changes unstaged; does not commit.

  ${CB}add-version${CN} <port>|--all [--overwrite]
      Record the port's current git-tree in versions/ and versions/baseline.json.
      Run this after committing a port change.

  ${CB}build${CN} <port> [--triplet T] [vcpkg args...]
      Build the port from this registry via an overlay.

  ${CB}format${CN} [port|--all]
      Run vcpkg format-manifest.

Environment:
  VCPKG_ROOT   vcpkg checkout to use (or VCPKG for the executable itself)
  GITHUB_TOKEN used by 'outdated' when the gh CLI is not installed
  NO_COLOR     disable colored output

See README.md for the full update-a-port workflow.
"@
}

# --------------------------------------------------------------------- main --

try {
    switch ($Command) {
        'list'        { Invoke-List }
        'verify'      { Invoke-Verify $Args_ }
        'check'       { Invoke-Verify $Args_ }
        'outdated'    { Invoke-Outdated $Args_ }
        'hash'        { Invoke-Hash $Args_ }
        'patches'     { Invoke-Patches $Args_ }
        'bump'        { Invoke-Bump $Args_ }
        'add-version' { Invoke-AddVersion $Args_ }
        'build'       { Invoke-Build $Args_ }
        'install'     { Invoke-Build $Args_ }
        'format'      { Invoke-Format $Args_ }
        { $_ -in 'help', '-h', '--help' } { Invoke-Help }
        default {
            Write-Err "unknown command: $Command"
            Write-Host ''
            Invoke-Help
            Pop-Location
            exit 1
        }
    }
} finally {
    Remove-TempRoot
    Pop-Location
}
