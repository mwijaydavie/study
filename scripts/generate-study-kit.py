"""Regenerate the personal PDF, DOCX and PPTX shipped with StudyDesk.

Install PyMuPDF, python-docx and python-pptx to run this script. The timetable
and study-block times are read from the same data used by the website.
"""

from datetime import datetime, timezone
import json
from pathlib import Path

import pymupdf
from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches as DIn, Pt as DPt, RGBColor as DRgb
from pptx import Presentation
from pptx.dml.color import RGBColor as PRgb
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Inches as PIn, Pt as PPt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'public' / 'downloads'
SEMESTER = json.loads((ROOT / 'src/data/semester.json').read_text())
PLAN = json.loads((ROOT / 'src/data/plan.json').read_text())
COURSES = SEMESTER['courses']
DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
KIND = {'lecture': 'Lecture', 'practical': 'Practical / Tutorial', 'chapel': 'Campus activity'}
INK = '252539'
MUTED = '59596B'
GOLD = 'FFE6A4'
LILAC = 'EBE3FB'
GREEN = 'E1F0E6'
BLUE = 'E3EDFC'
PEACH = 'FAEADD'
PAPER = 'FBFAF7'
WHITE = 'FFFFFF'
PASTELS = {'blue': BLUE, 'green': GREEN, 'violet': LILAC, 'peach': PEACH}
DOC_NAME = 'BIT Year 2 study planner'
DECK_NAME = 'OOAD in plain language'
CREATED = datetime(2026, 11, 18, tzinfo=timezone.utc)


def pdf_color(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4))


def timetable_pdf():
    doc = pymupdf.open()
    width, height = pymupdf.paper_size('a4-l')
    page = doc.new_page(width=width, height=height)
    doc.set_metadata({'title': 'UAUT BIT Year 2 - Weekly Class Timetable', 'author': 'StudyDesk', 'subject': '2026/27 Semester 1 | Reworked from the revised draft, p. 2'})

    def box(x, y, w, h, fill, stroke=None):
        page.draw_rect(pymupdf.Rect(x, y, x + w, y + h), fill=pdf_color(fill), color=pdf_color(stroke) if stroke else None, width=0.55)

    def text(x, y, value, size, bold=False, color=INK):
        page.insert_text((x, y), value, fontsize=size, fontname='hebo' if bold else 'helv', color=pdf_color(color))

    def wrap(value, size, max_width):
        lines, line = [], ''
        for word in value.split():
            candidate = f'{line} {word}'.strip()
            if line and pymupdf.get_text_length(candidate, fontname='hebo', fontsize=size) > max_width:
                lines.append(line)
                line = word
            else:
                line = candidate
        return lines + [line]

    box(28, 28, width - 56, 99, GOLD)
    text(44, 48, 'STUDYDESK  /  UNITED AFRICAN UNIVERSITY OF TANZANIA', 8.4, True, '6C511C')
    text(44, 83, 'BIT Year 2 timetable', 29, True)
    text(46, 108, 'Semester 1  /  2026-2027  /  East Africa Time (UTC+3)', 10, True, MUTED)
    box(width - 163, 53, 115, 27, 'FFF5D2')
    text(width - 150, 70, 'REVISED DRAFT', 9.3, True, '6C511C')

    gutter, gap, col_y = 28, 8, 148
    col_w = (width - 2 * gutter - 4 * gap) / 5
    for day in range(1, 6):
        x = gutter + (day - 1) * (col_w + gap)
        items = [item for item in SEMESTER['sessions'] if item['day'] == day]
        box(x, col_y, col_w, 361, PAPER, 'EBE8E2')
        box(x, col_y, col_w, 38, 'F0EEE8')
        text(x + 10, col_y + 15, DAYS[day].upper(), 9.2, True)
        text(x + 10, col_y + 29, f'{len(items)} sessions', 8.3, False, MUTED)
        for i, item in enumerate(items):
            y = col_y + 46 + 101 * i
            course = COURSES.get(item['code'])
            title = course['title'] if course else 'Chapel'
            tone = PASTELS[course['tone']] if course else PEACH
            box(x + 5, y, col_w - 10, 92, WHITE, 'EBE8E2')
            box(x + 5, y, 3.5, 92, tone)
            text(x + 12, y + 15, f"{item['start']} - {item['end']}", 10, True)
            text(x + 12, y + 27, (item['code'] + '  /  ' if item['code'] else '') + KIND[item['kind']], 7.6, False, MUTED)
            for line_index, line in enumerate(wrap(title, 9.6, col_w - 25)):
                text(x + 12, y + 42 + 11 * line_index, line, 9.6, True)
            text(x + 12, y + 72, item['venue'], 8.7, True)
            if course:
                text(x + 12, y + 84, course['lecturer'], 8.4, False, MUTED)
    text(29, 534, '6 courses  /  11 classes + Wednesday Chapel  /  Times repeat each teaching week.', 9.3, True)
    text(29, 550, 'Source: UAUT CoEIT/BIT Weekly Class Timetable 2026/2027, Updated Revised Draft, p. 2.', 8.3, False, MUTED)
    text(29, 565, 'Only scheduled slots are shown. Confirm any time or venue changes with UAUT.', 8.3, False, MUTED)
    doc.save(OUT / 'bit-year-2-timetable.pdf', garbage=4, deflate=True)


