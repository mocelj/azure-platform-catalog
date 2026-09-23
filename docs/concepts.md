# Resource modules and platform apps

An **AVM resource module** exposes the supported interface for an Azure resource and related capabilities. It is reusable infrastructure, not the organization's application policy. Its defaults may be broader than this demonstration permits.

A **platform app** is the platform team's product: a thin composition of pinned AVM modules, fixed security settings, approved sizes, private connectivity, diagnostic defaults, and a stable input/output contract. It deliberately exposes fewer choices than AVM.

A **developer request** selects that product using five JSON fields. It is data, not an executable template. The **environment binding** is a separate platform-owned document containing scope, network/DNS, state, workspace, and public-key inputs.

## Who changes what?

| Developer owns | Platform team owns |
| --- | --- |
| Application intent and bounded size request | Wrapper implementation and approved size mapping |
| Configuration PR and functional requirements | Region, target identity, scope, networking, DNS, egress |
| Application source, reviewed through a separate release lane | Identity, RBAC, private state, trusted deployment workflows |
| Application acceptance criteria | Dependency pins, image/runtime allowlists, policy tests |

One presenter can demonstrate both roles, but that does not provide independent review or separation of duties.

## Contract

The authoritative [schema](../schemas/platform-app.schema.json) requires:

| Field | Rule |
| --- | --- |
| `schemaVersion` | Exactly `"1.0"` |
| `platformApp` | `storage`, `vm`, `web-app`, or `container-app`; must match the target |
| `name` | Lowercase application identifier matching `^[a-z][a-z0-9-]{2,19}$` |
| `environment` | Exactly `"demo"` |
| `size` | `"small"` or `"medium"` |

No additional property is allowed. The engine is **not** a property: `apps/<service>/<engine>/platform-app.json` binds the immutable service-engine target. Treat changes to application identity as a new instance/replacement review, not an ordinary resize.

The renderer passes the validated 3–20-character `config.name` unchanged to both languages. Each wrapper owns final Azure resource naming within its assigned target scope; the rendered `name` is not necessarily an Azure resource name. The renderer records configuration/environment hashes in `deployment.json`, emits `app.parameters.json` for Bicep, or `app.tfvars.json` and `backend.hcl` for Terraform. Distinct resource-group bindings and Terraform keys of the form `demo/<service>-terraform/<name>.tfstate` separate targets. The metadata key emitted for a Bicep target is not used as Terraform state.

Same developer interface does not mean identical Azure internals, arbitrary engine interchange, or equal costs. Each target has a distinct resource group; each Terraform root has its own backend state. Both implementations enforce the same intended controls without managing one another's resources.

## Direct platform consumption

Platform engineers can use the [eight local wrapper examples](../README.md#eight-examples-one-developer-contract). This does not expose raw AVM settings to developers. Required security settings remain hardcoded in the wrapper even when the wrapper is consumed directly.

The common interface is recorded in [`implementation-contract.json`](../catalog/implementation-contract.json). Service-specific inputs supply only the needed foundation IDs and VM public key. Outputs are resource IDs, private-access hostnames, and non-secret identity metadata; no keys, secrets, connection credentials, or state.

## What validation means

Schema checks prove a request is within the declared interface. Source and IaC tests add evidence about pinned dependencies and configuration controls. Rendering is deterministic data conversion. Neither a passing test nor a rendered file proves Azure capacity, permissions, network reachability, application readiness, or regulatory compliance.

An Azure what-if/plan is a separate connected activity. What-if can contain warnings or unevaluated changes; Terraform plans can contain sensitive values. Review limitations and source/input binding before approval. See [rehearsal gates](rehearsal.md).
