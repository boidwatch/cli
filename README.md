# Boidwatch CLI

The public command-line client for [Boidwatch](https://boidwatch.com) — an autonomous web-evaluation engine that dispatches a flock of LLM-driven personas to explore a page and produces aggregate behavioral insights plus optional design-intent gap analysis.

`boidwatch` is a pure HTTPS client. Install it once, point it at hosted Boidwatch (or a self-hosted deployment), and drive runs from the terminal, CI, or an LLM agent harness. It never talks to a database — only the public API.

> Source for the CLI lives in Boidwatch's private monorepo; this repository hosts the published binaries, installer, and release notes.

## Install

```bash
# Homebrew (macOS / Linux)
brew install boidwatch/tap/boidwatch

# curl | sh (macOS / Linux). Pin a version with BOIDWATCH_VERSION=vX.Y.Z.
curl -fsSL https://boidwatch.com/install.sh | sh
```

Windows: download the `.zip` from the [latest release](https://github.com/boidwatch/cli/releases/latest) and put `boidwatch.exe` on your `PATH`.

## Authenticate

Authentication is API-key based — there is no browser/OAuth login flow in the CLI itself. **Create an API key in the web dashboard** (Settings → API keys), then either save it to a profile or export it:

```bash
# Save the key to a local profile (~/.boidwatch/credentials.json)
boidwatch auth login \
  --api-url https://api.boidwatch.com \
  --api-key fg_live_...

# Or, preferred for agents/CI — no `auth login` step needed:
export BOIDWATCH_API_KEY=fg_live_...
export BOIDWATCH_API_URL=https://api.boidwatch.com
```

## Quickstart

```bash
boidwatch version

# Preview cost without spending credits
boidwatch run create --dry-run \
  --url https://example.com/landing

# Kick off an exploration run and wait for the digest
boidwatch run create \
  --url https://example.com/landing \
  --design-intent "Drive non-technical buyers to the free trial" \
  --wait --format summary
```

`--format summary` returns a ~1 KB digest of aggregate insights, top friction points, and agent counts — small enough for an LLM to reason over without context bloat. Drop `--wait` to poll yourself with `boidwatch run status <run-id>`.

## Built for agents and CI

- Most commands accept `--format json`; a leading `--json` forces JSON output (including error envelopes) for any command.
- `boidwatch commands` prints a machine-readable manifest of every command, flag, env var, and exit code.
- `--quiet` / `-q` suppresses informational stderr.
- Stable exit codes: `0` success, `1` unexpected, `2` validation, `3` auth, `4` insufficient credits, `5` not found, `6` conflict, `7` timeout, `8` rate-limited.

## Command surface

| Command | Description |
|---|---|
| `boidwatch auth login \| status \| logout` | Manage CLI credential profiles |
| `boidwatch run create --url URL [flags]` | Create an exploration run |
| `boidwatch run status <run-id>` | Check run state / phase / progress |
| `boidwatch run results <run-id>` | Fetch results (JSON / summary / HTML) |
| `boidwatch run list [--limit N]` | List recent runs |
| `boidwatch run cancel <run-id>` | Cancel a queued / running run |
| `boidwatch billing status` | Show active workspace credits |
| `boidwatch billing top-up --amount N` | Open Stripe Checkout |
| `boidwatch personas ...` | List / inspect / create personas |
| `boidwatch site-profile ...` | Manage site profiles, skills, scenarios |
| `boidwatch commands` | JSON manifest of the full command surface |
| `boidwatch <command> --help` | Per-command help (flags + examples) |

See `boidwatch --help` for the complete, authoritative surface.

> **macOS Gatekeeper:** if you downloaded a tarball directly via a browser and it refuses to run, strip the quarantine attribute: `xattr -d com.apple.quarantine ./boidwatch`. Homebrew and the install script are not affected.

## Links

- Web dashboard: <https://app.boidwatch.com>
- Product site: <https://boidwatch.com>
- Releases: <https://github.com/boidwatch/cli/releases>
