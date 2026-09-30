# Boidwatch UX Check — GitHub Action

Run a Boidwatch persona-flock exploration against any URL from CI — typically a
Vercel/Netlify preview deploy — and get the findings back as a sticky PR
comment with a shareable report link. Optionally gate the job on coarse
assertions.

> **Publishing note:** this directory is authored in the Boidwatch monorepo but
> the public CLI ships from the separate [`boidwatch/cli`](https://github.com/boidwatch/cli)
> repo via GoReleaser. This `action/` directory is copied/published from that
> repo (so it is referenced as `boidwatch/cli/action@v1` or promoted to a
> dedicated `boidwatch/action` repo for Marketplace listing). Keep this copy as
> the source of truth and sync outward.

## Quickstart: check every preview deploy

```yaml
name: UX check
on:
  pull_request:

permissions:
  contents: read
  pull-requests: write   # needed for the sticky PR comment
  deployments: read      # if you read the preview URL from a deployment

jobs:
  boidwatch:
    runs-on: ubuntu-latest
    steps:
      # However you get your preview URL — Vercel/Netlify bots expose it as a
      # deployment status, or your deploy step outputs it directly.
      - name: Wait for preview deploy
        id: preview
        uses: patrickedqvist/wait-for-vercel-preview@v1.3.2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          max_timeout: 300

      - name: Boidwatch UX check
        uses: boidwatch/cli/action@v1
        with:
          url: ${{ steps.preview.outputs.url }}
          api-key: ${{ secrets.BOIDWATCH_API_KEY }}
          design-intent: 'Sign up for the newsletter'
```

That's it: the action downloads the `boidwatch` CLI release archive for the
runner (`boidwatch_<version>_<linux|darwin>_<x86_64|arm64>.tar.gz`), checks
it against the release's `checksums.txt` (a mismatch fails the step), runs
`boidwatch --json run create --url <url> --quick --wait --wait-timeout 10m`
(~5 credits), and posts/updates one sticky comment on the PR with the top
gaps, agent stats, and a public link to the full HTML report.

The action reads the CLI's compact results view (`schema_version` 1):
`gap_analysis.identified_gaps` (severity-ranked; the first three are the top
gaps), `metadata.valid_agents`, `surfaces.frustration_exits`,
`entry_block.message` and `summary.gap_analysis_status`. It warns when the CLI
prints a different `schema_version`.

### When a run does not pass

The CLI exits 0 for a completed run whose gap analysis failed. The action does
not treat that as a pass. `passed` is `"false"` when any of these
hold:

- The CLI exited non-zero. Exit 9 means a check failed: an assert-* input in
  gate mode, or, in any mode, no persona got past the entry URL.
- No persona got past the entry URL. The target is behind auth, or its WAF
  served an anti-bot challenge. The `entry-block` output carries the reason,
  and the PR comment shows it with the top-gaps row reading "Not evaluated".
- `design-intent` was set but gap analysis failed. `gap-analysis-status` is
  `failed`, and the PR comment says so.

Both conditions also emit a `::warning::` annotation. In `comment` mode the
job still succeeds. In `gate` mode the job fails and the error names the
cause.

### Gate mode

Once you trust the signal, gate merges on coarse absolutes:

```yaml
      - name: Boidwatch UX gate
        uses: boidwatch/cli/action@v1
        with:
          url: ${{ steps.preview.outputs.url }}
          api-key: ${{ secrets.BOIDWATCH_API_KEY }}
          design-intent: 'Complete checkout'
          mode: gate
          assert-max-high-gaps: 0
          assert-min-valid-agents: 3
```

## Flakiness stance (read this before gating)

LLM-driven exploration is stochastic: individual findings vary run to run.

- **Start in `comment` mode.** Findings never fail the job — only auth,
  credit, and infrastructure errors do. Watch a few PRs' worth of comments to
  learn what "normal" looks like for your app.
- **Gate only on coarse absolutes.** `assert-max-high-gaps: 0` ("no
  high-severity gaps") and `assert-min-valid-agents: N` ("the flock could
  actually use the page") are stable signals. Do not build gates around exact
  gap wording, counts of low/medium findings, or affect scores.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `url` | yes | — | Page URL to explore (must be publicly reachable — private/loopback URLs are rejected). |
| `api-key` | yes | — | Boidwatch API key. Always pass from `secrets`. |
| `design-intent` | no | `''` | Design intent driving gap analysis, e.g. `"Sign up for the newsletter"`. Without it you still get friction/perception surfaces, but no gap analysis. |
| `mode` | no | `comment` | `comment`: findings never fail the job. `gate`: assertions are passed to the CLI, and the job fails when `passed` is not `"true"`. |
| `agents` | no | `''` | Persona count. Empty keeps the `--quick` preset of 5 (~5 credits). |
| `max-steps` | no | `''` | Maximum steps per persona. Empty keeps the `--quick` preset of 15. |
| `wait-timeout` | no | `10m` | Max time to wait for the run (Go duration syntax). The run keeps going on the server after a timeout. |
| `assert-max-high-gaps` | no | `''` | Gate mode: fail when more than N high-severity gaps are found. |
| `assert-min-valid-agents` | no | `''` | Gate mode: fail when fewer than N agent sessions complete validly. |
| `share-report` | no | `true` | Mint a public 30-day share link for the HTML report and include it in the PR comment. |
| `github-token` | no | `github.token` | Token for the PR comment and release downloads. |
| `version` | no | `latest` | Pin a specific `boidwatch/cli` release tag (e.g. `v0.4.2`). |
| `api-url` | no | `https://app.boidwatch.com` | Boidwatch API base URL. |

## Outputs

| Output | Description |
| --- | --- |
| `run-id` | The Boidwatch run ID (`run_...`). |
| `report-url` | Public share-link URL for the HTML report (empty when `share-report: false` or minting failed). |
| `high-gaps` | Count of high-severity gaps. |
| `valid-agents` | Number of agent sessions that completed validly. |
| `passed` | `"true"` when the run completed, some persona got past the entry URL, gap analysis did not fail, and (in gate mode) all assertions passed. |
| `entry-block` | Why no persona got past the entry URL (auth wall or anti-bot challenge). Empty when some persona did. |
| `gap-analysis-status` | `ok`, `not_requested` (no `design-intent`), or `failed` (`design-intent` was set but gap analysis produced nothing). |

## Credit cost

Each check costs roughly **5 credits** with the default quick preset
(1 credit = 1 agent session; a run with auth configured costs 2× per agent).
Setting `agents` explicitly costs that many credits. Check your balance with
`boidwatch billing status` or at <https://app.boidwatch.com/billing>.

## Troubleshooting

The action maps the CLI's exit codes to explicit error annotations:

| Exit code | Meaning | What to do |
| --- | --- | --- |
| 0 | Success | None. |
| 1 | Unexpected error, or the run ended without completing | Read the annotation. It carries the CLI's error message, hint and run ID. |
| 2 | Validation | Check the inputs. The `url` must be publicly reachable; private and loopback URLs are rejected. |
| 3 | Authentication | Check the `BOIDWATCH_API_KEY` secret is set and not revoked. |
| 4 | Insufficient credits | Top up at <https://app.boidwatch.com/billing>. |
| 5 | Not found | The API did not find a resource it needed. The annotation names it. |
| 6 | Conflict | The create may still be committing. Do not re-run this job: check `boidwatch run list` for the run first. |
| 7 | Timeout | The run did not finish within `wait-timeout`. It keeps running; raise `wait-timeout` or resume with `boidwatch run results <id> --wait`. |
| 8 | Rate-limited | Wait, then resume with `boidwatch run results <run_id> --wait` if the log shows a run_id. Only re-run this job when no run was created. |
| 9 | Assertion failed | In gate mode, the findings breached your `assert-*` thresholds. In any mode, no persona got past the entry URL; in `comment` mode the job still succeeds with a warning. The sticky PR comment has the report. |
| 130 | Interrupted | The job was cancelled while waiting. The run keeps running; resume with `boidwatch run results <id> --wait`. |

`cmd/boidwatch/action_contract_test.go` checks this table, the asset name and
every `jq` path in `action.yml` against the CLI.

Other common issues:

- **No PR comment appears** — the job needs `pull-requests: write` permission,
  and the comment only posts on `pull_request` events.
- **`Unsupported runner OS`** or **`Unsupported runner arch`**: the action
  supports Linux and macOS runners on x86_64 (`X64`) and arm64 (`ARM64`).
- **`No persona got past the entry URL`**: the preview is protected (Vercel
  and Netlify previews are by default) or its WAF challenges Boidwatch's
  browsers. Make the preview public or allowlist the check, then re-run.
- **Share link missing from the comment** — minting the link failed (a warning
  annotation is emitted); the run itself still succeeded and `run-id` is set.
