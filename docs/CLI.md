# The `envhub` CLI

The same core as the app, in your shell — and they share one library: workspaces
you create in the CLI appear in the app's sidebar instantly.

## Install

```sh
brew install cs4alhaider/tap/envhub
```

Or build from source: `swift build -c release --package-path EnvHubCLI --product envhub`.

## Commands

```sh
# Add the current folder to EnvHub (it appears in the sidebar)
envhub add .
envhub add ~/code/my-app

# Open a folder in a project window WITHOUT adding it (a quick look)
envhub .
envhub ~/code/my-app

# Discover .env files, grouped by folder (‑‑deep to recurse)
envhub scan ~/Developer --deep

# List a project's files and variables (‑‑mask to hide values, ‑‑keys-only for keys)
envhub list ./my-app --mask

# Print one key's value (from a file, or searching a project folder)
envhub get DATABASE_URL --file ./my-app/.env
envhub get API_KEY --project ./my-app --mask

# Encrypt to .envenc (‑‑project for the whole folder; password prompted or from a file)
envhub export ./my-app/.env --out secrets.envenc
envhub export ./my-app --project --password-file ./pw.txt

# Decrypt a .envenc into a folder (‑‑force to overwrite)
envhub import secrets.envenc --into ./restored --force

# Workspaces — the same sidebar sections the app shows (shared store)
envhub workspace list
envhub workspace create Backend
envhub workspace move ./my-app Backend
envhub workspace sort Backend --by name

# Back up or inspect the shared data store
envhub store
cp "$(envhub store)" ~/envhub-backup.store
```

## The shared store

The app and CLI read and write one library in the `group.net.alhaider.EnvHub`
app-group container — `envhub store` prints the exact path. Set
`ENVHUB_STORE=<path>` to point either of them at a different store (useful for
testing or keeping separate setups).

## Safety defaults

- Output that contains values is **masked** wherever `--mask` applies; prefer it
  in scripts and share-able terminal sessions.
- `export` prompts for the password interactively unless `--password-file` is
  given; lost passwords are unrecoverable by design.

## For AI agents

[`skills/envhub-cli/`](../skills/envhub-cli/SKILL.md) is a ready-made agent skill
that teaches coding agents to use the CLI safely (masking rules, password
handling, workspace semantics). Drop the folder into your agent's skills
directory — e.g. `.claude/skills/envhub-cli/` for Claude Code.