def planner_docx():
    doc = Document()
    core = doc.core_properties
    core.author = 'StudyDesk'
    core.title = DOC_NAME
    core.subject = 'UAUT  /  2026–27 Semester 1'
    core.created = core.modified = CREATED
    section = doc.sections[0]
    section.page_width, section.page_height = DIn(8.27), DIn(11.69)
    section.left_margin, section.right_margin = DIn(.73), DIn(.73)
    section.top_margin, section.bottom_margin = DIn(.62), DIn(.6)
    section.footer_distance = DIn(.3)
    foot = section.footer.paragraphs[0].add_run('STUDYDESK  /  UAUT BIT YEAR 2  /  SEMESTER 1, 2026/27')
    foot.font.color.rgb = DRgb.from_string(MUTED)
    foot.font.size = DPt(8)

    normal = doc.styles['Normal']
    normal.font.name, normal.font.size = 'Aptos', DPt(10.5)
    normal.font.color.rgb = DRgb.from_string(INK)
    normal.paragraph_format.space_after = DPt(6)
    for name, size, color in [('Title', 34, INK), ('Heading 1', 19, INK), ('Heading 2', 13, '58418C')]:
        style = doc.styles[name]
        style.font.name, style.font.size, style.font.bold = 'Aptos', DPt(size), True
        style.font.color.rgb = DRgb.from_string(color)

    def caption(text):
        p = doc.add_paragraph()
        run = p.add_run(text)
        run.font.bold, run.font.size = True, DPt(9)
        run.font.color.rgb = DRgb.from_string('76501A')

    def cell_text(cell, value, fill, bold=False):
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        p = cell.paragraphs[0]
        p.paragraph_format.space_after = DPt(4)
        p.paragraph_format.space_before = DPt(4)
        run = p.add_run(value)
        run.bold, run.font.size = bold, DPt(9)
        shd = OxmlElement('w:shd')
        shd.set(qn('w:fill'), fill)
        cell._tc.get_or_add_tcPr().append(shd)

    caption('01   /   PERSONAL SEMESTER WORKSPACE')
    doc.add_heading(DOC_NAME, 0)
    doc.add_paragraph('Mwijay Davie  •  UAUT  •  Semester 1, 2026/27  •  East Africa Time')
    doc.add_paragraph('Week of: ___________________     One thing I want to understand: _____________________')
    doc.add_heading('A realistic weekly routine', 1)
    doc.add_paragraph('These are suggested self-study blocks, not extra classes. Leave time to eat and travel; swap a block rather than letting it overlap a class.')
    table = doc.add_table(rows=1, cols=4)
    table.autofit = False
    widths = [.67, 1.27, 2.37, 2.45]
    for col, size in zip(table.columns, widths):
        col.width = DIn(size)
    for cell, label, size in zip(table.rows[0].cells, ['Day', 'Time (EAT)', 'Study block', 'What to produce'], widths):
        cell.width = DIn(size)
        cell_text(cell, label, GOLD, True)
    for index, block in enumerate(PLAN):
        row = table.add_row()
        row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
        title = f"{block['code']} · {block['title']}"
        for cell, value, size in zip(row.cells, [DAYS[block['day']][:3], f"{block['start']}–{block['end']}", title, block['output']], widths):
            cell.width = DIn(size)
            cell_text(cell, value, PAPER if index % 2 == 0 else WHITE)
    doc.add_heading('How to use a block', 2)
    doc.add_paragraph('5 min — recall from memory. 20–30 min — try one example. Last 5 min — check it and write one question for class. Jifunze, jaribu, rudia.')
    doc.add_heading('Sunday reset (optional)', 2)
    doc.add_paragraph('What can I now explain without my notes? __________________________________________')
    doc.add_paragraph('What still needs practice next week? ______________________________________________')
    doc.add_paragraph('What should I ask a lecturer or classmate? __________________________________________')
    doc.add_page_break()
    caption('02   /   MATERIALS & ASSIGNMENTS')
    doc.add_heading('Where to start', 0)
    doc.add_heading('IS274 · Object-Oriented Analysis and Design', 2)
    doc.add_paragraph('Read Introduction-OOAD.pdf pp. 4–8, then 15–16. Analysis is “what must the system do?” Design is “how will it do it?” Example: a campus timetable must show the next classroom; decide how Course and Session objects will provide that result. Draft a use case, then sketch two classes.')
    doc.add_heading('IS264 · Principles of Database Systems', 2)
    doc.add_paragraph('In COMPLETE GROUPS WORK.pdf, locate your assigned group before starting. Sketch your tables and keys, insert fictional data, and predict query results. INNER JOIN keeps matches; LEFT JOIN also keeps unmatched left-side rows. For an enrolment report, test a student with no enrolments.')
    doc.add_heading('Networking · code to confirm', 2)
    doc.add_paragraph('UNIT I.pdf explains IP packets, IPv4 and NAT. UNIT II.pdf covers subnet masks and FLSM/VLSM. Work in that order. Example: splitting a /24 into four equal subnets needs two borrowed bits, giving /26 blocks with 64 addresses each (62 ordinary usable hosts).')
    doc.add_heading('Reusable report outline', 1)
    doc.add_paragraph('1. Question or objective  •  2. Design / setup  •  3. Steps and evidence  •  4. Expected vs. actual results  •  5. Conclusion and sources. Label each screenshot and explain what it demonstrates. Use only invented data for database exercises.')
    doc.add_heading('Turn the report into slides', 2)
    doc.add_paragraph('Use one idea per slide: problem → approach → example or diagram → result → takeaway. Keep full explanations in the speaker notes. The OOAD PowerPoint is an editable starting point, not a completed submission.')
    doc.add_paragraph('Ask in class: Database group ____ · Deadline ____ · Networking course code ____')
    doc.save(OUT / 'bit-year-2-study-planner.docx')


