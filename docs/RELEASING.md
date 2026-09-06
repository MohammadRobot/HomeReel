# Release and GitHub upload guide

## Distribution model

Media Server is distributed as a versioned Docker Compose source package.
Users download and extract it, configure `.env`, and launch the containers.
There is no standalone executable, desktop installer, bundled media, or bundled
container image. The user manual is Markdown so GitHub renders it directly.

The initial version is **1.0.0-rc.1**, a release candidate. It has configuration
and package validation, but still needs a fresh-host installation test before
being promoted to a stable release. The project uses the MIT license; see
[third-party notices](../THIRD_PARTY.md) for upstream components.

## Upload the repository

Create an empty GitHub repository in your account. Do not initialize it with a
second README or license. From this local project directory, replace the URL
below with the repository URL GitHub gives you:

```bash
git remote add origin https://github.com/YOUR_ACCOUNT/YOUR_REPOSITORY.git
git push -u origin HEAD
```

If `origin` already exists, inspect `git remote -v` and use the correct remote.
The current local branch is `master`; using `HEAD` avoids requiring a rename.
Upload the tracked repository through Git, not the whole project folder through
a browser: the working folder contains private runtime files. Never force-add
ignored files. GitHub Actions validates scripts and Compose on pushes and PRs.

## Build release assets

Update `VERSION`, the changelog, README version, and manual version together.
Commit the intended release first. From a clean Git checkout, run:

```bash
bash scripts/package-release.sh
```

The script packages an explicit allowlist of files from `HEAD`, generates
`.tar.gz` and `.zip` archives, and creates a `.sha256` checksum file in `dist/`.
It refuses to overwrite existing assets or package uncommitted changes.
Existing installation state and local TV builds are excluded. Keep `dist/`
out of Git; attach its contents to the GitHub release instead.

Check the package before publishing:

```bash
cd dist
sha256sum -c media-server-1.0.0-rc.1.sha256
tar -tzf media-server-1.0.0-rc.1.tar.gz
cd ..
```

## Create the GitHub release

1. Wait for the repository's validation workflow to pass.
2. In GitHub, open Releases → Draft a new release.
3. Create tag `v1.0.0-rc.1` targeting the exact commit used to build the assets.
4. Use title `Media Server 1.0.0-rc.1` and copy the relevant changelog section
   into the release description. Link to `docs/USER_MANUAL.md` in the repository.
5. Attach the ZIP, tar.gz, and SHA-256 files from `dist/`.
6. Mark this candidate as a pre-release. Review the draft, then publish it.

See [GitHub's release instructions](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).
No release is published automatically by this project.

## Stable release acceptance

Before changing to `1.0.0`, install the package on a fresh Ubuntu host, complete
application setup, verify permissions and library imports, test a real playback
and GPU transcode, and exercise updates and backup restoration. Verify CPU-only
manual operation if you advertise it. Record actual results in the release notes.
Check current upstream advisories and image availability before publishing.

An upgrade must preserve `.env`, application state, and media. If database
migrations occur, rollback requires the matching pre-upgrade state backup.
