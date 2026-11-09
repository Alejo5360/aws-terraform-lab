# Cost review: temporary AWS lab

Reviewed on **2026-11-06** for **us-east-2 (Ohio)**. This is a planning estimate, not an AWS bill or an authorization to deploy.

## Decision

Keep the EC2-based lab, funded by the active Free plan and its credits. Use short practice sessions and destroy the workload after each session. The requirement is **zero out-of-pocket spending**; compute and storage still have metered prices and can consume credits.

A read-only check confirmed FREE / ACTIVE on the review date. The selected Region was confirmed from the CLI profile. Exact project identifiers, credentials, and credit balances are excluded from this repository. Recheck the live plan, remaining credits, and expiration before any deployment.

[AWS's plan documentation](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html) describes the Free plan's no-charge period and its end when credits or the plan duration run out. Do not upgrade the plan, activate advanced features, join Organizations, or purchase commitments to complete this lab.

EC2, EBS, VPC, S3, IAM, and Systems Manager appear on the [supported Free Tier services list for the new AWS experience](https://docs.aws.amazon.com/accounts/latest/reference/supported-services-sign-up-new.html). The EC2 API marked both t3.micro and t4g.micro Free Tier eligible and offered them in Ohio. Eligibility does not mean an unlimited zero-dollar service rate. An empty Free Tier usage response does not prove that no other AWS costs exist.

## Verified rates

These USD On-Demand rates were retrieved using AWS Price List GetProducts. The API endpoint was us-east-1; the priced resources are in us-east-2. That catalog lookup does not deploy resources in another Region. [The snapshot](pricing-us-east-2.json) records service codes, product SKUs, usage types, conditions, and effective dates.

| Item | Rate | Source |
| --- | --- | --- |
| Linux t3.micro, shared tenancy | $0.0104 / hour | [EC2](https://aws.amazon.com/ec2/pricing/on-demand/) |
| Linux t4g.micro, ARM alternative | $0.0084 / hour | [EC2](https://aws.amazon.com/ec2/pricing/on-demand/) |
| gp3 provisioned storage, baseline performance | $0.08 / GB-month | [EBS](https://aws.amazon.com/ebs/pricing/) |
| One in-use public IPv4 address | $0.005 / hour | [VPC](https://aws.amazon.com/vpc/pricing/) |
| S3 Standard, first storage tier | $0.023 / GB-month | [S3](https://aws.amazon.com/s3/pricing/) |
| S3 PUT / COPY / POST / LIST | $0.005 / 1,000 requests | [S3](https://aws.amazon.com/s3/pricing/) |
| S3 GET and other Tier 2 requests | $0.0004 / 1,000 requests | [S3](https://aws.amazon.com/s3/pricing/) |
| Ohio internet egress, first paid tier | $0.09 / GB | [EC2 transfer](https://aws.amazon.com/ec2/pricing/on-demand/) |
| Session Manager for this EC2 instance | No additional session charge | [Systems Manager](https://aws.amazon.com/systems-manager/pricing/) |

AWS currently includes 100 GB of monthly internet egress aggregated across services and Regions, with regional exclusions documented on the EC2 pricing page. The conservative column below assumes that allowance is unavailable; it is not a second allowance per resource.

## Sizing assumptions

- One Linux t3.micro in standard CPU-credit mode, one encrypted 8 GiB gp3 root volume, baseline 3,000 IOPS and 125 MiB/s, and one auto-assigned public IPv4 address.
- Twenty running hours per month, for example ten two-hour practice sessions. Bootstrapping and verification time must fit inside those hours.
- A 730-hour planning month. EBS proration is an estimate; AWS bills actual provisioned time and the relevant monthly interval.
- One persistent S3 Standard state backend averaging 0.1 GB of billable storage, including all object versions, plus 1,000 Tier 1 and 10,000 Tier 2 requests per month. Requests and storage continue to count while EC2 is absent.
- One GB of total outbound traffic. Package downloads are inbound; larger outbound tests need a new estimate.
- No paid AMI, extra disk, snapshot, Elastic IP allocation, NAT Gateway, load balancer, interface endpoint, custom KMS key, enhanced monitoring, or separate logging service is included.
- Prices exclude taxes, unrelated project workloads, future price changes, and usage above these assumptions. A monthly spending target does not enforce a technical limit.

## Calculated scenarios

| Operating pattern | EC2 hours | EBS provisioned hours | IPv4 hours | Before paid egress | Including 1 GB at the paid egress rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| Destroy workload after sessions | 20 | 20 | 20 | $0.34 | **$0.43** |
| Stop EC2 but retain its root disk | 20 | 730 | 20 | $0.96 | $1.05 |
| Leave workload running | 730 | 730 | 730 | $11.89 | $11.98 |

The recommended row has $0.208 compute + $0.01753425 EBS + $0.10 IPv4 + $0.0113 S3 + $0.09 conservative egress = $0.42683425, rounded to $0.43. Sum unrounded amounts before rounding the total.

Stopping an instance does not remove the EBS disk. The stop scenario assumes an auto-assigned IPv4 address is released while stopped; retaining an allocated Elastic IP would change the estimate. See [EC2 stop/start behavior](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Stop_Start.html).

For 20 compute hours, switching to t4g.micro saves $0.04 in compute charges. Keep t3.micro for the first version's x86 compatibility; an ARM AMI and compatible software are required for t4g. This is an initial design choice, not an assertion that Nginx cannot run on ARM.

### Reproduce the arithmetic offline

No AWS calls, credentials, packages, or paid APIs are used by this calculator:

```sh
python scripts/estimate_costs.py
python scripts/estimate_costs.py --remaining-free-egress-gb 100
python scripts/estimate_costs.py --instance t4g.micro
```

The first command is conservative ($0.43 for the recommended row); the second applies an explicitly assumed remaining transfer allowance ($0.34). Update and re-verify the public pricing snapshot before reusing this estimate after prices change.

## Operating limits for v1

Use a **$1 monthly gross-consumption target**, a **20-hour monthly running-time target**, and sessions of **at most two hours**. These are proposed operator rules, not an AWS spend cap or an automated shutdown mechanism.

Before each future apply, require FREE / ACTIVE, us-east-2, an unexpired plan covering the session, and credits sufficient for expected remaining work plus at least $1 of headroom. If any condition fails, stop and revise the plan; never upgrade automatically. Check AWS Settings > Billing for current spend and AWS Settings > View all projects > Overview > Additional Info > Region for the selected Region.

After each future session, review the workload destroy plan, destroy the lab resources when authorized, and verify the instance, its EBS volume, and public address were removed. Leave the separately managed S3 state backend only while it is needed. At project closure, export any required records securely and clean up the backend separately after confirming that no live resources depend on its state.

AWS budgets and alerts are notifications, not a general-purpose guaranteed kill switch. No budget, alert, scheduler, Cost Explorer query, or deployment was created during this review.

Repository preparation and version pinning are recorded in [the local-development guide](local-development.md). Protected bootstrap code and offline tests were completed on 2026-11-09; see [the bootstrap runbook](bootstrap.md). Live preflight, deployment, and migration remain separate steps. This implementation does not refresh the dated credit balance or price snapshot.
