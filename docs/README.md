# `md2conf`

Publish Markdown from a repository `docs/` tree to Confluence using [`mark`](https://github.com/kovetskiy/mark).

## Requirements

To run locally, you need:

- `mark` v15+ ([https://github.com/kovetskiy/mark](https://github.com/kovetskiy/mark))
- GNU utilities such as `sed`, `realpath`, and `dirname` (typically available on developer machines; may be missing in distroless container images)

## Usage

```sh
MARK_BASE_URL=https://bfifinance.atlassian.net/wiki/ \
MARK_SPACE=DATA \
MARK_PARENTS= \
MARK_USERNAME=your.email@example.com \
MARK_PASSWORD=your-atlassian-api-token \
PROJECT_PREFIX_URL=https://github.com/org/repo/blob/main \
./md2conf.sh docs
```

You can avoid passing every variable on the command line:

- Create a `mark` TOML config (for example `mark.toml`) and run: `MARK_CONFIG=mark.toml ./md2conf.sh docs`
- Load a `.env` file: `env $(cat .env) ./md2conf.sh docs`
- Use `mise` with the included `mise.toml`, then run: `./md2conf.sh`

Reference `.env` and `mise.toml` files are included in this repository.

### Use from a pipeline

See [`.github/workflows/md2conf.yml`](/.github/workflows/md2conf.yml).

Per repository, configure:

| Name | Where | Example |
|------|--------|---------|
| `MARK_PASSWORD` | **Secret** (Settings → Secrets and variables → Actions → Secrets) | Atlassian API token |
| `MARK_SPACE` | **Variable** (Settings → Secrets and variables → Actions → Variables) | `DATA` or `~7120...` |
| `MARK_PARENTS` | **Variable** | `LMS/lms-calculation-service` |

Use **Variables** for `MARK_SPACE` and `MARK_PARENTS` (not secrets). They are not sensitive and are read via `${{ vars.MARK_* }}`.

#### Other repositories (for example `bfi-finance/lms-calculation-service`)

1. Add a `docs/` folder with your Markdown.
2. Set the three Actions settings above on that repository (or at org level).
3. Add `.github/workflows/md2conf.yml`:

```yaml
name: md2conf

on:
  push:
    branches: [main, master]
    paths:
      - 'docs/**'
  workflow_dispatch:

jobs:
  md2conf:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: alaksmana-mso/md2conf@main
        with:
          mark_space: ${{ vars.MARK_SPACE }}
          mark_parents: ${{ vars.MARK_PARENTS }}
          mark_password: ${{ secrets.MARK_PASSWORD }}
```

Or call the reusable workflow:

```yaml
jobs:
  md2conf:
    uses: alaksmana-mso/md2conf/.github/workflows/reusable-md2conf.yml@main
    with:
      mark_space: ${{ vars.MARK_SPACE }}
      mark_parents: ${{ vars.MARK_PARENTS }}
    secrets:
      MARK_PASSWORD: ${{ secrets.MARK_PASSWORD }}
```

If `alaksmana-mso/md2conf` is private, grant the consumer repository access (org settings / Actions access), or publish the action from a shared org repository.

Example published space: [Confluence](https://bfifinance.atlassian.net/wiki/spaces/~712020052f7b9360e3485597738b0dccd0b355/pages/2670493762/Service+Discovery).

## About

`md2conf` is a thin wrapper around `mark` with a fixed workflow:

- Pass a directory path (not globs). Every Markdown file under that path is published to Confluence.
- Remaining options are environment variables. See the `mark` documentation for supported settings.
- Parent pages follow the directory structure. For example, `some/deep/path/doc.md` maps to the same hierarchy in Confluence.
- If `PROJECT_PREFIX_URL` is set, a link to the source file is appended at the top of each page.
- `README.md` files are published under `MARK_PARENTS`.

## Why sync Markdown to Confluence?

Documentation serves different audiences with different access patterns:

- **Developers working in the codebase** benefit from docs next to the code, so updates can ship and be reviewed with the change.
- **Stakeholders without GitHub access** need Confluence, where docs sit with the rest of the project knowledge base and can stay aligned with code changes.
- **Readers with GitHub access who do not want to clone** can still browse source Markdown on GitHub when they need repository context.

## Why a composite action instead of inlining the script?

Keeping `md2conf.sh` as a real file (via a composite action) avoids large inline shell in YAML. The same script can be run locally, checked with `shellcheck`, and iterated without duplicating logic in workflow files.

### If you use an Atlassian classic token

Store the classic token in the repository secret **MARK_PASSWORD**.

### If you use an Atlassian scoped token (not recommended; last attempt did not work)

Create a **new** token with the required scopes (scopes cannot be edited later). For publishing with `mark` / `md2conf`, include at least:

| Scope | Purpose |
|------|---------|
| `read:page:confluence` | Find / load existing pages |
| `write:page:confluence` | Create / update pages |
| `read:space:confluence` | Resolve space |
| `write:attachment:confluence` | Upload images/diagrams |
| `read:attachment:confluence` | Read attachments when syncing |
| `read:hierarchical-content:confluence` | Parent / tree lookup |
| `write:folder:confluence` | Create folders (if used) |
| `read:folder:confluence` | Resolve folders |
| `write:label:confluence` / `read:label:confluence` | If you use labels |

Also useful if create-parent or content property calls fail:

- `read:content:confluence`
- `write:content:confluence`

**Important with scoped tokens:**

1. Base URL must use the platform form, not the site URL:

   `https://api.atlassian.com/ex/confluence/{cloudId}/wiki/`  
   (`cloudId` from e.g. `https://bfifinance.atlassian.net/_edge/tenant_info`)
2. Continue using Basic auth: email + token.
3. The Atlassian user still needs **edit** permission on the target space — scopes do not replace space permissions.

**Recommendation:** prefer a **classic unscoped** token for `md2conf` unless your organization requires scoped tokens. `mark` still depends on APIs that are awkward with minimal scopes, and this workflow is already configured for the site URL.
