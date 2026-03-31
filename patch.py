#!/usr/bin/env python3
"""
dzialaj-mi-tam: Patch Claude Code spinner verbs.

Replaces the English spinner verbs ("Thinking", "Pondering", etc.)
with custom ones from verbs.json.

Works on macOS (arm64/x86) with Bun-compiled Claude Code binaries.
"""
import json
import os
import platform
import shutil
import struct
import subprocess
import sys
import tempfile

ENTRY_HEADER = b'\x10\x00\x00\x00\x00\x00\x00\x00\x09\x00\x00\x00'
FIRST_VERB = b'Accomplishing'


def find_binary():
    candidates = [
        os.path.expanduser("~/.local/share/claude/versions"),
        os.path.expanduser("~/.claude/versions"),
    ]
    for d in candidates:
        if not os.path.isdir(d):
            continue
        versions = sorted(
            [f for f in os.listdir(d) if not f.endswith('.backup')],
            key=lambda f: os.path.getmtime(os.path.join(d, f)),
            reverse=True
        )
        for v in versions:
            path = os.path.join(d, v)
            if os.path.isfile(path) and os.access(path, os.X_OK):
                return path
    result = shutil.which("claude")
    if result:
        real = os.path.realpath(result)
        if os.path.isfile(real):
            return real
    return None


def load_verbs(verbs_file):
    with open(verbs_file, 'r', encoding='utf-8') as f:
        verbs = json.load(f)
    if not isinstance(verbs, list) or len(verbs) == 0:
        print("Error: verbs.json must be a non-empty JSON array of strings")
        sys.exit(1)
    return verbs


def find_verb_arrays(data):
    arrays = []
    start = 0
    while True:
        idx = data.find(FIRST_VERB, start)
        if idx == -1:
            break
        header_start = idx - 16
        if header_start >= 0 and data[header_start:header_start + 12] == ENTRY_HEADER:
            arrays.append(header_start)
        start = idx + len(FIRST_VERB)
    return arrays


