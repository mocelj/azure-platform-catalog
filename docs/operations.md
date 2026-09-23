# Operations, costs, and cleanup

This guide covers the operating considerations for deploying and removing the examples: cost, fault isolation, state ownership, and cleanup order.

## Cost drivers

Estimate costs using the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/) with your region, SKUs, expected usage, retention, and commercial terms. The main drivers are:

| Resource | Main drivers |
| --- | --- |
| Shared foundation | NAT Gateway, outbound public IP, private endpoints/traffic, private DNS, Log Analytics ingestion/retention, state/plan storage and recovery copies |
| Blob Storage | Redundancy, stored capacity, operations, recovery/version retention, data transfer, private endpoint |
| VM | VM size/running allocation, OS/data disks, diagnostics, network traffic; deallocation does not remove all disk/network costs |
| Web App | App Service plan capacity/instances even when sample traffic is low, private endpoint, diagnostics/egress |
| Container App | Workload-profile/environment choices, CPU/memory/replicas, requests/traffic, private endpoint and diagnostics |
| Delivery | Runner hosting, dependency/artifact storage, retained plans and logs; runner infrastructure is not provisioned here |

The `small` tier is a sizing choice, not a free tier. Select the targets needed for the exercise rather than assuming all eight must run. Shared services continue to incur charges after a workload is removed, and scale-to-zero does not remove environment or network costs. Budgets and cost alerts should come from your normal governance process; this catalog does not create them.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Unknown property / rejected request | Compare the request with the five-field schema and target. New infrastructure options need a platform design change, not just a schema extension |
| Unexpected target/engine | Check the folder mapping. Engine changes create a different managed target and require migration planning |
| Tool mismatch / failed restore | Compare versions and artifact checksums with the catalog records, then use the tooling script to restore the required version |
| Provider lock changed | Check platform/checksum coverage and dependency drift; handle intentional changes through an upgrade PR |
| VM provider deprecation warnings | Validation succeeds with the documented upstream warnings. Retain them for the next AVM/provider upgrade review |
| Terraform tests prompt for variables | For Storage, VM, or Web App, pass the selected example's `.example.tfvars.json` explicitly with `-var-file` from the workload root; see [the test command](rehearsal.md#run-one-terraform-mock-suite). Container Apps has no mock suite |
| Container Apps mock unavailable | This is a Terraform `1.13.5` limitation with the upstream ephemeral schema. `iac:check` reports source checks and init/validate only, without environment/app/PE mock coverage |
| Missing Azure permission | Identify whether the failure is control-plane, role-assignment, or Blob data-plane access, then review the identity's scope |
| Terraform backend unreachable | Check private DNS, routes, endpoint approval, OIDC, and Blob authorization. Public access or account keys would bypass the intended design |
| State locked | Identify the operation holding the lease before investigating abandoned execution; force-unlock requires a recovery decision |
| Web App private site works but deployment fails | Check SCM DNS, private reachability, and Entra publish permissions; the release path does not use basic publishing |
| Web App starts the wrong content | Infrastructure does not upload the Node sample. Verify the separate reviewed ZIP, root layout, startup command, and runtime |
| Container App inaccessible | Check environment Private Link/DNS, public-access setting, app ingress, target port, image startup, and private client route together |
| VM cannot connect | Check the management route/source, NSG, public-key pairing, image/SKU, and boot diagnostics while retaining private access |
| What-if shows incomplete analysis | Review the warning and affected resources before deciding whether the change can proceed |
| Connected job skipped | Check enablement and prerequisites; a skipped job has performed no Azure validation |

Capture the failing command, exit status, and enough sanitized output to diagnose it. Keep state, plans, tokens, and raw Azure debug logs out of public issues.

## Cleanup: workload first, state last

Treat cleanup as a reviewed infrastructure change. Confirm ownership from the deployment records and state, rather than from a naming prefix alone.

1. Stop new dispatches for the target and check active operations. Retain the source commits, input hashes, resource IDs, owner, engine, and backend key.
2. Review deletion impact, including shared dependencies, locks, recovery requirements, and data retention.
3. For Terraform, use the same catalog root, variables, backend, identity, and locking as deployment. Review a saved destroy plan in private storage before applying it. Automated approval, disabled locking, and key-based access are not part of this path.
4. For Bicep, remove the target's resources or its dedicated resource group after confirming the group contains no shared or customer-owned resources. Deleting deployment history does not delete resources; complete-mode deployment is not the teardown mechanism.
5. Reconcile the remaining inventory and state, including retained backups and soft-deleted data.
6. The foundation owner removes the demo foundation only after all dependent targets are gone. Preserve required state and audit records before removing the backend.
7. Exclude existing customer foundation resources from cleanup. Referencing them in environment JSON does not transfer ownership.
8. Disable deployment, retire demo-only federation/access and runner connectivity, and dispose of private workspaces and artifacts under the retention policy. Review any remaining charges.

### Terraform destroy-plan shape

From the catalog root on the private operator host, after initializing the target's backend as described in the service guide:

```powershell
$root = 'platform-apps\storage\terraform'
$variables = '<absolute-path-to-reviewed-rendered-app.tfvars.json>'
$plan = '<absolute-path-in-approved-private-storage-for-cleanup.tfplan>'
& .\.tools\terraform.exe "-chdir=$root" plan -destroy "-var-file=$variables" "-out=$plan"
if ($LASTEXITCODE -ne 0) { throw 'Destroy planning failed. Do not proceed.' }
```

This command produces a plan only. Review its deletion set, digest, state key, source/input hashes, and active operations before using `terraform apply` with that saved plan. Keep the plan private.

On Linux, use the `.tools` Terraform executable and native paths. Cleanup must use the instance's existing root and state; a different backend or engine would lose the ownership information needed to remove it safely.
