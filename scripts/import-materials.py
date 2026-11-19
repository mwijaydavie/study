"""File personal PDFs by module and build a private, portable copy of the folders."""

from argparse import ArgumentParser
from pathlib import Path
from shutil import copy2
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / 'study-materials' / '2026-27' / 'semester-1'
FILES = {
    'CoEIT_BIT_Weekly_Class_Timetable_2026_2027 UPDATED REVISED DRAFT.pdf': '00-timetable/source/coeit-bit-revised-draft.pdf',
    'Introduction-OOAD.pdf': 'IS274-ooad/source/introduction-ooad.pdf',
    'COMPLETE GROUPS WORK.pdf': 'IS264-databases/source/complete-groups-work.pdf',
    'UNIT I.pdf': 'networking-unconfirmed/source/unit-01-ip-fundamentals.pdf',
    'UNIT II.pdf': 'networking-unconfirmed/source/unit-02-subnetting.pdf',
}
DOWNLOAD_DIRS = {
    'bit-year-2-timetable.pdf': '00-timetable',
    'bit-year-2-study-planner.docx': '00-timetable',
    'is274-ooad-revision.pptx': 'IS274-ooad',
}


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('uploads', type=Path, help='Directory containing the five original PDF files')
    uploads = parser.parse_args().uploads
    missing = [name for name in FILES if not (uploads / name).is_file()]
    if missing:
        parser.error('Missing input: ' + ', '.join(missing))
    for name, relative in FILES.items():
        destination = LIBRARY / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        copy2(uploads / name, destination)
        print(f'{name} -> {relative}')

    zip_path = ROOT / 'study-materials' / 'organized-materials.zip'
    with ZipFile(zip_path, 'w', ZIP_DEFLATED) as archive:
        for file in sorted(LIBRARY.rglob('*')):
            if file.is_file():
                archive.write(file, file.relative_to(LIBRARY.parent.parent))
        for name, folder in DOWNLOAD_DIRS.items():
            artifact = ROOT / 'public' / 'downloads' / name
            if artifact.is_file():
                archive.write(artifact, f'2026-27/semester-1/{folder}/{name}')
    print(zip_path.relative_to(ROOT))


if __name__ == '__main__':
    main()
