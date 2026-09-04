# Alchemy vcpkg registry

A [vcpkg registry](https://learn.microsoft.com/vcpkg/concepts/registries) holding
the ports the Alchemy viewer needs that upstream vcpkg does not carry, plus
overlays of upstream ports that need Alchemy-specific patches or pinning.

```
ports/<name>/vcpkg.json        the port manifest: version, dependencies, features
ports/<name>/portfile.cmake    how to fetch, patch, configure and install it
ports/<name>/*.patch|*.diff    patches applied to the upstream source
versions/<letter>-/<name>.json every published version, keyed by git tree
versions/baseline.json         the version each port resolves to by default
scripts/registry.sh|.ps1       maintenance helper (see below)
```

---

## Using the registry

Add it to your project's `vcpkg-configuration.json` and pin `baseline` to a
commit of *this* repository:

```json
{
  "default-registry": {
    "kind": "git",
    "repository": "https://github.com/microsoft/vcpkg",
    "baseline": "<upstream vcpkg commit>"
  },
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/AlchemyViewer/alchemy-registry",
      "baseline": "<commit of this repo>",
      "packages": [ "faudio", "sdl3", "tracy", "webrtc" ]
    }
  ]
}
```

Every port this registry should serve has to be listed in `packages` — anything
omitted resolves from the default registry instead. `scripts/registry.sh list`
prints the full set of names.

The `baseline` commit decides which version of each port you get: vcpkg reads
`versions/baseline.json` at that commit. Bumping the baseline is how consumers
pick up port updates, so the baseline is only meaningful once a change has been
committed *and* recorded in the version database (see below).

To pin a single port to a version other than the baseline, add an
`overrides` entry in your `vcpkg.json`:

```json
"overrides": [
  { "name": "faudio", "version": "26.9" }
]
```

---

## Maintaining the registry

### The helper script

`scripts/registry.sh` (bash) and `scripts/registry.ps1` (PowerShell 7+) are the
same tool; use whichever matches your shell. Both are run from anywhere in the
repo and locate vcpkg via `$VCPKG_ROOT`, `$VCPKG`, or `PATH`.

| Command | What it does |
| --- | --- |
| `list` | Every port with its version, port-version, and upstream repo. |
| `verify [--fix]` | Full consistency check. Run before pushing. |
| `outdated [port...]` | Compare each port against its upstream GitHub release or tag. |
| `hash <url>` / `hash <owner/repo> <ref>` | SHA512 of a source archive. |
| `patches <port> [ref]` | Test-apply the port's patches to upstream source. |
| `bump <port> <version>` | Rewrite version + SHA512 in place. |
| `add-version <port>` | Record the port's git tree in `versions/`. |
| `build <port> [--triplet T]` | Build the port from this registry. |
| `format [port\|--all]` | Run `vcpkg format-manifest`. |

`verify` is the one to reach for by reflex — it catches the mistakes that are
invisible in review and only show up as a consumer's build failure. Note that it
needs a clean working tree: it checks manifest formatting and the version
database by running vcpkg's own rewriting tools and then looking for a diff, so
uncommitted changes would be indistinguishable from its findings. It restores
anything it rewrote unless you pass `--fix`.

### Updating a port to a new upstream version

```bash
scripts/registry.sh outdated faudio           # is there anything newer?
scripts/registry.sh bump faudio 26.9 --ref 26.09
scripts/registry.sh patches faudio 26.09      # do the patches still apply?
scripts/registry.sh build faudio              # does it still build?
git add ports/faudio && git commit
scripts/registry.sh add-version faudio
git add versions && git commit
```

The order matters. `bump` edits `ports/<name>/` and stops there; it never
commits. `add-version` records the *git tree hash* of the port directory, so the
port has to be committed first — otherwise the hash it writes into
`versions/f-/faudio.json` names a tree that exists in nobody's history and the
registry is unusable for consumers.

`bump` refuses rather than guesses when it cannot be sure:

- **`REF is computed in the portfile`** — the portfile derives its ref rather
  than using `${VERSION}` directly (FAudio maps the manifest version `26.9` to
  the calendar tag `26.09`). Pass `--ref` with the real tag.
- **`portfile has N SHA512 entries`** / **`not a literal hash`** — the port
  fetches a different archive per platform (`cef-bin`) or through a variable.
  Update each hash by hand, then use `add-version` as usual.

For a port whose upstream version is unchanged but whose *port files* changed
(a new patch, a build fix), do not touch `version` — add or increment
`"port-version"` instead, then commit and `add-version`.

### Patches

Patches live beside the portfile and are listed under `PATCHES` in
`vcpkg_from_github`. vcpkg applies them with:

```
git apply --ignore-whitespace --whitespace=nowarn <patch>
```

which means **`-p1`**: every path in the diff has exactly one leading component
stripped. Generate patches as `git diff` from inside a clone of the upstream
source so they carry `a/`…`b/` prefixes:

```bash
cd /path/to/upstream-checkout
# make the edit, then:
git diff > /path/to/registry/ports/<name>/my-fix.patch
```

A diff produced by `diff -u` between two absolute paths will *not* apply — the
`+++` line keeps the build-tree path, `-p1` strips only the first component, and
`git apply` looks for a file that does not exist. This is silent until someone
builds the port, which is what `patches` exists to catch:

```bash
scripts/registry.sh patches faudio 26.09
```

It downloads the upstream tarball, makes a throwaway git repo, and applies each
patch in the order the portfile lists them, with vcpkg's exact flags. Run it on
every version bump — patches that no longer apply are the usual reason an
upgrade breaks. Entries pointing into `${SOURCE_PATH}` are skipped, since those
target a nested source tree rather than the port directory.

### Adding a new port

1. Create `ports/<name>/vcpkg.json` and `ports/<name>/portfile.cmake`. Copying a
   similar existing port is the fastest start.
2. `scripts/registry.sh hash <owner/repo> <tag>` for the `SHA512`.
3. `scripts/registry.sh build <name>` until it installs cleanly.
4. `scripts/registry.sh format <name>`.
5. Commit `ports/<name>/`, then `scripts/registry.sh add-version <name>` and
   commit `versions/`.

New ports also need adding to the consumer's `packages` list — a port that only
exists here is invisible to a project that has not listed it.

### Version database notes

`versions/<letter>-/<name>.json` is append-only history: one entry per published
`version` + `port-version`, each naming the git tree of `ports/<name>/` at the
commit that published it. `versions/baseline.json` names the current version of
every port. Both are maintained by `add-version`; do not hand-edit them.

Two vcpkg behaviours are worth knowing, because they make mistakes here quiet:

- `vcpkg x-add-version --all` reports a port whose files changed without a
  version bump as an `error:` on stdout **but still exits 0**. `verify` reads the
  output rather than the exit status for this reason. The single-port form does
  set a failing status.
- `x-add-version` hashes the *working tree*, not `HEAD`. Running it with
  uncommitted changes records a tree hash that no commit contains. Both scripts
  warn when the port directory is dirty.

If you genuinely need to re-point an already-published version at a new tree —
which rewrites history for anyone who pinned it — `add-version <port>
--overwrite` is the escape hatch. Prefer a `port-version` bump.
