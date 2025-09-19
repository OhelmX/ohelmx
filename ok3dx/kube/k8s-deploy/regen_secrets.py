#!/usr/bin/env python3
"""
Script to update Kubernetes Secret JSON files with generated passwords.
Multi-pwgen labels version, using JSON.

Usage: python pwgen_secrets_json.py <input_dir> <output_dir>
"""

import hashlib
import hmac
import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path
import uuid as uuid_module
import secrets
import string

USE_CL_OPENSSL = False
ANNOTATION_KEY_PREFIX = 'ok3dx/pwgen'


try:
    from Crypto.PublicKey import RSA # type: ignore
except ImportError:
    USE_CL_OPENSSL = True


def rsa_private_key(bits: int = 2048):
    """
    Export an RSA private key in PEM format.
    """
    if USE_CL_OPENSSL:
        try:
            result = subprocess.run(
                ['openssl', 'genrsa', str(bits)],
                capture_output=True, text=True, check=True
            )
            return result.stdout
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"openssl genrsa failed: {e}")
    else:
        key = RSA.generate(bits) # type: ignore
        return key.export_key().decode()


def uid_master_hash(master_key: str, uid: str) -> str:
    """
    Hash a key UID and master key to generate an API key

    This is used specifically for meilisearch.
    Source: https://www.meilisearch.com/docs/reference/api/keys#key
    """
    return hmac.new(master_key.encode(), uid.encode(), hashlib.sha256).hexdigest()


def uuid(size: int) -> str:
    """
    Return a random uuid string with a given size.
    """
    fn = getattr(uuid_module, f"uuid{size}")
    return str(fn())


def ascii_secret(length):
    """
    Generate an ASCII secret of the given length.
    """
    return "".join(
        [secrets.choice(string.ascii_letters + string.digits) for _ in range(length)]
    )


def hex_secret(length):
    """
    Generate a hex secret of the given length.
    """
    return "".join(
        [secrets.choice(string.hexdigits[:-1]) for _ in range(length)]
    )


def generate_password(func_name, *args):
    """
    Generate a password using the specified function.
    """
    generators = {
        "ascii_secret": ascii_secret,
        "hex_secret": hex_secret,
        "uuid": uuid,
        "uid_master_hash": uid_master_hash,
        "rsa_private_key": rsa_private_key,
    }
    if func_name not in generators:
        raise ValueError(f"Unknown password generator: {func_name}")
    return generators[func_name](*args)


def process_secret_json(data, pwgen_specs):
    """
    Process a Secret JSON dict and update passwords for multiple specs.
    pwgen_specs is a list of (label_key, pwgen_value) sorted by label_key.
    """
    if not isinstance(data, dict) or data.get('kind') != 'Secret':
        return data

    string_data = data.get('stringData', {})

    generated = {}  # stringData key -> generated password

    for label_key, pwgen_value in pwgen_specs:
        parts = pwgen_value.split('|')
        if len(parts) < 3:
            print(f"Invalid pwgen label format in {label_key}: {pwgen_value}")
            continue

        key = parts[0]
        pattern = parts[1]
        func_name = parts[2]
        args_str = parts[3:]

        # Parse args: if int, keep as int; if in generated, use generated value; else treat as string
        parsed_args = []
        for arg in args_str:
            try:
                parsed_args.append(int(arg))
            except ValueError:
                if arg in generated:
                    parsed_args.append(generated[arg])
                else:
                    parsed_args.append(arg)  # or error

        if key not in string_data:
            print(f"Key '{key}' not found in stringData for {label_key}")
            continue

        value = string_data[key]
        if not isinstance(value, str):
            continue

        new_password = generate_password(func_name, *parsed_args)

        def replace_match(match):
            old_password = match.group(1)
            return match.group(0).replace(old_password, new_password)

        # Use MULTILINE only for multi-line blocks
        flags = 0  # For JSON, values are strings, no blocks
        updated_value = re.sub(pattern, replace_match, value, flags=flags)

        # If no replacement occurred, skip
        if updated_value == value:
            continue

        string_data[key] = updated_value
        generated[key] = new_password

    return data


def process_file(input_path, output_path, input_dir):
    """
    Process a single file: copy or update JSON if it's a Secret.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if input_path.suffix.lower() not in ['.json']:
        shutil.copy2(input_path, output_path)
        return

    try:
        with open(input_path, 'r') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error loading JSON {input_path}: {e}")
        shutil.copy2(input_path, output_path)
        return

    # Find all pwgen annotations starting with ANNOTATION_KEY_PREFIX
    metadata = data.get('metadata', {}) if isinstance(data, dict) else {}
    annotations = metadata.get('annotations', {})
    if not isinstance(annotations, dict):
        annotations = {}
    pwgen_specs = []
    for annotation_key, annotation_value in annotations.items():
        if annotation_key.startswith(ANNOTATION_KEY_PREFIX):
            if isinstance(annotation_value, str):
                pwgen_specs.append((annotation_key, annotation_value))

    if not pwgen_specs:
        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
        return

    # Sort by label key
    pwgen_specs.sort(key=lambda x: x[0])

    updated_data = process_secret_json(data, pwgen_specs)

    with open(output_path, 'w') as f:
        json.dump(updated_data, f, indent=2)


def main():
    parser = argparse.ArgumentParser(description='Update Kubernetes Secret JSON files with generated passwords.')
    parser.add_argument('input_dir', help='Input directory containing JSON files')
    parser.add_argument('output_dir', help='Output directory for updated files')
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)

    if not input_dir.is_dir():
        print(f"Input directory does not exist: {input_dir}")
        return

    output_dir.mkdir(parents=True, exist_ok=True)

    for root, dirs, files in os.walk(input_dir):
        for file in files:
            input_file = Path(root) / file
            relative_path = input_file.relative_to(input_dir)
            output_file = output_dir / relative_path
            process_file(input_file, output_file, input_dir)


if __name__ == '__main__':
    main()
