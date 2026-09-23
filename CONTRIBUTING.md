# Contributing

This is a demonstration of a constrained developer interface over official AVM. Changes must preserve that boundary, not turn the catalog into an arbitrary infrastructure execution service.

1. Explain the intended behavior and affected targets in a PR.
2. Use the exact tool versions in [`catalog/toolchain.json`](catalog/toolchain.json).
3. Run from the catalog root:

   ```powershell
   npm ci --ignore-scripts
   npm test
   npm run check
   node scripts/tooling.mjs
   npm run iac:check
   ```

   Dependency/tool downloads need network access; these checks do not deploy Azure resources. Report commands actually run and any failures. See [release gates](docs/rehearsal.md).
4. Add positive and negative tests for contract or control changes. Keep Bicep and Terraform behavior aligned, with separate resources and state.
5. Update the relevant example, compatibility records, and documentation. Dependency upgrades require explicit review; never regenerate provider locks with upgrades during normal CI.

First-party infrastructure must compose pinned official AVM. Do not add custom Azure resource declarations, Terraform provisioners, inline ARM, `az rest` creation paths, mutable dependencies, or passthrough objects that bypass policy. Changing schema validation alone does not change wrapper controls.

Do not include real environment bindings, tokens, SSH private keys, state, saved plans, deployment outputs, customer identifiers, or sensitive logs in commits or public artifacts. See [SECURITY.md](SECURITY.md).

Maintainers review platform-owned files and connected execution separately. A passing public PR check is not deployment authorization. Public contributions never execute on the private runner. CODEOWNERS only requests reviews; repository rules and environment restrictions must also be configured.

Original contributions are licensed under [MIT](LICENSE). Upstream AVM, providers, Actions, tools, and images keep their own licenses and attribution. Do not copy or relicense upstream source as original demo code.
