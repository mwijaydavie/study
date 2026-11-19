import { useState } from 'react';
import { ArrowDownToLine, ArrowUpRight, BookOpen, FileText, Folder, FolderOpen, Search, X } from 'lucide-react';
import { courses } from '../schedule.js';
import guides from '../data/guides.json';
import { CourseIcon, downloads, Modal } from './ui.jsx';

const folders = [
  { id: 'IS274', title: 'Object-Oriented Analysis and Design', description: 'Start with software development, requirements and UML.', items: [
    { guide: 'ooad', label: 'OOAD in plain language', meta: 'Study guide · Introduction slides' },
    { href: downloads.slides, label: 'OOAD revision slides', meta: 'Editable PowerPoint · PPTX' },
  ] },
  { id: 'IS264', title: 'Principles of Database Systems', description: 'Sort out the practical briefs and build your SQL foundations.', items: [
    { guide: 'sql', label: 'Group work: an SQL roadmap', meta: 'Study guide · COMPLETE GROUPS WORK' },
  ] },
  { id: 'networking', title: 'Networking', description: 'Supplementary notes. Confirm the course code with your lecturer.', items: [
    { guide: 'ip', label: 'Unit I — IP fundamentals', meta: 'Study guide · packets, IPv4 and NAT' },
    { guide: 'subnet', label: 'Unit II — Subnetting', meta: 'Study guide · prefixes, FLSM and VLSM' },
  ] },
  { id: 'tools', title: 'Semester downloads', description: 'A printable timetable and a planner you can edit.', items: [
    { href: downloads.print, label: 'BIT Year 2 weekly timetable', meta: 'Print-friendly · PDF' },
    { href: downloads.planner, label: 'BIT Year 2 study planner', meta: 'Editable Word document · DOCX' },
  ] },
  { id: 'FN200', ...courses.FN200, description: 'Finance decisions, agency problems and the two sides of a financial instrument.', items: [
    { guide: 'finance-function', label: 'The finance function', meta: 'Study guide · decisions, liquidity and agency' },
    { guide: 'finance-instruments', label: 'Financial instruments', meta: 'Study guide · assets, liabilities and equity' },
  ] },
  ...['CS243', 'IS237', 'ST119'].map((id) => ({ id, ...courses[id], description: courses[id].focus, items: [] })),
];
const filters = [{ id: '', label: 'All folders' }, ...folders.map(({ id }) => ({ id, label: ({ networking: 'Networking', tools: 'Downloads' })[id] ?? id }))];

function Guide({ guide, onClose }) {
  return <Modal label="Study guide" title={guide.title} onClose={onClose}>
    <p className="guide-source">{guide.source}</p>
    <p className="guide-intro">{guide.intro}</p>
    <div className="guide-sections">{guide.sections.map(({ title, body }) => <section key={title}><h3>{title}</h3><p>{body}</p></section>)}</div>
    <div className="tip-box"><strong>Try it yourself</strong><p>{guide.exercise}</p></div>
  </Modal>;
}

function ResourceItem({ item, onOpen }) {
  const { label, meta, href, guide } = item;
  const content = <><FileText className="resource-file" size={17} /><span><strong>{label}</strong><span>{meta}</span></span>{href ? <ArrowDownToLine size={17} aria-hidden="true" /> : <ArrowUpRight size={17} aria-hidden="true" />}</>;
  return <li>{href ? <a className="resource-link" href={href} download>{content}</a> : <button className="resource-link" type="button" onClick={() => onOpen(guide)}>{content}</button>}</li>;
}

export default function Materials({ selected }) {
  const [query, setQuery] = useState('');
  const [guide, setGuide] = useState(null);
  const needle = query.trim().toLowerCase();
  const visible = folders.filter(({ id, title, description, items }) => (!selected || id === selected) &&
    [id, title, description, ...items.flatMap(({ label, meta, guide: key }) => [label, meta, key && guides[key]?.source])].join(' ').toLowerCase().includes(needle));
  return <>
    <section className="hero secondary-hero library-hero" aria-labelledby="page-title">
      <div className="hero-copy">
        <span className="hero-label"><FolderOpen size={17} /> STUDY LIBRARY</span>
        <h1 id="page-title">My materials<span>.</span></h1>
        <p>Course folders, simple explanations, and editable files.</p>
        <div className="hero-meta"><BookOpen size={16} /> Semester 1 <span className="inline-dot" /> 2026/27</div>
      </div>
      <div className="hero-emblem" aria-hidden="true"><FolderOpen size={150} strokeWidth={1.15} /></div>
    </section>
    <section className="materials-section" aria-labelledby="folders-heading">
      <div className="section-heading materials-heading">
        <div><h2 id="folders-heading">Course folders</h2><p>Revision guides and downloads. Original PDFs are filed separately in your workspace.</p></div>
        <div className="search-box"><Search size={18} aria-hidden="true" /><input type="search" aria-label="Search materials" placeholder="Find a topic or file…" value={query} onChange={(event) => setQuery(event.target.value)} />
          {query && <button type="button" className="clear-search" aria-label="Clear search" onClick={() => setQuery('')}><X size={16} /></button>}
        </div>
      </div>
      <div className="folder-filters" role="group" aria-label="Filter by course">
        {filters.map(({ id, label }) => <a key={id} aria-current={selected === id ? 'true' : undefined} href={id ? `#materials/${id}` : '#materials'} onClick={() => setQuery('')}>
          {!id && <Folder size={15} />}{label}
        </a>)}
      </div>
      {visible.length ? <div className="folder-grid" aria-live="polite">{visible.map(({ id, title, description, items }) => <article className="folder-card" key={id}>
        <div className="folder-intro"><CourseIcon code={id} /><div><p className="eyebrow">{id === 'networking' ? 'COURSE UNCONFIRMED' : id === 'tools' ? 'PRINT & EDIT' : id}</p><h3>{title}</h3></div></div>
        <p>{description}</p>
        {items.length > 0 ? <ul className="resource-list">{items.map((item) => <ResourceItem key={item.label} item={item} onOpen={setGuide} />)}</ul> :
          <p className="empty-folder"><Folder size={16} /> No source material uploaded yet</p>}
      </article>)}</div> :
        <div className="library-empty" role="status"><Search size={26} /><h3>No matching folders</h3><p>Try a different topic or clear the search.</p><button className="button secondary" type="button" onClick={() => setQuery('')}>Clear search</button></div>}
    </section>
    {guide && <Guide guide={guides[guide]} onClose={() => setGuide(null)} />}
  </>;
}
