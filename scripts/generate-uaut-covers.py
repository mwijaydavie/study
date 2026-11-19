"""Build editable student submission covers from the ignored local profile and logo."""

import json
from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches as DIn, Pt as DPt, RGBColor as DRgb
from pptx import Presentation
from pptx.dml.color import RGBColor as PRgb
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches as PIn, Pt as PPt

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'study-materials' / 'private'
UNIVERSITY = 'The United African University of Tanzania'
INK, MUTED, FOREST, GOLD = '1B2929', '4D625A', '153E35', 'BF8D3B'
PAPER, WHITE = 'F1F6F3', 'FFFFFF'


def word_cover(path, logo, programme, cohort, academic_session, fields):
    doc = Document()
    doc.core_properties.title = 'UAUT academic submission cover'
    doc.core_properties.subject = 'Editable student coursework cover sheet'
    doc.core_properties.author = 'StudyDesk'
    section = doc.sections[0]
    section.page_width, section.page_height = DIn(8.27), DIn(11.69)
    section.left_margin = section.right_margin = DIn(.81)
    section.top_margin, section.bottom_margin = DIn(.72), DIn(.71)
    section.footer_distance = DIn(.45)
    normal = doc.styles['Normal']
    normal.font.name, normal.font.size = 'Aptos', DPt(11)
    normal.paragraph_format.space_after = DPt(0)

    def line(paragraph, text, size, *, color=INK, bold=False, before=0, after=0, center=False):
        f = paragraph.paragraph_format
        f.space_before, f.space_after = DPt(before), DPt(after)
        if center:
            paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = paragraph.add_run(text)
        run.font.name, run.font.size = 'Aptos', DPt(size)
        run.font.bold, run.font.color.rgb = bold, DRgb.from_string(color)
        return paragraph

    def band(paragraph):
        # Word-native accent rule so the cover remains editable and prints sharply.
        fmt = paragraph.paragraph_format
        fmt.left_indent = fmt.right_indent = DIn(2.62)
        borders = OxmlElement('w:pBdr')
        edge = OxmlElement('w:bottom')
        for key, value in {'val': 'single', 'sz': '16', 'space': '2', 'color': GOLD}.items():
            edge.set(qn(f'w:{key}'), value)
        borders.append(edge)
        paragraph._p.get_or_add_pPr().append(borders)
        line(paragraph, ' ', 3, before=14, after=5)

    def table(rows):
        grid = doc.add_table(rows=rows, cols=2)
        grid.autofit = False
        grid.alignment = WD_TABLE_ALIGNMENT.CENTER
        for col in grid.columns:
            col.width = DIn(3.32)
        for i, row in enumerate(grid.rows):
            for cell in row.cells:
                cell.width = DIn(3.32)
                cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
                tc = cell._tc.get_or_add_tcPr()
                fill = OxmlElement('w:shd')
                fill.set(qn('w:fill'), FOREST if rows == 1 else PAPER if i % 2 == 0 else 'F9FBF9')
                tc.append(fill)
                margins = OxmlElement('w:tcMar')
                for position, amount in (('top', '164'), ('bottom', '164'), ('left', '244'), ('right', '244')):
                    margin = OxmlElement(f'w:{position}')
                    margin.set(qn('w:w'), amount)
                    margin.set(qn('w:type'), 'dxa')
                    margins.append(margin)
                tc.append(margins)
        return grid

    left, right = table(1).rows[0].cells
    line(left.paragraphs[0], 'ACADEMIC SUBMISSION', 10, color=WHITE, bold=True)
    label = line(right.paragraphs[0], f'UAUT  /  {cohort.upper()}', 10, color='F1D499', bold=True)
    label.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    art = doc.add_paragraph()
    art.alignment = WD_ALIGN_PARAGRAPH.CENTER
    art.paragraph_format.space_before = DPt(29)
    art.paragraph_format.space_after = DPt(13)
    picture = art.add_run().add_picture(str(logo), height=DIn(1.82))
    picture._inline.docPr.set('descr', f'{UNIVERSITY} logo')
    line(doc.add_paragraph(), UNIVERSITY, 18, bold=True, center=True, after=5)
    line(doc.add_paragraph(), programme, 10.75, color=MUTED, center=True)
    band(doc.add_paragraph())
    line(doc.add_paragraph(), '[Assignment or report title]', 32, bold=True, before=13, after=7, center=True)
    line(doc.add_paragraph(), '[Assignment type or task number]', 11.5, color=MUTED, after=29, center=True)

    details = table(3)
    for i, (label, value) in enumerate(fields + [('ACADEMIC SESSION', academic_session)]):
        target = details.cell(i // 2, i % 2)
        line(target.paragraphs[0], label, 9, color=MUTED, bold=True, after=4)
        line(target.add_paragraph(), value, 12, bold=True)
    line(section.footer.paragraphs[0], 'UAUT  /  STUDENT COURSEWORK', 9, color=MUTED, center=True)
    doc.save(path)


def slide_cover(path, logo, cohort, academic_session, fields):
    deck = Presentation()
    deck.slide_width, deck.slide_height = PIn(13.333333), PIn(7.5)
    deck.core_properties.title = 'UAUT academic presentation cover'
    deck.core_properties.subject = 'Editable title slide for student coursework'
    deck.core_properties.author = 'StudyDesk'
    slide = deck.slides.add_slide(deck.slide_layouts[6])
    slide.background.fill.solid()
    slide.background.fill.fore_color.rgb = PRgb.from_string(WHITE)

    def box(x, y, w, h, color, rounded=False):
        obj = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if rounded else MSO_SHAPE.RECTANGLE, PIn(x), PIn(y), PIn(w), PIn(h))
        obj.fill.solid()
        obj.fill.fore_color.rgb = PRgb.from_string(color)
        obj.line.fill.background()
        if rounded:
            obj.adjustments[0] = .10

    def text(x, y, w, h, label, size, *, color=INK, bold=False, center=False):
        tf = slide.shapes.add_textbox(PIn(x), PIn(y), PIn(w), PIn(h)).text_frame
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
        tf.word_wrap = True
        p = tf.paragraphs[0]
        if center:
            p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = label
        run.font.name, run.font.size, run.font.bold = 'Aptos', PPt(size), bold
        run.font.color.rgb = PRgb.from_string(color)

    rail_x = 8.93
    rail_center = (rail_x + 13.333333) / 2
    box(rail_x, 0, 13.333333 - rail_x, 7.5, FOREST)
    box(rail_x, 0, .055, 7.5, GOLD)
    box(rail_center - 1.31, 1.30, 2.62, 3.41, WHITE, rounded=True)
    art_h = 2.79
    # Insert by height to preserve the original transparent PNG's proportions.
    picture = slide.shapes.add_picture(str(logo), 0, PIn(1.61), height=PIn(art_h))
    picture.left = PIn(rail_center) - picture.width // 2
    picture._element.nvPicPr.cNvPr.set('descr', f'{UNIVERSITY} logo')
    text(rail_x + .32, 5.10, 3.76, .35, cohort.upper(), 16, color=WHITE, bold=True, center=True)
    text(rail_x + .32, 5.64, 3.76, .36, academic_session, 12, color='F1D499', center=True)

    text(.73, .64, 7.75, .33, 'UAUT  /  COURSEWORK PRESENTATION', 12, color=MUTED, bold=True)
    text(.73, 1.18, 7.75, .39, UNIVERSITY, 18, bold=True)
    box(.73, 1.77, .74, .045, GOLD)
    text(.70, 2.02, 7.74, 1.50, '[Presentation title]', 40, bold=True)
    text(.74, 3.52, 7.70, .45, '[Optional subtitle or task number]', 14, color=MUTED)
    box(.73, 4.13, 7.61, .014, 'D7E3DD')
    for i, (label, value) in enumerate(fields):
        x = .73 + 3.86 * (i % 2)
        y = 4.42 + .89 * (i // 2)
        text(x, y, 3.60, .23, 'PRESENTER' if label == 'PREPARED BY' else label, 10, color=MUTED, bold=True)
        text(x, y + .28, 3.60, .56, value, 14, bold=True)
    deck.save(path)


def main():
    profile_path, logo = PRIVATE / 'profile.json', PRIVATE / 'logo.png'
    if not (profile_path.is_file() and logo.is_file()):
        raise SystemExit('Add profile.json and the supplied logo.png to study-materials/private first (see README).')
    profile = json.loads(profile_path.read_text(encoding='utf-8'))
    name, identifier = profile.get('student_name'), profile.get('student_id')
    if not all(isinstance(value, str) and value.strip() for value in (name, identifier)):
        raise SystemExit('Profile must provide nonempty student_name and student_id strings.')
    semester = json.loads((ROOT / 'src/data/semester.json').read_text(encoding='utf-8'))
    session = f"{semester['term']} · {semester['year']}"
    fields = [
        ('PREPARED BY', name.strip()), ('STUDENT ID', identifier.strip()),
        ('COURSE', '[Course code and name]'), ('SUBMITTED TO', '[Lecturer or supervisor]'),
        ('SUBMISSION DATE', '[Day Month Year]'),
    ]
    covers = PRIVATE / 'covers'
    covers.mkdir(mode=0o700, exist_ok=True)
    docx, pptx = covers / 'uaut-assignment-cover.docx', covers / 'uaut-presentation-cover.pptx'
    word_cover(docx, logo, semester['program'], semester['cohort'], session, fields)
    slide_cover(pptx, logo, semester['cohort'], session, fields)
    for file in (docx, pptx):
        file.chmod(0o600)
        print(file.relative_to(ROOT))


if __name__ == '__main__':
    main()
