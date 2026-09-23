# Contributing

The catalog maintains a common developer interface across Bicep and Terraform. Contributions should keep that interface small and put infrastructure choices in the platform-owned wrappers.

1. Describe the intended behavior, affected targets, and operational impact in the PR.
2. Use the versions in [`catalog/toolchain.json`](catalog/toolchain.json) to match CI.
3. Run from the catalog root:

   ```powershell
   npm ci --ignore-scripts
   npm test
   npm run check
   node scripts/tooling.mjs
   npm run iac:check
   ```

   Restoring tools and dependencies requires network access, but the checks do not deploy Azure resources. Include results and any remaining gaps in the PR. The [validation guide](docs/rehearsal.md) describes the test coverage.
4. Cover accepted and rejected inputs when changing the interface or controls. Keep equivalent behavior across both engines while retaining separate resource ownership and state.
5. Update examples, dependency records, and documentation together. Regenerate provider locks in a dependency-upgrade PR rather than during routine CI.

Infrastructure changes use pinned official AVM modules. Custom resource declarations, Terraform provisioners, inline ARM, CLI resource creation, and unrestricted AVM parameter objects are outside this design. Security settings belong in the wrappers as well as the input checks, so direct platform-team use retains the same controls.

Keep real environment bindings, credentials, SSH private keys, state, saved plans, customer identifiers, and sensitive deployment output out of commits and public artifacts. See [SECURITY.md](SECURITY.md) for reporting and handling guidance.

Maintainers review platform changes and deployment authorization separately. PR checks run on hosted runners; the private runner executes only catalog deployment jobs. CODEOWNERS provides review routing, while repository rules and environment settings enforce it.

Original contributions use the [MIT license](LICENSE). Upstream AVM, providers, Actions, tools, and images retain their own licenses and attribution.
