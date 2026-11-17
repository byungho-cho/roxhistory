"""Build a streaming recipe that recreates the exact cumulative Godot PCK."""
import argparse
import struct
from pathlib import Path

BLOCK = 4096
LITERAL = 0xFFFFFFFF


def build(source, target):
    position = 0
    source_hint = 0
    copied_offset = 0
    copied_size = 0
    literals = bytearray()
    result = bytearray(b"RDX1")
    while position < len(target):
        block = target[position:position + BLOCK]
        match = -1
        if len(block) == BLOCK:
            if source.startswith(block, source_hint):
                match = source_hint
            else:
                match = source.find(block, max(0, source_hint - 65536), source_hint + 65536)
                if match < 0:
                    match = source.find(block)
        if match < 0:
            if copied_size:
                result.extend(struct.pack("<II", copied_offset, copied_size))
                copied_size = 0
            literals.extend(block)
            source_hint += len(block)
        else:
            if literals:
                result.extend(struct.pack("<II", LITERAL, len(literals)))
                result.extend(literals)
                literals.clear()
            if copied_size and copied_offset + copied_size != match:
                result.extend(struct.pack("<II", copied_offset, copied_size))
                copied_size = 0
            if not copied_size:
                copied_offset = match
            copied_size += len(block)
            source_hint = match + len(block)
        position += len(block)
    if copied_size:
        result.extend(struct.pack("<II", copied_offset, copied_size))
    if literals:
        result.extend(struct.pack("<II", LITERAL, len(literals)))
        result.extend(literals)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.write_bytes(build(args.source.read_bytes(), args.target.read_bytes()))


if __name__ == "__main__":
    main()
