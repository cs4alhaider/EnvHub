---
name: envhub-cli
description: Manage .env files across local projects with the envhub CLI — discover env files, read keys (masked by default), export/import password-encrypted .envenc archives, and organize EnvHub workspaces. Use when a task involves finding, reading, auditing, or moving environment variables across projects on this machine, or when the user mentions EnvHub, .envenc, or their EnvHub workspaces.
---

# envhub CLI

`envhub` is the command-line companion to the EnvHub macOS app. Both share one data
store, so workspaces you create or reorganize here appear in the app's sidebar
immediately (and vice versa).

Check availability with `envhub --help`; build from source with
`swift build -c release --product envhub` in the EnvHub repo if it isn't installed.

## Safety rules (read first)

1. **Values are secrets.** Default to `--mask` whenever output might be shown to a
   human, logged, committed, or pasted into an issue/PR. Only read an unmasked value
   (`envhub get KEY --file …`) when the task genuinely needs the value itself — e.g.
   injecting it into a runtime environment — and never echo it back in your reply.
2. **Never write secret values into files that get committed** (docs, tests,
   fixtures). For shareable templates, prefer `.env.example` files (keys, no values).
3. For export/import, pass the password via `--password-file`: create the file with
   `umask 077`, and delete it immediately afterwards. Don't put passwords in argv.
4. Read-only by default: `scan`, `list`, `get`, and `workspace list` never modify
   anything. `export` writes one archive; `import` writes env files (refuses to
   overwrite without `--force`); `workspace` subcommands modify only EnvHub's own
   metadata store, never files on disk.

## Add or open a folder in the app

```sh
envhub add .             # add the current folder to EnvHub (it appears in the sidebar)
envhub add ~/code/app    # any path; works even if the folder has no .env files yet

envhub .                 # open the folder in a project window WITHOUT adding it
envhub open ~/code/app   # explicit form of the same thing (a bare path = `open`)
```

- `envhub add <path>` **persists** the project — it shows up in the app's sidebar and
  the shared store.
- `envhub <path>` / `envhub open <path>` opens a one-off project window for a quick
  look and does **not** add it. (If the folder already is a project, it re-uses that
  project's window.)

Either way the app comes to the front; if the folder has no env files, the window's
detail view offers a create-a-file flow where you pick the type.

## The data store

```sh
envhub store             # print the path to the shared SwiftData store (db)
envhub store --reveal    # …and reveal it in Finder
cp "$(envhub store)" ~/envhub-backup.store   # back it up
```

The app and CLI share this one file. Copy it to back up your projects/workspaces
(the `.env` files themselves are never inside it — they stay on disk).

## Discover env files

```sh
envhub scan ~/Developer --deep     # recurse; groups results by folder
envhub scan                        # current directory, shallow
```

Deep scans skip `node_modules`, `.git`, `~/Library`-style cache trees, etc.

## Read variables

```sh
envhub list ./my-app --mask        # every env file + variables, values masked
envhub list ./my-app --keys-only   # just the keys (safe to show)
envhub get DATABASE_URL --project ./my-app --mask
envhub get DATABASE_URL --file ./my-app/.env      # unmasked: handle with care
```

`get` prints the first match and exits 0; a missing key exits non-zero with
`key not found: …` on stderr.

## Encrypted export / import (.envenc)

```sh
(umask 077; printf '%s' "$PASSWORD" > /tmp/pw)    # never pass passwords in argv
envhub export ./my-app --project --out my-app.envenc --password-file /tmp/pw
envhub import my-app.envenc --into ./restored --force --password-file /tmp/pw
rm /tmp/pw
```

`.envenc` is AES-256-GCM with an scrypt-derived key; a wrong password fails cleanly
("Wrong password, or the file has been tampered with.").

## Workspaces (shared with the app's sidebar)

```sh
envhub workspace list                      # sections + their projects (📌 = pinned)
envhub workspace create Backend
envhub workspace move ./my-app Backend     # by path, or unique project name
envhub workspace move my-app none          # "none"/"others" = ungroup
envhub workspace sort Backend --by name    # name | path | date (newest first)
envhub workspace rename Backend Services
envhub workspace delete Services           # projects move back to Others
```

Projects are identified by canonical path (symlinks resolved, trailing slashes
ignored). `workspace` commands only edit EnvHub metadata — they cannot touch or
delete real files.

## The shared store

Default: `~/Library/Application Support/EnvHub/EnvHub.store`. Set
`ENVHUB_STORE=/path/to/store` to operate on an isolated store (useful for tests or
scripted experiments without touching the user's real sidebar).

## Recipes

- **Audit which projects define a key:** `envhub workspace list` for the project
  inventory, then loop `envhub get KEY --project <path> --mask` and report only
  presence/absence.
- **Make a committed template from a real file:** read keys with
  `envhub list <project> --keys-only`, then write a `.env.example` with empty values.
- **Move secrets between machines:** `export --project` on one side, transfer the
  `.envenc`, `import --into` on the other; the password travels out-of-band.
