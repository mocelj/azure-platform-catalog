# Security controls and production considerations

The catalog provides a private-access baseline and separates application configuration from deployment privileges. The table distinguishes what the code configures from what needs checking in an Azure environment. The release has passed CI, but no Azure deployment or live security verification has been performed.

| Area | Design | Verification or production consideration |
| --- | --- | --- |
| Configuration | Five-field schema, fixed service-engine target, and repeatable rendering | Plan/apply revalidate the request at a full consumer SHA merged into `main`; source and target mismatches are rejected |
| Infrastructure | Compositions of pinned official AVM modules | Review the resolved dependencies and planned resources against organizational policy |
| Storage | Private Blob endpoint; public access, anonymous access, and Shared Key off; HTTPS and minimum TLS | Test Entra-authorized private access and denial from Internet and Shared Key clients |
| VM | Private NIC, SSH keys, and restricted management source | Verify permitted and denied management paths, image/SKU compatibility, and guest configuration |
| Web App | Private site/SCM endpoint, HTTPS, minimum TLS, basic publishing off | Test both DNS names and Entra ZIP deployment; inbound Private Link and outbound VNet integration use separate subnets |
| Container Apps | Environment Private Link, public access off, HTTPS app ingress | Verify environment DNS and application routing; `external` app ingress means access from outside the environment, not necessarily the Internet |
| Egress | NAT-backed outbound connectivity | NAT is not a filtering firewall or destination allowlist; add inspection/filtering through the production landing zone |
| Monitoring | Diagnostics to a shared workspace over public Azure Monitor endpoints | No Azure Monitor Private Link Scope is deployed; assess private telemetry requirements |
| State | Bicep-owned private Blob storage, OIDC/Entra authorization, separate keys and locking | Verify private reachability and Blob data roles; management-plane Reader is insufficient |
| Foundation | Shared resources have one Bicep owner | Existing-foundation mode references customer resources without import, adoption, mutation, or deletion |
| PR validation | Hosted runners without Azure identity or private-state access | Repository rules must protect platform-owned files; editing consumer CI does not grant deployment access |
| Deployment runner | Catalog-only registration, isolated network, protected catalog code | A self-hosted runner in a public repository remains a demo exception; use a private execution repository and restricted runner group in production |
| Identity and approval | Short-lived federation, scoped roles, `demo-apply` approval | Check subject/audience and environment restrictions; one presenter's approval is not independent separation of duties |
| Plan handling | Private `plans` container, `plan_id`, source/input hashes, target serialization | Apply checks the reviewed plan's bindings and blocks unreviewed destruction; what-if limitations still need human review |
| Test coverage | Source checks, compilation/validation, nine mock plans across Storage, VM, and Web App | Container Apps has no environment/app/PE mock plans under Terraform `1.13.5`; its checks cover source invariants and real init/validate only |
| APIs | Pinned modules/providers and an API inventory | Terraform Container Apps uses `2025-10-02-preview` and `2025-02-02-preview`; review these and transitive preview APIs for production |
| Container image | MCR hello-world image pinned by digest | The older sample image is illustrative, not hardened; production needs a maintained image and artifact supply chain |
| Node runtime | Local toolchain pin and Azure `NODE\|24-lts` runtime family | App Service manages runtime patches, so local and Azure patch versions can differ |
| Application release | Reviewed ZIP/digest, separate build, scoped private deployment | PR code stays off the infrastructure runner; application authentication remains an application responsibility |
| Data handling | Test data in source, non-secret outputs, sanitized public summaries | State, plans, real bindings, tokens, and sensitive logs stay private |

## Monitoring and application responsibilities

The VM examples provide resource or NIC metrics and managed boot diagnostics, not guest-log collection. In Bicep, the VM AVM exposes diagnostic settings on the NIC rather than a top-level VM `diagnosticSettings` input. Guest telemetry needs an Azure Monitor Agent and data-collection-rule design.

Private networking and platform encryption are useful controls, but they do not provide application authorization, customer-managed key policy, malware protection, backup, or recovery testing. Those capabilities need to be designed around the customer's data and operating requirements.

## Applying the pattern in a regulated environment

Start with the organization's landing zone and change process. Move deployment execution to a private repository with restricted, preferably disposable runners; assign independent reviewers and prevent self-review. Integrate network inspection, identity governance, artifact controls, observability, data classification, recovery, and security operations.

The public telemetry path, preview APIs, sample image, and solo approval model are conscious simplifications for this example. They require customer-specific decisions rather than additional fields in the developer request. The catalog is not an FSI compliance certification or a replacement for a production landing zone.

References: [GitHub secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use), [deployment environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments), and [security reporting](../SECURITY.md).