def ooad_deck():
    deck = Presentation()
    deck.slide_width, deck.slide_height = PIn(13.333), PIn(7.5)
    core = deck.core_properties
    core.title, core.author = DECK_NAME, 'StudyDesk'
    core.subject, core.created, core.modified = 'IS274 · UAUT revision deck', CREATED, CREATED

    def shape(slide, x, y, w, h, color, rounded=False):
        figure = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if rounded else MSO_SHAPE.RECTANGLE, PIn(x), PIn(y), PIn(w), PIn(h))
        figure.fill.solid()
        figure.fill.fore_color.rgb = PRgb.from_string(color)
        figure.line.fill.background()
        if rounded:
            figure.adjustments[0] = 0.13
        return figure

    def text(slide, x, y, w, h, value, size=22, color=INK, bold=False, align=PP_ALIGN.LEFT):
        tf = slide.shapes.add_textbox(PIn(x), PIn(y), PIn(w), PIn(h)).text_frame
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
        tf.word_wrap = True
        tf.vertical_anchor = MSO_ANCHOR.TOP
        for i, line in enumerate(value.split('\n')):
            p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            p.alignment = align
            p.space_after = PPt(6)
            run = p.add_run()
            run.text = line
            run.font.name, run.font.size, run.font.bold = 'Aptos', PPt(size), bold
            run.font.color.rgb = PRgb.from_string(color)

    def slide(label, title, sub='', cover=False):
        s = deck.slides.add_slide(deck.slide_layouts[6])
        s.background.fill.solid()
        s.background.fill.fore_color.rgb = PRgb.from_string(GOLD if cover else PAPER)
        shape(s, .7, .62, .12, .31, '7A57B1')
        text(s, .94, .62, 11.7, .3, label, 13, '5F467F', True)
        text(s, .7, 1.10, 11.9, 1.90 if cover else .77, title, 53 if cover else 39, bold=True)
        if sub:
            text(s, .73, 3.14 if cover else 1.93, 11.7, .8, sub, 22 if cover else 18, MUTED)
        shape(s, .7, 6.9, 11.93, .013, 'DBD6CE' if not cover else 'DCBD71')
        text(s, .7, 7.03, 10.8, .22, 'STUDYDESK     /     IS274     /     UAUT 2026/27', 10, MUTED, True)
        text(s, 11.85, 7.03, .78, .22, f'{len(deck.slides):02}', 10, MUTED, True, PP_ALIGN.RIGHT)
        return s

    def tile(s, x, y, w, h, tag, title, body, fill):
        shape(s, x, y, w, h, fill, True)
        text(s, x + .23, y + .23, w - .46, .33, tag, 11.5, '625078', True)
        text(s, x + .23, y + .68, w - .46, .59, title, 23, bold=True)
        text(s, x + .23, y + 1.27, w - .46, h - 1.45, body, 17.5, MUTED)

    def note(s, value):
        s.notes_slide.notes_text_frame.text = value

    s = slide('REVISION DECK  /  UNIT 1', 'OOAD in\nplain language', 'Object-Oriented Analysis and Design', cover=True)
    tile(s, 7.98, 1.66, 4.38, 3.93, 'TODAY’S QUESTION', 'What comes before code?', 'Start with a student’s goal, sketch a model and test whether it supports the goal.', LILAC)
    text(s, .74, 4.67, 6.85, 1.17, 'BIT Year 2  •  Semester 1\nA campus timetable example', 20, MUTED)
    note(s, 'Source: Introduction-OOAD.pdf, Gambadu, pp. 2–20. These original revision slides use a hypothetical campus timetable feature as the running example.')

    s = slide('01  /  DEVELOPMENT', 'Software development is a cycle', 'A working program is not the end: needs change and systems must be maintained.')
    specs = [('01', 'Discover', 'Find users and collect requirements.', GOLD), ('02', 'Design', 'Model the data, behaviour and responsibilities.', LILAC), ('03', 'Build & test', 'Write code and test it against expected behaviour.', BLUE), ('04', 'Evolve', 'Release, maintain and improve with feedback.', GREEN)]
    for i, (tag, heading, body, color) in enumerate(specs):
        tile(s, .7 + 3.02 * i, 3.02, 2.86, 3.01, tag, heading, body, color)
    note(s, 'Introduction-OOAD.pdf, pp. 4–11. This is a simplified view of the software development lifecycle. Activities can repeat; it is not a mandatory waterfall sequence.')

    s = slide('02  /  REQUIREMENTS', 'Analysis asks what. Design asks how.', 'Same feature, two different questions.')
    tile(s, .7, 2.83, 5.82, 3.35, 'ANALYSIS', 'What does the user need?', 'A student needs the time and venue of the next scheduled activity, even if the next class is tomorrow.', GOLD)
    tile(s, 6.75, 2.83, 5.88, 3.35, 'DESIGN', 'How will the app do it?', 'Store day, start time, end time and venue on each Session; compare the schedule to the current time in EAT.', LILAC)
    note(s, 'Ask which box “show classes in Dar es Salaam time” belongs in. It can be a requirement. Choosing Intl.DateTimeFormat and the time zone is a design decision. See source pp. 4, 15–16.')

    s = slide('03  /  OBJECT-ORIENTED THINKING', 'Give objects clear responsibilities', 'Objects can carry state and behaviour. Start with useful distinctions.')
    tile(s, .7, 2.83, 3.83, 3.42, 'FOCUS', 'Abstraction', 'Keep what matters: start, end and room, not the colour of the classroom walls.', LILAC)
    tile(s, 4.75, 2.83, 3.83, 3.42, 'PROTECT', 'Encapsulation', 'Keep rules with the object: a session should not end before it starts.', BLUE)
    tile(s, 8.8, 2.83, 3.83, 3.42, 'SEPARATE', 'Modularity', 'Separate timetable logic from screen styling so each can change independently.', GREEN)
    note(s, 'Source p. 16. Related OO ideas include inheritance and polymorphism. They can be useful, but only when the design actually needs them.')

    s = slide('04  /  UML', 'Pick the diagram for the question', 'UML is a shared way to communicate a model, not the software itself.')
    for i, (left, right, color) in enumerate([('Use case', 'Who uses the system, and what goal do they have?', GOLD), ('Class', 'What concepts exist, and how are they related?', LILAC), ('Sequence', 'Who sends which message, and in what order?', BLUE), ('Activity', 'What steps and decisions make up this workflow?', GREEN)]):
        y = 2.75 + .86 * i
        shape(s, .7, y, 11.93, .71, color, True)
        text(s, .9, y + .14, 2.35, .4, left, 19, bold=True)
        text(s, 3.35, y + .16, 8.94, .43, right, 17, MUTED)
    note(s, 'Source pp. 2–3, 16. Sequence diagrams focus on interactions. Activity diagrams focus on the flow and its branches. State diagrams can explain how one entity changes state over time.')

    s = slide('05  /  WORKED EXAMPLE', 'Model “Check next class”', 'Goal: find out where to go without reading the whole timetable.')
    tile(s, .7, 2.73, 5.84, 3.68, 'USE CASE NARRATIVE', 'Actor: Student', '1. Student opens timetable.\n2. App selects the next session.\n3. App shows time and venue.\nIf none today: show the next day.', GOLD)
    shape(s, 6.76, 2.73, 5.87, 3.68, LILAC, True)
    text(s, 6.99, 2.98, 5.40, .3, 'SIMPLIFIED CLASS MODEL', 11.5, '625078', True)
    shape(s, 7.02, 3.63, 1.98, 1.46, WHITE, True)
    shape(s, 10.00, 3.63, 2.38, 1.46, WHITE, True)
    shape(s, 9.00, 4.32, 1.0, .019, '7A57B1')
    text(s, 7.14, 3.77, 1.74, .4, 'Course', 18, bold=True)
    text(s, 7.14, 4.25, 1.74, .61, 'code\ntitle', 13, MUTED)
    text(s, 10.12, 3.77, 2.09, .4, 'Session', 18, bold=True)
    text(s, 10.12, 4.25, 2.09, .68, 'day, start, end\nvenue', 13, MUTED)
    text(s, 9.09, 3.98, .83, .32, '1     0..*', 12, '625078', True)
    text(s, 7.03, 5.34, 5.24, .59, 'One course may have many sessions.', 15, MUTED)
    note(s, 'Illustrative example based on the modelling goals in the introduction. The diagram covers course sessions only; a campus activity such as Chapel can be represented separately.')

    s = slide('06  /  QUALITY', 'Why projects still struggle', 'Good tools help, but do not replace clear thinking and communication.')
    tile(s, .7, 2.83, 5.82, 3.45, 'A COMMON MYTH', '“Working code means done.”', 'A project still needs validation, testing, useful documentation and maintenance. Ask: does it solve the user’s problem?', PEACH)
    tile(s, 6.75, 2.83, 5.88, 3.45, 'A PRACTICAL RESPONSE', 'Test the requirement', 'Try a normal day, a weekend and consecutive classes. Agree with the user what the app should show in each case.', GREEN)
    note(s, 'Source pp. 10–15, 17–19. The software crisis showed the costs of unclear requirements and unmanaged complexity: missed timelines, low quality and expensive maintenance.')

    s = slide('07  /  ACTIVE RECALL', 'Close your notes and try this', 'Explain your reasoning, not just the definition.')
    for i, (number, prompt) in enumerate([('01', 'Write one requirement and one design decision for a campus app.'), ('02', 'Sketch a use case with an alternate flow for no classes today.'), ('03', 'Which UML diagram explains the order of messages, and why?')]):
        y = 2.8 + .85 * i
        shape(s, .7, y, .51, .51, GOLD, True)
        text(s, .76, y + .11, .39, .27, number, 13, '654913', True, PP_ALIGN.CENTER)
        text(s, 1.42, y + .08, 11, .62, prompt, 20, INK)
    text(s, .72, 5.61, 11.65, .58, 'Source: Introduction-OOAD.pdf · Gambadu · 2026/27 · pp. 2–20', 14, MUTED)
    note(s, 'Possible answer for 3: sequence diagram. For 1 and 2, check that the requirements describe an observable outcome and that the alternate flow has a clear trigger and result.')
    deck.save(OUT / 'is274-ooad-revision.pptx')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    timetable_pdf()
    planner_docx()
    ooad_deck()
    print('Wrote printable timetable, editable Word planner and OOAD revision slides.')
