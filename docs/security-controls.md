# Controls, evidence, and exceptions

This matrix describes the intended platform boundary and what must be verified. It is **not** a certification, penetration-test result, or claim that resources have been deployed. Offline checks and Azure-connected tests answer different questions.

| Area | Catalog control / boundary | Required connected evidence or explicit exception |
| --- | --- | --- |
| Developer input | Five-field schema, no extra properties, fixed service-engine target; deterministic data rendering | Both plan/apply require exact 40-hex consumer SHA already merged into approved `main`; revalidate and reject forged target/path or source/input mismatch |
| IaC ownership | First-party composition of exact official AVM references, not custom base resource definitions or arbitrary passthrough | Review resolved dependency closure and actual planned resources; AVM alone is not organizational policy |
| Storage ingress/auth | Private Blob endpoint; public access, anonymous Blob access, and Shared Key disabled; HTTPS/TLS minimum | Private DNS and authorized Entra Blob access succeed; Internet and Shared Key access fail |
| VM ingress/auth | Private NIC, no VM public IP, SSH public-key-only authentication, scoped private management path | Approved private source can connect; unapproved sources cannot; verify image/SKU security capability and guest posture |
| Web App ingress/publishing | Private endpoint, public access off, HTTPS and minimum site/SCM TLS, FTP/SCM basic publishing disabled | Private site **and SCM** resolve/reach correctly; Entra ZIP deployment succeeds without credentials fallback |
| Web App egress | Separate delegated integration subnet with deliberate VNet routing | Confirm supported traffic takes the intended route; inbound Private Link alone does not control outbound traffic |
| Container Apps ingress | Environment-level Private Link and public access disabled; insecure app ingress off | Private endpoint/DNS and app routing work together; app `external` ingress is not synonymous with public Internet access |
| Egress | Explicit NAT-backed demo outbound path; no VM default-outbound dependency | **Exception:** NAT is not a filtering firewall or destination allowlist. Production needs approved inspection/filtering and egress governance |
| Monitoring | Workspace/diagnostic bindings through the approved composition | **Exception:** Azure Monitor connectivity is public. Do not describe telemetry as private or imply AMPLS is deployed |
| State | Bicep-owned private Blob storage; Entra/OIDC backend; separate target keys and locking | Runner reaches private endpoint and has data-plane permissions; Reader alone is insufficient; no keys/SAS fallback |
| Foundation | Bicep owns shared network, DNS, NAT, state, identities and bootstrap scopes | Existing-foundation JSON binds to customer-owned resources; no adoption/import, mutation, or deletion of them |
| Public validation | Hosted runners, minimum read permission, no Azure token/secrets/state/private runner | Verify workflow and repository policy; changing a consumer workflow cannot authorize connected execution |
| Connected runner | Registered only to catalog; trusted catalog code; consumer JSON is data; isolation and no stored powerful identity | **Exception:** public-repository self-hosted runners remain risky. Real FSI use requires a private trusted execution plane and restricted runner group |
| Identity and approval | Short-lived catalog/environment-scoped federation, scoped rights, explicit protected `demo-apply` approval | Verify actual subject/audience, branch/environment restrictions, and permissions. **Solo approval is not independent separation of duties** |
| Plan integrity | Private `plans` Blob container, sanitized `plan_id`, config/catalog/environment hash binding, target serialization; no public raw-plan artifacts | Apply only the reviewed bound result; reject mismatches and unattended destruction; retain what-if limitations. No premerge Azure preview |
| Offline test coverage | Pinned compiler/provider checks plus source contracts; nine passing mocked plan runs across Storage, VM, and Web App | **No Container Apps mocked plan coverage**, including app/PE: Terraform `1.13.5` rejects the upstream ephemeral mock schema even at count zero, and `override_module` failed. Its unsupported test file was removed; Node source invariants and real init/validate are the only evidence, with an explicit `iac:check` limitation message |
| API compatibility | Exact modules/providers plus recorded API inventory | **Exception:** Terraform Container Apps includes `2025-10-02-preview` and `2025-02-02-preview`; inspect the complete resolved inventory for more |
| Container supply chain | Exact MCR hello-world digest and port | **Exception:** old illustrative image, not FSI-hardened or a vulnerability-free/supported workload claim; approved private supply chain is a production adaptation |
| Node runtime | Exact local/test toolchain; supported `NODE\|24-lts` native Web App family | Azure manages runtime patches. Exact local patch parity is not guaranteed; verify the live runtime and support status |
| Payload | Separate reviewed artifact/digest and narrow private Entra deployment | Do not build/run untrusted PR code on the infrastructure runner; private ingress does not replace application authorization |
| Data/log handling | Synthetic source-controlled examples, no secrets in outputs; sanitized summaries only | Keep state, plans, real bindings, raw outputs and logs private; verify that sanitization removes sensitive values |

## What is outside this demo

No production landing-zone replacement, regulatory attestation, enterprise network inspection, private ACR supply chain, business authentication/authorization, disaster-recovery guarantee, or managed security operations is provided. Do not infer guest monitoring/patching agents, customer-managed keys, malware protection, or backup from a managed identity or diagnostic setting.

The Bicep VM baseline exposes NIC `AllMetrics` and managed boot diagnostics, **not guest-log collection**. Its pinned VM AVM does not expose a top-level `diagnosticSettings` input. An Azure Monitor Agent/data-collection-rule design would require a separately reviewed implementation and evidence; a workspace binding alone does not provide it.

Default platform encryption and transport settings do not establish a customer-specific key-management policy. A resource being private does not establish least-privilege application access. A version pin does not establish content integrity without reviewed provenance/hashes.

## Before using this pattern in FSI

Move trusted execution to a private organizational repository and restricted ephemeral runners. Require independent reviewers and prevent self-review. Integrate approved landing-zone policy, network controls, identity governance, private artifact supply chain, observability, data classification, recovery testing, security operations, and formal change control. Reassess preview APIs and native runtime patch policy.

These are adaptations requiring design and evidence, not switches hidden in the developer JSON.

See [GitHub secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use), [deployment environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments), and [security reporting](../SECURITY.md).
