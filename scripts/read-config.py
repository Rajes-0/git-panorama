#!/usr/bin/env python3
"""
Configuration Reader Utility
Reads values from config.yaml for use in bash scripts.

Usage:
    python3 scripts/read-config.py <config_file> <key_path>

Examples:
    python3 scripts/read-config.py config.yaml "elasticsearch.host"
    python3 scripts/read-config.py config.yaml "elasticsearch.port"
    python3 scripts/read-config.py config.yaml "elasticsearch.bulk_batch_size"
"""

import sys
import yaml
from pathlib import Path


def read_config_value(config_file: str, key_path: str):
    """Read a value from config file using dot-notation path."""
    config_path = Path(config_file)
    
    if not config_path.exists():
        print(f"Error: Configuration file not found: {config_file}", file=sys.stderr)
        sys.exit(1)
    
    try:
        with config_path.open('r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
    except yaml.YAMLError as e:
        print(f"Error: Failed to parse YAML: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Navigate through nested keys
    keys = key_path.split('.')
    value = config
    
    try:
        for key in keys:
            value = value[key]
    except (KeyError, TypeError) as e:
        print(f"Error: Key path '{key_path}' not found in config", file=sys.stderr)
        sys.exit(1)
    
    # Print the value (bash will capture this)
    print(value)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 read-config.py <config_file> <key_path>", file=sys.stderr)
        print("Example: python3 read-config.py config.yaml 'elasticsearch.host'", file=sys.stderr)
        sys.exit(1)
    
    config_file = sys.argv[1]
    key_path = sys.argv[2]
    
    read_config_value(config_file, key_path)