def patch_array(data, array_start, verbs):
    pos = array_start
    patched = 0
    verb_idx = 0

    while True:
        if data[pos:pos + 8] != b'\x10\x00\x00\x00\x00\x00\x00\x00':
            break

        str_len = struct.unpack_from('<I', data, pos + 12)[0]
        if str_len < 3 or str_len > 30:
            break

        padded_area = ((str_len + 15) // 16) * 16
        slot_size = 16 + padded_area

        old_str = data[pos + 16:pos + 16 + str_len].decode('utf-8', errors='replace')

        new_str = verbs[verb_idx % len(verbs)]
        new_bytes = new_str.encode('utf-8')
        new_len = len(new_bytes)
        new_padded = ((new_len + 15) // 16) * 16

        if new_padded > padded_area:
            fits = [v for v in verbs if ((len(v.encode('utf-8')) + 15) // 16) * 16 <= padded_area]
            if fits:
                new_str = fits[verb_idx % len(fits)]
                new_bytes = new_str.encode('utf-8')
                new_len = len(new_bytes)
            else:
                new_bytes = new_bytes[:padded_area - 1]
                new_len = len(new_bytes)

        struct.pack_into('<I', data, pos + 12, new_len)

        for i in range(padded_area):
            data[pos + 16 + i] = new_bytes[i] if i < new_len else 0

        patched += 1
        verb_idx += 1
        pos += slot_size

    return patched


def extract_entitlements(binary_path):
    tmp = tempfile.NamedTemporaryFile(suffix='.plist', delete=False)
    tmp.close()
    subprocess.run(
        ['codesign', '-d', '--entitlements', tmp.name, '--xml', binary_path],
        capture_output=True
    )
    if os.path.getsize(tmp.name) == 0:
        with open(tmp.name, 'w') as f:
            f.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
                    '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
                    '<plist version="1.0"><dict>\n'
                    '<key>com.apple.security.cs.allow-jit</key><true/>\n'
                    '<key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>\n'
                    '<key>com.apple.security.cs.disable-library-validation</key><true/>\n'
                    '</dict></plist>')
    return tmp.name


def resign(binary_path, entitlements_path):
    subprocess.run(['codesign', '--remove-signature', binary_path],
                   capture_output=True)
    result = subprocess.run(
        ['codesign', '-f', '-s', '-', '--entitlements', entitlements_path,
         '--options', 'runtime', binary_path],
        capture_output=True, text=True
    )
    return result.returncode == 0


def do_patch(verbs_file):
    binary = find_binary()
    if not binary:
        print("Could not find Claude Code binary.")
        sys.exit(1)

    print(f"Binary: {binary}")

    backup = binary + '.backup'
    if not os.path.exists(backup):
        print(f"Backup: {backup}")
        shutil.copy2(binary, backup)
    else:
        print(f"Backup already exists: {backup}")

    verbs = load_verbs(verbs_file)
    print(f"Loaded {len(verbs)} verbs")

    if platform.system() == 'Darwin':
        entitlements = extract_entitlements(binary)
    else:
        entitlements = None

    with open(binary, 'rb') as f:
        data = bytearray(f.read())

    arrays = find_verb_arrays(data)
    if not arrays:
        print("Could not find verb arrays in binary. Is this Claude Code >= 2.x?")
        sys.exit(1)

    print(f"Found {len(arrays)} verb array(s)")

    total = 0
    for i, offset in enumerate(arrays):
        count = patch_array(data, offset, verbs)
        print(f"  Array {i}: {count} verbs patched")
        total += count

    with open(binary, 'wb') as f:
        f.write(data)

    if platform.system() == 'Darwin' and entitlements:
        print("Re-signing binary (macOS)...")
        if resign(binary, entitlements):
            print("Signed OK")
        else:
            print("Signing failed! Restoring backup...")
            shutil.copy2(backup, binary)
            sys.exit(1)
        os.unlink(entitlements)

    print(f"\nDone! {total} verbs patched.")
    print(f"Restore original: python3 patch.py --restore")


def do_restore():
    binary = find_binary()
    if not binary:
        print("Could not find Claude Code binary.")
        sys.exit(1)

    backup = binary + '.backup'
    if not os.path.exists(backup):
        print("No backup found. Nothing to restore.")
        sys.exit(1)

    shutil.copy2(backup, binary)
    print(f"Restored: {binary}")


def find_any_verb_array(data):
    """Find verb array by structural pattern (works on patched binaries too)."""
    known_verbs = [b'Thinking', b'Pondering', b'Ogarnianie', b'Pierdolenie',
                   b'Kminienie', b'Kombinowanie', b'Working', b'Creating']
    for verb in known_verbs:
        start = 0
        while True:
            idx = data.find(verb, start)
            if idx == -1:
                break
            header_start = idx - 16
            if header_start >= 0 and data[header_start:header_start + 8] == b'\x10\x00\x00\x00\x00\x00\x00\x00':
                str_len = struct.unpack_from('<I', data, header_start + 12)[0]
                if str_len == len(verb):
                    scan = header_start
                    while scan >= 16:
                        prev = scan - 16
                        prev_padded = 16
                        found_prev = False
                        for try_back in range(64, 0, -16):
                            test = scan - try_back
                            if test < 0:
                                continue
                            if data[test:test + 8] == b'\x10\x00\x00\x00\x00\x00\x00\x00':
                                tl = struct.unpack_from('<I', data, test + 12)[0]
                                if 3 <= tl <= 30:
                                    tp = ((tl + 15) // 16) * 16
                                    if test + 16 + tp == scan:
                                        scan = test
                                        found_prev = True
                                        break
                        if not found_prev:
                            break
                    return [scan]
            start = idx + len(verb)
    return []


def do_list():
    binary = find_binary()
    if not binary:
        print("Could not find Claude Code binary.")
        sys.exit(1)

    with open(binary, 'rb') as f:
        data = bytearray(f.read())

    arrays = find_verb_arrays(data)
    if not arrays:
        arrays = find_any_verb_array(data)
    if not arrays:
        print("No verb arrays found.")
        sys.exit(1)

    pos = arrays[0]
    while True:
        if data[pos:pos + 8] != b'\x10\x00\x00\x00\x00\x00\x00\x00':
            break
        str_len = struct.unpack_from('<I', data, pos + 12)[0]
        if str_len < 3 or str_len > 30:
            break
        padded_area = ((str_len + 15) // 16) * 16
        print(data[pos + 16:pos + 16 + str_len].decode('utf-8', errors='replace'))
        pos += 16 + padded_area


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--restore':
        do_restore()
        return

    if len(sys.argv) > 1 and sys.argv[1] == '--list':
        do_list()
        return

    script_dir = os.path.dirname(os.path.abspath(__file__))
    verbs_file = os.path.join(script_dir, 'verbs.json')

    if len(sys.argv) > 1 and not sys.argv[1].startswith('-'):
        verbs_file = sys.argv[1]

    if not os.path.exists(verbs_file):
        print(f"Verbs file not found: {verbs_file}")
        sys.exit(1)

    do_patch(verbs_file)


if __name__ == '__main__':
    main()
