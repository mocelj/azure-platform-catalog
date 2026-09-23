# Security policy

This repository is a demonstration, not a production reference architecture, support commitment, or FSI compliance certification. No Azure deployment or live security outcome is established by offline validation.

## Reporting

Do not post credentials, customer data, exploitable details, state, plans, or private network information in public issues. Use the repository's **Security → Report a vulnerability** option if private reporting is enabled. If it is unavailable, ask `mocelj` for a private reporting channel without including the sensitive details. A private channel and response arrangements must be established before a connected rehearsal.

Include the affected catalog commit, target, expected boundary, observed behavior, and a minimal synthetic reproduction. Never attach live secrets. Report defects here rather than implying that this project is a Microsoft-operated service.

## Deployment boundary

- Public validation has no Azure credentials, OIDC token, private backend, or private runner.
- Connected execution is disabled unless `ENABLE_AZURE_DEPLOYMENT=true` and the documented prerequisites are satisfied.
- Only trusted, protected catalog code may run on the catalog-only private runner. Consumer JSON is data, not executable content.
- Both plan and apply require an exact 40-hex consumer commit already merged into approved `main`; no premerge/fork Azure preview is supported. Reject arbitrary repositories, paths, mutable commits, consumer scripts, mismatched plan/input bindings, and unreviewed destructive operations.
- Entra/OIDC authentication is required. Do not introduce Shared Key, SAS, publishing profiles, client secrets, or an ambient privileged runner identity as a workaround.
- Saved plans and state can contain sensitive data. Plans belong in the private `plans` Blob container, never public artifacts. Apply selects the reviewed `plan_id`, requires matching configuration/catalog/environment hashes and explicit `demo-apply` approval; publish only deliberately sanitized summaries.

Read the [control and exception matrix](docs/security-controls.md), [connected gates](docs/rehearsal.md), and [cleanup boundaries](docs/operations.md).

A self-hosted runner in a public repository remains risky. The documented isolation is a disposable-demo exception. For real FSI use, move the trusted execution plane to a private organizational repository and restricted runner group, apply organizational controls, and require independent approval.

## Versions

There is no long-term support promise. A release is eligible for rehearsal only after its dependency graph, provenance, lock files, tests, and explicit live gates have been reviewed. An immutable pin limits drift; it does not prove that an image is hardened or a dependency has no vulnerabilities. See [dependency upgrades](docs/dependencies.md).
