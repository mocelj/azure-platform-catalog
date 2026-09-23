# Security policy

The catalog separates public configuration validation from private Azure deployment. Its security controls and the adaptations needed for production are described in the [design review](docs/security-controls.md). The published release has passed CI but has not been deployed to Azure.

## Reporting

Use **Security → Report a vulnerability** if private reporting is enabled. Otherwise, contact `mocelj` to arrange a private channel before sharing details. Public issues are not suitable for credentials, customer data, exploit details, state, plans, or private network information.

Include the catalog commit, target, expected and observed behavior, and a reproduction using test data. Report issues with these wrappers here; the repository is maintained independently of Microsoft.

## Deployment controls

- Public validation uses hosted runners without Azure credentials, OIDC tokens, or private backend access.
- Deployment is disabled by default. Enabling `ENABLE_AZURE_DEPLOYMENT` requires the [environment prerequisites](docs/rehearsal.md).
- The private runner is registered only to the catalog. It executes protected catalog code and reads consumer JSON as data, not scripts or application source.
- Plan and apply accept a full 40-hex consumer commit already merged into `main`. Repository, path, target, ancestry, and input checks prevent arbitrary source execution and stale-plan reuse. Premerge and fork previews are not supported.
- Entra/OIDC provides short-lived authentication. Shared Key, SAS, publishing profiles, client secrets, and persistent privileged runner identities are not part of the deployment path.
- Saved plans and state stay private because they can contain sensitive values. Apply selects a `plan_id` from the private `plans` container, verifies configuration/catalog/environment hashes, and requires `demo-apply` approval. Public logs contain sanitized summaries only.

The public-repository self-hosted runner is a deliberate demo exception. For production, particularly in a regulated environment, use a private organizational execution repository, restricted runners, and independent approval. The [control matrix](docs/security-controls.md) and [cleanup guide](docs/operations.md) cover the associated operating requirements.

## Versions

The project has no long-term support commitment or compliance certification. Pinned versions provide reproducibility, while vulnerability review and live verification remain separate responsibilities. See [dependency upgrades](docs/dependencies.md) for the release process.
