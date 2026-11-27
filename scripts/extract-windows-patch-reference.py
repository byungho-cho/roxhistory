"""Extract and pin the exact embedded Godot pack from a verified Windows build."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct


def digest(file):
    with file.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def extract(exe, reference, pin, manifest, base_commit, runtime):
    build = json.loads(manifest.read_text(encoding='utf-8-sig'))
    entry, = [row for row in build['files'] if row['name'] == exe.name]
    version = build['version']
    if (exe.name != f'Roxhistory_{version}.exe' or entry['size'] != exe.stat().st_size or
            entry['sha256'] != digest(exe) or not re.fullmatch('[0-9a-f]{40}', build['commit']) or
            not re.fullmatch('[0-9a-f]{40}', base_commit)):
        raise ValueError('The executable does not match the Windows build manifest.')
    if reference.exists() or pin.exists():
        raise FileExistsError('Preserve the existing baseline reference and pin.')
    header = struct.Struct('<4s5I2Q')
    exe_size = exe.stat().st_size
    with exe.open('rb') as source:
        source.seek(-12, 2)
        length, magic = struct.unpack('<Q4s', source.read(12))
        start = exe_size - 12 - length
        if magic != b'GDPC' or length < 112 or start <= 0:
            raise ValueError('No embedded Godot pack footer was found.')
        source.seek(start)
        meta = header.unpack(source.read(header.size))
        if meta[:7] != (b'GDPC', 3, 4, 5, 1, 2, 112) or not 112 < meta[-1] < length:
            raise ValueError('The embedded Godot pack has an incompatible layout.')
        source.seek(start)
        exact = hashlib.sha256()
        remaining = length
        with reference.open('xb') as target:
            while remaining:
                chunk = source.read(min(1 << 20, remaining))
                if not chunk:
                    raise ValueError('The embedded Godot pack is truncated.')
                target.write(chunk)
                exact.update(chunk)
                remaining -= len(chunk)
    if reference.stat().st_size != length or digest(reference) != exact.hexdigest():
        raise ValueError('The extracted resource pack differs from the installed executable.')
    report = {
        'base': version, 'base_commit': base_commit, 'runtime': runtime, 'build_commit': build['commit'],
        'exe_file': exe.name, 'exe_size': entry['size'], 'exe_sha256': entry['sha256'],
        'reference_file': reference.name, 'reference_size': length, 'reference_sha256': exact.hexdigest(),
        'exe_reference_exact': True,
    }
    pin.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(f'{reference.name}: {length} exact embedded bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ('exe', 'reference', 'pin', 'manifest'):
        parser.add_argument(field, type=Path)
    parser.add_argument('base_commit')
    parser.add_argument('runtime')
    args = parser.parse_args()
    extract(**vars(args))
