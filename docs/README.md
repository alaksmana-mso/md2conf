# `md2conf`

## Requirement

To run locally, you need:

- `mark` v15+ ([https://github.com/kovetskiy/mark](https://github.com/kovetskiy/mark))
- GNU utils like `sed`, `realpath`, `dirname`, etc. which should be available in your machine (but may not be available when you're using distroless container image)

## Usage

```sh
MARK_BASE_URL=https://bfifinance.atlassian.net/wiki/ MARK_SPACE=DATA MARK_PARENTS= MARK_USERNAME=mso.andre.laksmana@bfi.co.id MARK_PASSWORD=your-atlassian-password PROJECT_PREFIX_URL=https://github.com/alaksmana-mso/md2conf/blob/main ./md2conf.sh docs
```

Fyuh, what a load of envronment variables to pass. Alternative ways:

- Create a `mark` TOML config file, for example `mark.toml`, then refer it like `MARK_CONFIG=mark.toml ./md2conf.sh docs`
- Use `.env` file, then do, idk, `env $(cat .env) ./md2conf.sh docs`
- Like previous options, but with `mise`, and just do `./md2conf.sh`

Reference `.env` and `mise.toml` are included in this repo for you to look at.

### Use from pipeline

See this project [`.github/workflows/md2conf.yml`](/.github/workflows/md2conf.yml).

Per repository, configure:

| Name | Where | Example |
|------|--------|---------|
| `MARK_PASSWORD` | **Secret** (Settings → Secrets and variables → Actions → Secrets) | Atlassian API token |
| `MARK_SPACE` | **Variable** (Settings → Secrets and variables → Actions → Variables) | `DATA` or `~7120...` |
| `MARK_PARENTS` | **Variable** | `LMS/lms-calculation-service` |

Use **Variables** for `MARK_SPACE` / `MARK_PARENTS` (not secrets) — they are not sensitive and are read via `${{ vars.MARK_* }}`.

#### Other repositories (e.g. `bfi-finance/lms-calculation-service`)

1. Add a `docs/` folder with your markdown.
2. Set the three Actions settings above on that repo (or at org level).
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

If `alaksmana-mso/md2conf` is private, grant the consumer repo access (org settings / Actions access), or publish the action from a shared org repo.

See this repository resulting [Confluence](https://bfifinance.atlassian.net/wiki/spaces/~712020052f7b9360e3485597738b0dccd0b355/pages/2670493762/Service+Discovery).

## About

This tool wrap `mark` (well, wrapping means supeset, but this is more like a limited subset).

- You can only pass directory to process. Instead of globs `'**/*.md'`, you specify path. Every markdown inside the path will be published as Confluence docs.
- Everything else is passed as environment variables. Read `mark` docs to read the args.
- Parents will be added according to directory structure. Having your markdown in deep path, i.e. `some/deep/path/doc.md` will yield the same structure in Confluence.
- If you provide the `PROJECT_PREFIX_URL`, link to the source file will be appended to the top of the docs.
- `README.md` are written into `MARK_PARENTS`.



## Question



### Why?

Because documentation serves different users; and these users have different way to fulfill their needs.

- **As a developer who work with the code** in a day-to-day basis, having the docs available next to the code in the editor is the best. As a plus, documentation can be updated along with code changes for easier review.
- **As a product person** who does not have access to GitHub (don't ask me, ask our CTO), having the docs available in Confluence means it's accessible with the rest of the documentations. As a plus, it is grouped by project, and maybe it'll be updated when people make changes along with the code, instead of being left outdated. (A high ask, since people still like to left outdated code.)
- **As a traveler developer** who have access to GitHub but does not want to clone the repositories, having the docs available in GitHub means it's easier to look at and understand the context around.



## Why a composite action instead of inlining the script?

I don't want to inline shellscript in yaml. A composite action keeps `md2conf.sh` as a real file. This means I can use the script locally, `shellcheck` it, and iterate.

### **If you use Atlassian classic token** 

Add the Atlassian classic token as part of the repo secret variable **MARK_PASSWORD**.

### **If you use Atlassian scoped token (not recommended, last try did not work)**

Create a **new** token with scopes (you can’t edit scopes later). For publishing docs with `mark` / `md2conf`, include at least:


| **Scope**                                          | **Why**                       |
| -------------------------------------------------- | ----------------------------- |
| `read:page:confluence`                             | Find / load existing pages    |
| `write:page:confluence`                            | Create / update pages         |
| `read:space:confluence`                            | Resolve space                 |
| `write:attachment:confluence`                      | Upload images/diagrams        |
| `read:attachment:confluence`                       | Read attachments when syncing |
| `read:hierarchical-content:confluence`             | Parent / tree lookup          |
| `write:folder:confluence`                          | Create folders (if used)      |
| `read:folder:confluence`                           | Resolve folders               |
| `write:label:confluence` / `read:label:confluence` | If you use labels             |


Also useful if create-parent / content props fail:

- `read:content:confluence`
- `write:content:confluence`

**Important with scoped tokens:**

1. Base URL must be the platform form, not your site URL:

`https://api.atlassian.com/ex/confluence/{cloudId}/wiki/`  
(cloudId from e.g. `https://bfifinance.atlassian.net/_edge/tenant_info`)
2. Still use Basic auth: email + token (same as now).
3. The Atlassian user still needs **edit** permission on the target space — scopes don’t replace space permissions.

**Practical recommendation:** use a **classic unscoped** token for `md2conf` unless your org requires scoped tokens. `mark` still leans on APIs that are awkward with minimal scopes, and your workflow is already wired to the site URL.