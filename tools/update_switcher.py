#!/usr/bin/env python3
"""
Update switcher.json with a new version entry.

This script updates the version switcher configuration for documentation
when a new release is published.
"""

import json
import argparse
import sys
import os


def update_switcher_json(switcher_path, version):
    """
    Update switcher.json with a new version entry.
    
    Args:
        switcher_path (str): Path to the switcher.json file
        version (str): Version to add (without 'v' prefix)
    """
    # Read the current switcher.json
    try:
        with open(switcher_path, 'r') as f:
            switcher = json.load(f)
    except FileNotFoundError:
        print(f"Error: switcher.json not found at {switcher_path}")
        return False
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in switcher.json: {e}")
        return False

    # Update the stable version reference
    for item in switcher:
        if "stable" in item.get("name", ""):
            item["name"] = f"v{version} (stable)"
            item["version"] = f"v{version} (stable)"
            break

    # Add the new version if it doesn't exist
    version_exists = any(item.get("version", "").lstrip("v") == version for item in switcher)
    if not version_exists:
        new_entry = {
            "name": f"v{version}",
            "version": version,
            "url": f"https://ncar.github.io/music-box/versions/{version}"
        }
        # Insert before the dev entry (which should be last)
        switcher.insert(-1, new_entry)

    # Write the updated switcher.json
    try:
        with open(switcher_path, 'w') as f:
            json.dump(switcher, f, indent=2)
        print(f"Successfully updated switcher.json with version {version}")
        return True
    except Exception as e:
        print(f"Error writing switcher.json: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description='Update switcher.json with a new version')
    parser.add_argument('--switcher-path', required=True,
                        help='Path to the switcher.json file')
    parser.add_argument('--version', required=True,
                        help='Version to add (without v prefix)')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.switcher_path):
        print(f"Error: switcher.json not found at {args.switcher_path}")
        sys.exit(1)
    
    success = update_switcher_json(args.switcher_path, args.version)
    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()