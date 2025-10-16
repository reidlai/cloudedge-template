#!/usr/bin/env python3
import json
from pathlib import Path

threat_file = Path("threat_modelling/reports/pr-threats.json")
with open(threat_file) as f:
    threats = json.load(f)

print("# Threat Modeling Summary\n")
print(f"**Critical**: {len(threats['critical'])}")
print(f"**High**: {len(threats['high'])}")
print(f"**Medium**: {len(threats['medium'])}")
print(f"**Low**: {len(threats['low'])}\n")

if threats['critical']:
    print("## Critical Threats\n")
    for threat in threats['critical']:
        print(f"- **{threat['title']}** ({threat['file_path']})")
        print(f"  - Resource: `{threat['resource']}`")
        print(f"  - {threat['description']}\n")
