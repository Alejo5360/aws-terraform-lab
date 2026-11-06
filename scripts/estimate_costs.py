"""Offline cost scenarios using the reviewed Ohio price snapshot; makes no AWS calls."""

import argparse
import json
from decimal import Decimal
from pathlib import Path


def nonnegative(value):
    number = Decimal(value)
    if not number.is_finite() or number < 0:
        raise argparse.ArgumentTypeError("Use a finite, nonnegative number")
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hours", type=nonnegative, default=Decimal("20"))
    parser.add_argument("--month-hours", type=nonnegative, default=Decimal("730"))
    parser.add_argument("--outbound-gb", type=nonnegative, default=Decimal("1"))
    parser.add_argument("--remaining-free-egress-gb", type=nonnegative, default=Decimal("0"))
    parser.add_argument("--instance", choices=["t3.micro", "t4g.micro"], default="t3.micro")
    args = parser.parse_args()
    if args.month_hours <= 0 or args.hours > args.month_hours:
        parser.error("month-hours must be positive and at least hours")

    snapshot = json.loads((Path(__file__).resolve().parents[1] / "docs" / "pricing-us-east-2.json").read_text())
    rates = {key: Decimal(item["value"]) for key, item in snapshot["rates"].items()}
    compute_rate = rates["t3_micro_hour" if args.instance == "t3.micro" else "t4g_micro_hour"]
    state_cost = (
        Decimal("0.1") * rates["s3_standard_gb_month"]
        + Decimal("1000") * rates["s3_tier1_request"]
        + Decimal("10000") * rates["s3_tier2_request"]
    )
    transfer_cost = max(Decimal("0"), args.outbound_gb - args.remaining_free_egress_gb) * rates["internet_egress_gb"]
    scenarios = [
        ("destroy_after_sessions", args.hours, args.hours, args.hours),
        ("stop_but_retain_disk", args.hours, args.month_hours, args.hours),
        ("leave_running", args.month_hours, args.month_hours, args.month_hours),
    ]
    result = {"review_date": snapshot["review_date"], "currency": "USD", "instance": args.instance, "scenarios": {}}
    for name, compute_hours, disk_hours, ip_hours in scenarios:
        lines = {
            "compute": compute_hours * compute_rate,
            "ebs": Decimal("8") * rates["gp3_gb_month"] * disk_hours / args.month_hours,
            "ipv4": ip_hours * rates["public_ipv4_hour"],
            "s3": state_cost,
            "internet_egress": transfer_cost,
        }
        total = sum(lines.values())
        result["scenarios"][name] = {
            "line_items": {key: str(value) for key, value in lines.items()},
            "total_unrounded": str(total),
            "total_rounded": f"{total:.2f}",
        }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
