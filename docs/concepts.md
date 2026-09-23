# Resource modules and platform apps

An AVM resource module provides a reusable implementation of an Azure resource and related features. It exposes a broad interface because it needs to support many deployment patterns.

The catalog's platform apps narrow that interface for application teams. Each wrapper combines pinned AVM modules with the organization's choices for sizing, private connectivity, identity, and diagnostics. Developers select the service and capacity tier rather than repeat those decisions for every application.

Two documents provide the inputs. The developer request contains five application-level fields. A separate environment binding, maintained by the platform team, supplies resource groups, network and DNS IDs, state storage, workspace, and SSH public key.

## Who changes what?

| Developer owns | Platform team owns |
| --- | --- |
| Application requirements and size request | Wrapper implementation and size-to-SKU mapping |
| Configuration PR and functional requirements | Region, target identity, scope, networking, DNS, egress |
| Application source and release process | Identity, RBAC, private state, deployment workflows |
| Application acceptance criteria | Dependency pins, image/runtime allowlists, policy tests |

The sample uses one maintainer to demonstrate both roles. A production deployment process would normally assign review and release approval independently.

## Contract

The [schema](../schemas/platform-app.schema.json) defines the request:

| Field | Rule |
| --- | --- |
| `schemaVersion` | `"1.0"` |
| `platformApp` | `storage`, `vm`, `web-app`, or `container-app`; must match the target |
| `name` | Lowercase application identifier matching `^[a-z][a-z0-9-]{2,19}$` |
| `environment` | `"demo"` |
| `size` | `"small"` or `"medium"` |

The schema rejects additional properties. The engine comes from the target path, `apps/<service>/<engine>/platform-app.json`, rather than a field a developer can switch. Changing an application name or engine can create a different instance, so it requires a migration or replacement review rather than a routine resize.

The renderer passes `config.name` unchanged to the wrapper, which derives the Azure resource names. It also records configuration and environment hashes in `deployment.json`. Bicep receives `app.parameters.json`; Terraform receives `app.tfvars.json` and `backend.hcl`.

Each target has a separate resource-group binding. Terraform state keys follow `demo/<service>-terraform/<name>.tfstate`; the corresponding metadata field on a Bicep target is not used for state.

Both engines offer the same application-level interface and security intent, but their module implementations and some resource choices differ. They manage independent resources, not interchangeable ownership of a single deployment. Review the service guides for those differences and their cost implications.

## Direct platform consumption

Platform engineers can also use the [eight wrapper examples](../README.md#eight-examples-one-developer-contract) directly. Security settings remain in the wrapper, so this route retains the same baseline rather than exposing unrestricted AVM parameters.

[`implementation-contract.json`](../catalog/implementation-contract.json) records the common interface. Service-specific inputs provide foundation IDs and, for the VM, a public SSH key. Wrapper outputs expose resource identifiers and other non-secret metadata, not credentials or Terraform state.

## What validation means

Schema checks validate the request; source and IaC tests check the implementation and dependency graph. Rendering converts configuration into deployment inputs without contacting Azure.

Deployment preparation adds checks for subscription policy, capacity, permissions, and network access, followed by a what-if or plan review. What-if can leave changes unevaluated, and Terraform plans can contain sensitive values. The [validation and deployment guide](rehearsal.md) separates these checks and documents current coverage.
