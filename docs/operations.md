# Operations, costs, and cleanup

These are instructions for a separately authorized connected rehearsal. They are not evidence of deployed resources or permission to delete anything.

## Cost drivers

There is no fixed price estimate in this repository. Use the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/) with the actual region, selected SKUs, usage, retention, and account pricing before provisioning.

| Resource | Main drivers |
| --- | --- |
| Shared foundation | NAT Gateway, outbound public IP, private endpoints/traffic, private DNS, Log Analytics ingestion/retention, state/plan storage and recovery copies |
| Blob Storage | Approved redundancy, stored capacity, operations, recovery/version retention, data transfer, private endpoint |
| VM | VM size/running allocation, OS/data disks, diagnostics, network traffic; deallocation does not remove all disk/network costs |
| Web App | App Service plan capacity/instances even when sample traffic is low, private endpoint, diagnostics/egress |
| Container App | Workload-profile/environment choices, CPU/memory/replicas, requests/traffic, private endpoint and diagnostics |
| Delivery | Runner hosting, dependency/artifact storage, retained plans and logs; runner infrastructure is not provisioned here |

`small` is a bounded catalog tier, not “free.” Running all eight examples costs more than selecting one. Shared-foundation charges continue after a workload is removed. Autoscale or an idle sample does not establish zero cost. Configure organizational cost governance separately; this demo does not create budgets or alerts.

## Troubleshooting without weakening the contract

| Symptom | Check |
| --- | --- |
| Unknown property / rejected request | Use the five-field schema and matching target. Remove the attempted override; do not extend the schema to bypass policy |
| Unexpected target/engine | Verify the approved folder mapping. Changing engines creates another managed target, not a migration |
| Tool mismatch / failed restore | Compare exact versions and artifact checksums; use the recorded installer and restore commands. Never substitute a floating version |
| Provider lock changed | Stop normal validation; investigate platform/checksum coverage or dependency drift through an explicit upgrade PR |
| VM provider deprecation warnings | Retain the accepted upstream AVM warnings in evidence. They do not mean validation failed, but require upgrade review; do not patch upstream code or change pins to hide them |
| Terraform tests prompt for variables | For Storage, VM, or Web App, pass the selected example's `.example.tfvars.json` explicitly with `-var-file` from the workload root; see [the test command](rehearsal.md#run-one-terraform-mock-suite). Container Apps has no mock suite |
| Container Apps mock unavailable | Terraform `1.13.5` rejects the upstream ephemeral mock schema even at count zero; module override also failed. The unsupported test file is removed. `iac:check` explicitly reports the gap: Node source invariants and real init/validate only, with no environment/app/PE mocked plan coverage |
| Missing Azure permission | Distinguish control-plane, role-assignment, and Blob data-plane permissions; check exact identity and scope, not a blanket Owner grant |
| Terraform backend unreachable | Inspect private DNS, route, endpoint approval, Entra/OIDC configuration, and Blob authorization; do not enable public access or retrieve keys |
| State locked | Identify the owning live operation and serialization key. Investigate abandoned execution; force-unlock is not normal automation |
| Web App private site works but deployment fails | Check SCM DNS/private reachability and Entra publish permissions. Do not enable basic publishing or use a profile |
| Web App starts the wrong content | Infrastructure does not upload the Node sample. Verify the separate reviewed ZIP, root layout, startup command, and runtime |
| Container App inaccessible | Check environment Private Link/DNS, public-access setting, app ingress, target port, image startup, and private client route together |
| VM cannot connect | Verify approved management route/source, NSG, public-key pairing, exact image/SKU and boot state. Do not attach a public IP |
| What-if shows incomplete analysis | Preserve and review the warning/unevaluated resources; it is not an unconditional safe-to-apply signal |
| Connected job skipped | Confirm enablement and prerequisites. Report **not configured / not run**, not success |

For a failure, keep exact command exits and minimal sanitized evidence. Do not paste raw state, saved plans, tokens, or Azure debug logs into public issues.

## Cleanup: workload first, state last

Cleanup is a separate reviewed change. Do not run it automatically after a public PR, as an error handler, or against a resource group guessed from a prefix.

1. Stop new dispatches for the exact target and identify in-flight operations. Preserve the source commits, configuration/environment hashes, resource IDs, owner, engine, and Terraform backend key.
2. Review the full inventory and deletion impact, including data retention, shared dependencies, locks, recovery requirements, and the exact approval scope. A deployment name or tag alone is not sufficient proof of ownership.
3. For **Terraform**, use the same fixed catalog root, reviewed variables, private backend, Entra identity, and locks. Produce a destroy plan in approved private storage and review it; apply only that exact approved plan. No `-auto-approve`, `-lock=false`, key fallback, or routine force-unlock.
4. For **Bicep**, deleting deployment history does not delete its resources. Review and remove only the disposable target's owned workload resources, or its dedicated resource group if the owner has verified it contains no shared/customer resources. Do not use complete-mode deployment as an improvised teardown mechanism.
5. Verify workload resources are actually removed and reconcile state/inventory. Preserve or dispose of backups/recovery copies according to the reviewed retention decision.
6. Only the **foundation owner** may remove a created demo foundation after every dependent target is gone and no state/plan storage is still needed. Preserve required Terraform state and audit evidence securely before removing the backend.
7. **Never delete or adopt an existing customer foundation.** Existing mode is a binding, not ownership. Keep its network, DNS, identities, workspace, state account, and resource groups outside cleanup scope.
8. Disable connected execution, revoke demo-only access/federation as appropriate, remove/recycle the isolated runner, and remove private workspaces/artifacts according to the approved retention policy. Verify any remaining billable resources with the owner.

### Terraform destroy-plan shape

For an authorized Windows private operator, from the catalog root, after initializing the **correct private backend** according to the service guide:

```powershell
$root = 'platform-apps\storage\terraform'
$variables = '<absolute-path-to-reviewed-rendered-app.tfvars.json>'
$plan = '<absolute-path-in-approved-private-storage-for-cleanup.tfplan>'
& .\.tools\terraform.exe "-chdir=$root" plan -destroy "-var-file=$variables" "-out=$plan"
if ($LASTEXITCODE -ne 0) { throw 'Destroy planning failed. Do not proceed.' }
```

This example **only produces a plan**. Before a separately approved apply, verify its digest, target/state key, source/variable hashes, exact deletion set, and current lock/operation status. The operator then uses the same root and `terraform apply` with the exact reviewed saved plan. Do not upload that plan to a public GitHub artifact or log its raw contents.

For Linux, use the pinned `.tools` Terraform executable and native paths. Never use a different engine, empty/new backend, or alternate state key to “clean up” an instance.
