# GNU Stow and Skills CLI coexistence

Research date: 2026-08-13

Skills CLI source reviewed at commit [`c6f69c6`](https://github.com/vercel-labs/skills/tree/c6f69c631292444cc541ac6d91e2226b0ff247da), package version 1.5.22. GNU Stow documentation reviewed for version 2.4.1, which is also the locally installed version.

## Recommendation

Use GNU Stow only to expose the repository's `agents/skills` directory as the canonical global directory, and rely on **tree folding**:

```text
/home/adel/dotfiles/agents/skills  <-- repository directory
                ^
                |
~/.agents/skills -----------------+  (directory symlink created by Stow)
```

Treat `agents` as a Stow package and target `~/.agents`, rather than targeting `$HOME`:

```sh
stow --dir=/home/adel/dotfiles --target="$HOME/.agents" agents
```

The package's installation image is `skills/...`, so an empty/non-conflicting target lets Stow fold the entire `skills` subtree into one symlink. Stow explicitly prefers a single subtree symlink when it can, and descends into an existing real target directory only when folding is unavailable.[GNU Stow manual: Installing Packages and Tree folding](https://www.gnu.org/software/stow/manual/stow.html#Tree-folding)

This gives each tool one clear role:

- Git owns history and transport for `agents/skills`.
- Stow owns the `~/.agents/skills` directory symlink.
- Skills CLI owns the ordinary skill directories below that path and may replace them during install/update.
- Agent-specific locations such as `~/.claude/skills/<name>` contain links to the canonical directory.

This works because a program opening `~/.agents/skills/<name>` follows the folded parent directory into the repository. Skills CLI deliberately installs a skill by removing and recreating its canonical directory, then copying the source into it; it also resolves symlinked parent directories when constructing agent links.[Skills CLI installer, canonical directory and replacement](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/installer.ts#L104-L115) [Skills CLI installer, symlinked-parent handling](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/installer.ts#L150-L175) [Skills CLI installer, local/disk install](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/installer.ts#L313-L360)

Do **not** use `stow --adopt` as the normal synchronization mechanism. Do the one-time import explicitly, keep a backup, then create the folded link.

## Why `--adopt` is not appropriate

`--adopt` is not a general "import everything from the target" operation. It changes conflict handling while Stow walks the package's existing installation image: when a package path collides with an unowned plain target file, Stow moves the target file into the corresponding package path and then links it. The manual warns that this option is specifically intended to alter the Stow directory.[GNU Stow manual: `--adopt`](https://www.gnu.org/software/stow/manual/stow.html#Invoking-Stow)

Consequences here:

- It can replace the repository copy of every matching skill file with the target copy. That may be useful for a carefully reviewed, one-time conflict import, but it is too broad for routine sync.
- A target-only skill is not necessarily discovered: Stow's operation is driven by paths in the package installation image, not by an inventory of arbitrary target-only content.
- It does not establish which copy should win, does not preserve both copies, and is especially unsafe in a dirty worktree.
- `--simulate --verbose` can preview planned Stow operations, but adoption should still follow an explicit backup and diff.[GNU Stow manual: `--simulate` and `--verbose`](https://www.gnu.org/software/stow/manual/stow.html#Invoking-Stow)

Stow otherwise has useful safety properties: it defines ownership as target links pointing into a package in the current Stow directory, never deletes target objects it does not own, and performs conflict analysis before filesystem changes.[GNU Stow manual: Ownership](https://www.gnu.org/software/stow/manual/stow.html#Ownership) [GNU Stow manual: Deferred Operation](https://www.gnu.org/software/stow/manual/stow.html#Deferred-Operation)

## Ignore files

Stow ignore rules are independent of `.gitignore`. A top-level package may contain `.stow-local-ignore`; otherwise Stow uses `~/.stow-global-ignore`, and only if neither exists does it use the built-in defaults. A package-local file therefore **replaces**, rather than extends, the global/built-in list. `.stow-local-ignore` itself is always ignored.[GNU Stow manual: Types and Syntax of Ignore Lists](https://www.gnu.org/software/stow/manual/stow.html#Types-And-Syntax-Of-Ignore-Lists)

For the recommended `agents` package:

- Do not ignore `skills` or its children; doing so prevents restoration.
- No ignore file is required merely because the repository has a root `.gitignore`; the Stow package root is `agents`, not the repository root.
- If `agents/.stow-local-ignore` is later added, copy any desired built-in patterns into it because the defaults will no longer apply.
- Ignore rules only exclude paths Stow sees in the package. They do not import, hide, or take ownership of target-only skill directories.

## Folding requirements and failure mode

The desired invariant is:

```sh
test -L "$HOME/.agents/skills"
test "$(readlink -f "$HOME/.agents/skills")" = "/home/adel/dotfiles/agents/skills"
```

If `~/.agents/skills` is a real directory, Stow descends into it and creates finer-grained links where possible. If an additional Stow package needs the same subtree, Stow can unfold an existing folded link into a real directory populated by per-entry links.[GNU Stow manual: Tree unfolding](https://www.gnu.org/software/stow/manual/stow.html#Tree-unfolding-1)

Either state breaks automatic capture of new skills: Skills CLI can create a new ordinary target-only directory that is not represented in the repository. Therefore:

- Only the `agents` Stow package should contribute to `~/.agents/skills`.
- Do not use `--no-folding`; that option explicitly creates real target directories with child links instead of folding.[GNU Stow manual: `--no-folding`](https://www.gnu.org/software/stow/manual/stow.html#Invoking-Stow)
- Verify the directory symlink after every Stow layout change.
- Keep `~/.agents` itself as a real directory so unrelated runtime state such as `packref/` remains local.

## Skills CLI behavior

### Install layout

Skills CLI documents `~/.agents/skills` as its canonical global copy and recommends symlinking agent directories to that copy; `--copy` instead creates independent agent copies.[Skills CLI README: Installation Scope and Methods](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/README.md#installation-scope)

The implementation computes global canonical storage as `~/.agents/skills`. In symlink mode it removes/recreates `<canonical>/<skill>`, copies all source files there, and links agent-specific destinations to it. Existing ordinary agent destinations may be recursively removed when replaced.[Skills CLI installer](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/installer.ts#L104-L115) [Skills CLI install algorithm](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/installer.ts#L265-L375)

The implementation has lexical source/destination overlap guards, but those checks do not resolve a folded parent symlink.[Skills CLI overlap check and guards](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/installer.ts#L48-L50) [Skills CLI source guards](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/installer.ts#L305-L326) Consequently this command from the in-progress `dot` change is unsafe once `~/.agents/skills` is folded to the source repository:

```sh
npx --yes skills add /home/adel/dotfiles/agents/skills -g \
  -a opencode codex claude-code -s '*' -y
```

For a skill whose source is `/home/adel/dotfiles/agents/skills/<name>`, the canonical destination string is `$HOME/.agents/skills/<name>`. They look different lexically, so Skills CLI may remove the destination through the parent symlink, which removes its own source, then fail while copying. Do not combine local-source replay with the folded layout.

Remote installs and updates do not have that self-overlap: their source is a downloaded/cloned temporary tree, so replacing the canonical directory writes the new snapshot into the repository through the folded parent.

### Lockfiles

Skills CLI has two different lockfiles:

- The **global state file** is `$XDG_STATE_HOME/skills/.skill-lock.json` when `XDG_STATE_HOME` is set, otherwise `~/.agents/.skill-lock.json`. It records remote source, source type/URL/ref/path, a folder hash, timestamps, dismissed prompts, and last-selected agents.[Skills CLI global lock implementation](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/skill-lock.ts#L8-L55) [Global lock location](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/skill-lock.ts#L57-L68)
- The **project lock** is `skills-lock.json`. Its source calls it timestamp-free, deterministic, and "meant to be checked into version control." It stores source metadata and content hashes.[Skills CLI project lock implementation](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/local-lock.ts#L8-L60) [Deterministic project-lock writing](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/local-lock.ts#L101-L126)

Important limits:

- A global install is added to the global lock only when the source normalizes to a remote source. A local-path global install does not satisfy that condition, so replaying `agents/skills` does not create update provenance.[Skills CLI global lock write condition](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/add.ts#L1807-L1813) [Skills CLI global lock recording](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/add.ts#L1849-L1893)
- The global file is update state, not a frozen dependency lock: `skills update -g` compares the recorded folder hash with the current upstream folder, then invokes `skills add ... -g -y` to install the latest contents at the recorded branch/tag ref.[Skills CLI global update check](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/update.ts#L488-L635) [Skills CLI global update install](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/update.ts#L672-L720)
- Local-path entries cannot be updated automatically; project update also skips local and `node_modules` sources.[Skills CLI update skip behavior](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/update.ts#L178-L198) [Project update source filtering](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/update.ts#L239-L252)
- `experimental_install` restores only a **project** `skills-lock.json` into project `.agents/skills`; it is not a global-lock restore command.[Skills CLI project-lock installer](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/install.ts#L9-L32) [Skills CLI project restore loop](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/src/install.ts#L62-L82)

Do not treat the global lock as the repository's portable manifest without accepting churn and machine state: it contains timestamps, dismissed prompts, and agent-selection history. The source explicitly marks only the project lock as intended for version control. If cross-machine upstream updates are required, keep a small checked-in provenance manifest of source/ref/skill names alongside the vendored snapshots. Stow restores the snapshots; the manifest lets any machine deliberately reinstall/update from upstream. This is a repository convention, not currently a first-class global restore feature in Skills CLI.

## Exact sync flow

### One-time migration on the authoritative computer

1. Stop agent/Skills CLI processes that may write skills, and inspect the dirty worktree. Do not start from `--adopt`.
2. Back up the live canonical tree.

   ```sh
   backup="$HOME/.agents/skills.pre-stow.$(date +%Y%m%d_%H%M%S)"
   cp -a "$HOME/.agents/skills" "$backup"
   ```

3. Preview the import. The trailing slashes are significant.

   ```sh
   rsync -ani "$HOME/.agents/skills/" /home/adel/dotfiles/agents/skills/
   ```

4. Review every changed and target-only skill, then import the intended live versions without deleting repository-only skills.

   ```sh
   rsync -a "$HOME/.agents/skills/" /home/adel/dotfiles/agents/skills/
   git -C /home/adel/dotfiles diff -- agents/skills
   git -C /home/adel/dotfiles status --short
   ```

5. Move the live directory aside rather than deleting it, preview Stow, then stow.

   ```sh
   mv "$HOME/.agents/skills" "$HOME/.agents/skills.before-fold"
   stow --simulate --verbose=2 --dir=/home/adel/dotfiles \
     --target="$HOME/.agents" agents
   stow --dir=/home/adel/dotfiles --target="$HOME/.agents" agents
   test -L "$HOME/.agents/skills"
   test "$(readlink -f "$HOME/.agents/skills")" = "/home/adel/dotfiles/agents/skills"
   ```

6. Compare against both backups before removing either. Commit only after review; Stow itself should not be allowed to decide which pre-existing content wins.

### Add a skill on any configured computer

Install from its remote source, not from the vendored local directory:

```sh
npx skills add owner/repo -g -a opencode codex claude-code \
  -s skill-name -y
```

Then verify that the canonical child is an ordinary directory reached through the folded parent and that Git sees it:

```sh
test -L "$HOME/.agents/skills"
test -d "$HOME/.agents/skills/skill-name"
test ! -L "$HOME/.agents/skills/skill-name"
git -C /home/adel/dotfiles status --short -- agents/skills
git -C /home/adel/dotfiles diff -- agents/skills/skill-name
```

Review and commit the new vendored directory normally. The global lock on that computer retains the remote provenance for updates, but another computer receives the vendored snapshot through Git/Stow even without that lock entry.

### Restore on another computer

1. Pull/clone the dotfiles repository.
2. If `~/.agents/skills` already exists as a real directory, back it up and reconcile it exactly as in the one-time migration. Do not adopt it.
3. Apply and verify the `agents` package:

   ```sh
   mkdir -p "$HOME/.agents"
   stow --dir=/home/adel/dotfiles --target="$HOME/.agents" agents
   test -L "$HOME/.agents/skills"
   ```

4. OpenCode and Codex discover the universal `~/.agents/skills` store directly. Create only missing Claude Code links, and do not overwrite ordinary local directories silently:

   ```sh
   destination="$HOME/.claude/skills"
   mkdir -p "$destination"
   for skill in "$HOME/.agents/skills"/*
   do
     name=${skill##*/}
     if [ ! -e "$destination/$name" ] && [ ! -L "$destination/$name" ]; then
       ln -s "$skill" "$destination/$name"
     elif [ -L "$destination/$name" ]; then
       test "$(readlink -f "$destination/$name")" = "$(readlink -f "$skill")" || \
         printf 'conflicting link: %s\n' "$destination/$name" >&2
     else
       printf 'conflicting directory: %s\n' "$destination/$name" >&2
     fi
   done
   ```

This restores the committed snapshot without asking Skills CLI to copy the local source onto itself. A future repository helper can make this link step idempotent, but it should retain the conflict checks.

### Update

On a computer that has the remote entry in its global lock:

```sh
npx skills update -g skill-name
git -C /home/adel/dotfiles diff -- agents/skills/skill-name
```

The update replaces the canonical child, which writes the updated snapshot into the repository through the folded parent. Review and commit it. On a computer without global provenance, rerun the explicit remote `skills add` command from the checked-in provenance manifest; `skills update -g` cannot infer a source merely from an installed directory.

## Alternatives rejected

### Stow `--adopt` for every sync

Rejected because adoption is conflict replacement, not target discovery or bidirectional synchronization. It can overwrite tracked package content and does not give a safe merge boundary.

### Per-skill Stow links or `--no-folding`

Rejected because a newly installed ordinary directory in the real target is then outside the package and will not automatically appear in Git. A single folded `skills` link is the property that captures additions.

### Run `skills add agents/skills -g` after Stow

Rejected with the folded layout because the local source and canonical destination resolve to the same files through different lexical paths. Current Skills CLI guards do not resolve that equivalence before cleaning the destination.

### Skills CLI `--copy`

Rejected as the primary model because it creates independent copies in each agent directory, explicitly abandoning the single canonical source and allowing drift.[Skills CLI README: Installation Methods](https://github.com/vercel-labs/skills/blob/c6f69c631292444cc541ac6d91e2226b0ff247da/README.md#installation-methods)

### Track only the global `.skill-lock.json`

Rejected as a restore strategy. It is machine-oriented update state and Skills CLI has no global restore-from-lock command. It is still useful locally for `skills update -g`, but the vendored directory is what makes restoration deterministic.

### Use project `skills-lock.json` as-is

Rejected for this layout. It is designed for project `.agents/skills`, while this repository intentionally vendors global snapshots at `agents/skills`; its restore command is project-scoped. It could inspire a separate provenance manifest, but does not directly restore this global Stow layout.

## Pre-implementation observations

Before the folded layout was implemented, the worktree and live installation had these conditions:

- Skills are staged as moves from `home/.agents/skills/...` to `agents/skills/...`.
- `home/.agents/.skill-lock.json` is deleted.
- `dot` and `README.md` temporarily ran `skills add "$SKILLS_DIR" -g` after Stow.
- The current live canonical directory has 42 skills, while `agents/skills` has 40. The live-only directories observed were `uv-package-manager` and `vercel-react-best-practices`.
- Current live canonical skill directories are ordinary directories; Claude, Codex, and OpenCode currently have per-skill symlinks for shared skills.

These observations explain why the one-time import preceded folding and why the two live-only skills were reviewed rather than overwritten. The final implementation removed the unsafe local-source replay, imported both live-only skills, and made `~/.agents/skills` a folded link to `agents/skills`.

## Caveats

- Skills CLI replaces skill directories recursively. A failed install after cleanup can leave a tracked skill temporarily removed or partial; Git and the pre-migration backup are the recovery mechanisms.
- A folded parent means any process writing below `~/.agents/skills` writes into the dotfiles worktree. This is intentional, but concurrent updates can race and should be serialized.
- Never run Stow and Skills CLI mutation concurrently.
- Skill names collide globally because the global lock and canonical directory are keyed by skill name; two sources publishing the same name cannot coexist independently in this model.
- Agent-specific directories may contain private, system, or agent-only skills. The restore loop links only missing names and reports conflicts instead of replacing them.
- Absolute links created by the restore loop are local artifacts, not committed files. Skills CLI normally uses relative links, but both resolve to the same canonical directory.
- If `XDG_STATE_HOME` is set, the global lock is not under `~/.agents`; account for that when diagnosing why updates are not tracked.
- The source findings are version-specific. Recheck the installer overlap guards and lock semantics before upgrading Skills CLI if this layout becomes automated.
