import { useState } from 'react';
import { ArrowUpRight, CalendarDays, Circle, CircleCheck, Clock3, ListChecks, Target } from 'lucide-react';
import plan from '../data/plan.json';
import { days, duration, formatDuration } from '../schedule.js';
import { CourseIcon, DownloadLink, downloads } from './ui.jsx';

const totalMinutes = plan.reduce((sum, block) => sum + duration(block), 0);
const storageKey = 'studydesk:weekly-progress';

function readProgress() {
  try {
    const value = JSON.parse(localStorage.getItem(storageKey));
    return value && typeof value.week === 'string' && Array.isArray(value.done) ? value : null;
  } catch { return null; }
}

export default function StudyPlan({ clock }) {
  const [saved, setSaved] = useState(readProgress);
  const [canSave, setCanSave] = useState(true);
  const { weekKey, weekLabel } = clock;
  const done = new Set(saved?.week === weekKey ? saved.done.filter((id) => plan.some((block) => block.id === id)) : []);
  const percentage = Math.round(done.size / plan.length * 100);
  function toggle(id) {
    if (done.has(id)) done.delete(id);
    else done.add(id);
    const state = { week: weekKey, done: [...done] };
    setSaved(state);
    try {
      localStorage.setItem(storageKey, JSON.stringify(state));
      setCanSave(true);
    } catch { setCanSave(false); }
  }

  return <>
    <section className="hero secondary-hero plan-hero" aria-labelledby="page-title">
      <div className="hero-copy">
        <span className="hero-label"><ListChecks size={17} /> PERSONAL STUDY TIME</span>
        <h1 id="page-title">My study plan<span>.</span></h1>
        <p>One small task at a time. Jifunze, jaribu, rudia.</p>
        <div className="hero-meta"><CalendarDays size={16} /> {weekLabel} <span className="inline-dot" /> EAT</div>
      </div>
      <div className="hero-emblem" aria-hidden="true"><Target size={144} strokeWidth={1.15} /></div>
    </section>
    <div className="work-layout">
      <section aria-labelledby="blocks-heading">
        <div className="section-heading">
          <div><h2 id="blocks-heading">Your study blocks</h2><p>Suggested times around your classes <span className="inline-dot" /> {formatDuration(totalMinutes)} total</p></div>
        </div>
        <ul className="plan-list">
          {plan.map((block) => {
            const completed = done.has(block.id);
            return <li key={block.id} className={`plan-card${completed ? ' is-done' : ''}`}>
              <CourseIcon code={block.code} />
              <div className="plan-body">
                <div className="plan-slot"><span>{days[block.day]} · {block.start}–{block.end}</span><span className="session-code">{block.code}</span></div>
                <h3>{block.title}</h3>
                <p>{block.work}</p>
                <p className="plan-output"><strong>Make:</strong> {block.output}</p>
                <a href={`#materials/${block.code}`} className="text-link">Course folder <ArrowUpRight size={14} /></a>
              </div>
              <label className="plan-check" title={completed ? 'Mark as not done' : 'Mark as done'}>
                <input type="checkbox" aria-label={`Completed: ${block.title}`} checked={completed} onChange={() => toggle(block.id)} />
                <span aria-hidden="true">{completed ? <CircleCheck size={23} /> : <Circle size={21} />}</span>
              </label>
            </li>;
          })}
        </ul>
      </section>
      <aside className="work-aside" aria-label="Study progress and tips">
        <section className="progress-card">
          <p className="eyebrow"><Target size={16} /> THIS WEEK</p>
          <h2>{done.size}<span> / {plan.length} done</span></h2>
          <progress aria-label="Study blocks completed" value={done.size} max={plan.length} />
          <p>{percentage}% complete <span className="inline-dot" /> {canSave ? 'Saved on this device' : 'Progress is not saved'}</p>
        </section>
        <section className="snapshot-card method-card">
          <h2>A simple study routine</h2>
          <ol><li><strong>Recall:</strong> explain the main idea without notes.</li><li><strong>Practise:</strong> solve or sketch one example.</li><li><strong>Review:</strong> write one thing to revisit.</li></ol>
          <p className="snapshot-foot"><Clock3 size={15} /> The checklist starts fresh every Monday, EAT.</p>
        </section>
        <div className="aside-download"><DownloadLink href={downloads.planner}>Download editable planner</DownloadLink><span>Word document · DOCX</span></div>
      </aside>
    </div>
  </>;
}
