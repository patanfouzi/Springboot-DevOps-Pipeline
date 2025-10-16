#!/usr/bin/env python3
import json, sys

if len(sys.argv) < 2:
    print("Usage: tf-to-inventory.py path/to/tfoutput.json")
    sys.exit(1)

# Load Terraform JSON output
with open(sys.argv[1]) as f:
    obj = json.load(f)

def extract_ip(output_name):
    """Extract IP from Terraform output, handle lists."""
    if output_name not in obj:
        return None
    ip = obj[output_name].get('value')
    if isinstance(ip, list):
        ip = ip[0]
    return ip

# Extract IPs
app_ip = extract_ip('app_public_ip')
mysql_ip = extract_ip('mysql_public_ip')

# Generate Ansible inventory
if mysql_ip:
    print("[mysql]")
    print(f"{mysql_ip} ansible_user=ubuntu")
    print()

if app_ip:
    print("[app]")
    print(f"{app_ip} ansible_user=ubuntu")
    print()
