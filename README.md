# AWS Terraform Lab

A hands-on DevOps lab for designing, provisioning, validating, and tearing down AWS infrastructure with Terraform. The goal is to build a reproducible environment and document the reasoning behind its networking, access controls, state management, and cost decisions.

> **Status: Local scaffold prepared.** The repository contains design documents, an offline cost calculator, and Terraform provider scaffolds with pinned dependencies. AWS resource implementation and deployment are still pending; no infrastructure has been deployed by this project.

## What this project will demonstrate

- Infrastructure changes defined in Terraform and reviewed through Git.
- AWS networking and service permissions with explicit boundaries.
- Protected remote state and controlled infrastructure changes.
- Verification that covers service behavior, security, and reproducibility.
- A documented teardown process and evidence of the results.

The project follows **Spec → Plan → Build → Test → Review**. Each phase should produce something that can be inspected and explained.

## Design documents

- [Cost review and operating limits](docs/cost-review.md)
- [Architecture baseline and decisions](docs/architecture.md)
- [Local development, repository layout, and pinned versions](docs/local-development.md)
- [Verified Ohio pricing snapshot](docs/pricing-us-east-2.json)
- [Offline cost calculator](scripts/estimate_costs.py)

The 2026-11-06 review estimates **$0.43 in metered usage for 20 practice hours per month** when the workload is destroyed after each session, including a conservative 1 GB paid-egress allowance. The goal remains **$0 out of pocket while the project stays FREE / ACTIVE with sufficient credits**. See the cost review for assumptions and exclusions; this is not a spending guarantee.

## Project constraints

| Area | Decision |
| --- | --- |
| AWS Region | `us-east-2` (Ohio) |
| Environment | One temporary `dev` environment |
| Spending | Zero out-of-pocket AWS spending |
| Deployment | Pending explicit implementation / deployment authorization and a fresh cost preflight |
| Repository | Private during initial development |
| Documentation | English |

The spending requirement is a design constraint, not a claim that the proposed services are free. Before any deployment, verify the active AWS plan, available allowances or credits, expected usage, and cleanup requirements. Include compute, storage, public IPv4 addresses, and data transfer in that review.

Do not upgrade the AWS project to a paid plan or activate paid features as part of this lab. Adjust the architecture if it cannot meet the spending requirement.

## Architecture baseline

The cost-reviewed baseline is a small, single-Availability-Zone lab. These resources are planned, not deployed.

- A dedicated VPC with one public subnet, an Internet Gateway, and a route table.
- One Linux x86_64 t3.micro in standard CPU-credit mode, running Nginx and a simple demonstration page.
- One encrypted 8 GiB gp3 root volume with baseline performance and deletion on termination.
- One auto-assigned public IPv4 address; no separate Elastic IP allocation.
- A Security Group that restricts HTTP access to the operator's IP.
- Administrative access through AWS Systems Manager Session Manager.
- An IAM role for the instance, with permissions limited to its required tasks.
- Terraform state in a separate S3 backend with encryption, versioning, blocked public access, and state locking.

```mermaid
flowchart LR
    Operator["Operator"]
    Terraform["Terraform"]
    State["S3 remote state"]

    subgraph AWS["AWS · us-east-2 · design only"]
        subgraph VPC["Dedicated VPC"]
            subgraph Subnet["Public subnet · one Availability Zone"]
                EC2["t3.micro · Linux + Nginx"]
            end
            IGW["Internet Gateway"]
        end
        SSM["Systems Manager"]
    end

    Operator -->|"HTTP · restricted source IP"| IGW
    IGW --> EC2
    Operator -->|"Administrative session"| SSM
    SSM --- EC2
    Terraform -->|"Provision"| VPC
    Terraform <-->|"Read / write state"| State
```

High availability, load balancing, databases, Kubernetes, and a production application are outside the initial scope.

## Roadmap

| Phase | Deliverable | Status |
| --- | --- | --- |
| 1. Specify | Scope, spending constraints, and acceptance criteria | Documented |
| 2. Design | Reviewed architecture, cost estimate, and decision records | Baseline documented |
| 3. Prepare | Repository structure, pinned tool versions, and authentication guide | Prepared and locally validated |
| 4. Manage state | Separate backend bootstrap and recovery procedure | Planned |
| 5. Implement | Parameterized networking, IAM, compute, and instance configuration | Planned |
| 6. Validate | Local and CI checks, deployment verification, and reproducibility evidence | Planned |
| 7. Review and clean up | Teardown evidence, final documentation, and reproducible demonstration | Planned |

**Next milestone:** define the protected bootstrap state location and implement the S3 backend with recovery and migration instructions. A future deployment must recheck the live plan, credits, Region, and expiry before apply and obtain deployment authorization.

## Local preparation

Terraform **1.17.1** and the **hashicorp/aws 6.72.0** provider are pinned. Separate roots live in `infra/bootstrap` and `infra/environments/dev`; neither contains resources or data sources yet. The dev S3 backend is a partial declaration, not a configured or existing bucket.

For local-only checks, use `fmt`, `init -backend=false`, and `validate` from [the development guide](docs/local-development.md). The provider lock files cover Windows AMD64 and Linux AMD64. Actual execution has been checked on Windows; Linux hashes are prepared for later CI.

## Acceptance criteria

The completed lab should satisfy all of the following:

- A fresh clone can reproduce the environment by following the documented prerequisites and steps.
- The demonstration page responds from the allowed source IP.
- Administrative access works through Session Manager without opening SSH.
- A second Terraform plan reports no changes when the configuration and environment are unchanged.
- A controlled configuration change produces the expected infrastructure change.
- Terraform state stays outside Git and is protected against unauthorized access and concurrent writes.
- Validation results and known limitations are recorded.
- Teardown removes the lab resources, and any retained backend resources are identified and handled separately.
- The documentation explains the network path, permissions, cost assumptions, and main tradeoffs.

## Security and repository hygiene

Never commit AWS credentials, access tokens, login caches, Terraform state, saved plan files, or configuration containing secrets. Treat outputs and screenshots as potentially sensitive before adding them to the repository.

Future automation should validate changes before deployment. Provider scaffolds and local validation instructions are available now. AWS resource definitions, CI workflows, and deployment commands will be added in later phases.

## Planned portfolio evidence

- Architecture diagram and decision records.
- README with reproducible setup, verification, and teardown steps.
- Terraform validation and security-check results.
- Evidence of a successful deployment, controlled change, and cleanup.
- A short demonstration that explains what was built and why.
