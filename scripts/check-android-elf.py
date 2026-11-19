#!/usr/bin/env python3
"""Inspect the packaged 64-bit libraries for Android 16 KiB page compatibility."""

import argparse
import re
import struct
import zipfile

PAGE_SIZE = 16 * 1024
LIBRARY = re.compile(r"lib/(arm64-v8a|x86_64)/[^/]+\.so\Z")


def check_library(archive, entry):
    with archive.open(entry) as lib:
        header = lib.read(64)
        if len(header) != 64 or header[:6] != b"\x7fELF\x02\x01":
            raise ValueError(f"{entry.filename}: expected a little-endian ELF64 library")
        start = struct.unpack_from("<Q", header, 32)[0]
        width, count = struct.unpack_from("<HH", header, 54)
        if start < 64 or width != 56 or not count or start + width * count > entry.file_size:
            raise ValueError(f"{entry.filename}: invalid ELF program headers")
        lib.seek(start)
        loads = 0
        for index in range(count):
            kind, _, offset, address, _, _, _, align = struct.unpack("<IIQQQQQQ", lib.read(width))
            if kind == 1:  # PT_LOAD
                loads += 1
                if align < PAGE_SIZE or (address - offset) % PAGE_SIZE:
                    raise ValueError(f"{entry.filename}: LOAD segment {index} is not 16 KiB aligned")
        if not loads:
            raise ValueError(f"{entry.filename}: no loadable segments found")
        print(f"16 KiB ELF OK: {entry.filename}")


def verify(apk):
    with zipfile.ZipFile(apk) as archive:
        entries = [entry for entry in archive.infolist() if LIBRARY.fullmatch(entry.filename)]
        if not any(entry.filename == "lib/arm64-v8a/libflutter.so" for entry in entries):
            raise ValueError("APK is missing the ARM64 Flutter engine")
        for entry in entries:
            check_library(archive, entry)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk")
    args = parser.parse_args()
    try:
        verify(args.apk)
    except (ValueError, OSError, zipfile.BadZipFile, struct.error) as error:
        parser.exit(1, f"Android ELF check failed: {error}\n")


if __name__ == "__main__":
    main()
