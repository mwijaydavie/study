import { useEffect, useId, useRef } from 'react';
import { ArrowDownToLine, BookOpen, Calculator, Church, Code2, Database, Landmark, Laptop, Network, X } from 'lucide-react';
import { courses } from '../schedule.js';

const courseIcons = { CS243: Laptop, IS274: Code2, IS264: Database, ST119: Calculator, IS237: Network, FN200: Landmark, networking: Network, tools: BookOpen };

export const downloads = {
  print: '/downloads/bit-year-2-timetable.pdf',
  planner: '/downloads/bit-year-2-study-planner.docx',
  slides: '/downloads/is274-ooad-revision.pptx',
};

export function CourseIcon({ code, className = '' }) {
  const Icon = courseIcons[code] ?? Church;
  const tone = courses[code]?.tone ?? (code === 'networking' ? 'blue' : 'peach');
  return <span className={`course-icon tone-${tone} ${className}`}><Icon size={21} aria-hidden="true" /></span>;
}

export function DownloadLink({ href, children, className = '' }) {
  return <a href={href} download className={`download-link ${className}`}>
    <ArrowDownToLine size={16} aria-hidden="true" /> {children}
  </a>;
}

export function Modal({ title, label, children, onClose }) {
  const dialog = useRef(null);
  const titleId = useId();
  useEffect(() => {
    const element = dialog.current;
    if (!element.open) element.showModal();
  }, []);
  return <dialog ref={dialog} className="modal" aria-labelledby={titleId} onClose={onClose}
    onClick={(event) => { if (event.target === event.currentTarget) dialog.current.close(); }}>
    <div className="modal-inner">
      <button autoFocus type="button" className="icon-button close-modal" aria-label="Close dialog" onClick={() => dialog.current.close()}><X size={20} /></button>
      <p className="eyebrow">{label}</p>
      <h2 id={titleId}>{title}</h2>
      {children}
    </div>
  </dialog>;
}
