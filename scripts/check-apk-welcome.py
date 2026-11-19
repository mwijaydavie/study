"""Ensure Android can open the five bundled speech clips as raw file descriptors."""

import sys
from zipfile import ZIP_STORED, ZipFile

NAMES = ('karibu', 'mambo', 'welcome', 'inakuaje', 'tujipime')

with ZipFile(sys.argv[1]) as apk:
    for name in NAMES:
        entry = f'res/raw/welcome_{name}.mp3'
        try:
            clip = apk.getinfo(entry)
        except KeyError:
            sys.exit(f'Missing APK greeting: {entry}')
        if clip.compress_type != ZIP_STORED or clip.file_size < 1024:
            sys.exit(f'APK greeting is compressed or empty: {entry}')
    print(f'Checked {len(NAMES)} uncompressed APK greeting clips.')
