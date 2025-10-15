#!/usr/bin/env python3
import json
import sys
from pathlib import Path

def convert_checkov_to_threat_report():
    """Convert Checkov results to threat report format"""
    checkov_file = Path("threat_modelling/reports/results_json.json")

    if not checkov_file.exists():
        print(f"Checkov results not found at {checkov_file}")
        sys.exit(0)

    with open(checkov_file) as f:
        checkov_data = json.load(f)

    threat_report = {
        "scan_date": checkov_data.get("summary", {}).get("parsing_errors", 0),
        "critical": [],
        "high": [],
        "medium": [],
        "low": []
    }

    # Process failed checks
    for result in checkov_data.get("results", {}).get("failed_checks", []):
        severity = result.get("severity", "MEDIUM").upper()

        threat = {
            "title": result.get("check_name", "Unknown Check"),
            "description": result.get("description", ""),
            "resource": result.get("resource", ""),
            "file_path": result.get("file_path", ""),
            "line_range": result.get("file_line_range", []),
            "guideline": result.get("guideline", "")
        }

        if severity == "CRITICAL":
            threat_report["critical"].append(threat)
        elif severity == "HIGH":
            threat_report["high"].append(threat)
        elif severity == "MEDIUM":
            threat_report["medium"].append(threat)
        else:
            threat_report["low"].append(threat)

    # Write threat report
    output_file = Path("threat_modelling/reports/pr-threats.json")
    with open(output_file, 'w') as f:
        json.dump(threat_report, f, indent=2)

    print(f"Threat report generated: {output_file}")
    print(f"Critical: {len(threat_report['critical'])}, High: {len(threat_report['high'])}")

if __name__ == "__main__":
    convert_checkov_to_threat_report()
