import { useState } from 'react';
import { ArrowRight, ArrowUpRight, BookOpen, CalendarDays, ChevronRight, Clock3, GraduationCap, Info, MapPin, Sun, UserRound } from 'lucide-react';
import { courses, days, duration, formatDuration, kindLabels, semester, sessions, sessionsFor, sessionTitle, upcomingSession, weekdays } from '../schedule.js';
import { CourseIcon, DownloadLink, downloads, Modal } from './ui.jsx';

const courseCount = Object.keys(courses).length;
const classMinutes = sessions.filter((item) => item.kind !== 'chapel').reduce((total, item) => total + duration(item), 0);

function SessionCard({ session, onOpen }) {
  const course = courses[session.code];
  return <li>
    <button type="button" className={`session-card ${course ? `tone-${course.tone}` : 'tone-peach'}`} onClick={() => onOpen(session)}>
      <span className="session-time"><strong>{session.start}</strong><span>{session.end}</span></span>
      <CourseIcon code={session.code} />
      <span className="session-body">
        <span className="session-tags">
          {session.code && <span className="session-code">{session.code}</span>}
          {session.kind !== 'chapel' && <span className="kind-label">{kindLabels[session.kind]}</span>}
          {session.kind === 'chapel' && <span className="kind-label">Campus activity</span>}
        </span>
        <span className="session-title">{sessionTitle(session)}</span>
        <span className="session-meta">
          <span><MapPin size={14} />{session.venue}</span>
          {course && <span><UserRound size={14} />{course.lecturer}</span>}
        </span>
      </span>
      <ChevronRight size={18} className="session-chevron" aria-hidden="true" />
    </button>
  </li>;
}

function SessionList({ day, today, onOpen }) {
  const list = sessionsFor(day);
  return <section className="day-group" aria-label={`${days[day]} schedule`}>
    <div className="day-heading">
      <div><h3>{days[day]}</h3>{day === today && <span className="today-pill">Today</span>}</div>
      <p>{list.length} {list.length === 1 ? 'session' : 'sessions'}{list.length > 0 && <><span className="inline-dot" />{formatDuration(list.reduce((total, item) => total + duration(item), 0))}</>}</p>
    </div>
    {list.length ? <ul className="session-list">{list.map((session) => <SessionCard key={session.id} session={session} onOpen={onOpen} />)}</ul> :
      <div className="rest-card">
        <span className="square-icon tone-peach"><Sun size={23} /></span>
        <div><h4>No scheduled classes</h4><p>Take a break, or use the time for a short review.</p><a className="text-link" href="#plan">See the study plan <ArrowRight size={15} /></a></div>
      </div>}
  </section>;
}

function SessionDetails({ session, onClose }) {
  const course = courses[session.code];
  return <Modal title={sessionTitle(session)} label={session.code ? `${session.code} · ${kindLabels[session.kind]}` : 'Campus activity'} onClose={onClose}>
    <dl className="detail-list">
      <div><dt><CalendarDays size={17} /> When</dt><dd>{days[session.day]} · {session.start}–{session.end} EAT</dd></div>
      <div><dt><Clock3 size={17} /> Duration</dt><dd>{formatDuration(duration(session))}</dd></div>
      <div><dt><MapPin size={17} /> Venue</dt><dd>{session.venue}</dd></div>
      {course && <div><dt><UserRound size={17} /> Lecturer</dt><dd>{course.lecturer}</dd></div>}
    </dl>
    {course && <div className="tip-box"><strong>Suggested follow-up</strong><p>{course.focus}</p></div>}
    <div className="modal-actions">
      {course && <a className="button primary" href={`#materials/${session.code}`} onClick={onClose}>Open course folder <ArrowRight size={16} /></a>}
      <span className="fine-print">Weekly draft · source p. {semester.sourcePage}</span>
    </div>
  </Modal>;
}

function NextCard({ clock, onOpen }) {
  const next = upcomingSession(clock);
  if (!next) return null;
  const { session, offset, inProgress } = next;
  const day = offset === 0 ? 'Today' : offset === 1 ? 'Tomorrow' : days[session.day];
  return <section className="next-card" aria-label={inProgress ? 'Scheduled now' : 'Up next'}>
    <div className="next-top"><span><span className="signal" />{inProgress ? 'SCHEDULED NOW' : 'UP NEXT'}</span><Clock3 size={16} aria-hidden="true" /></div>
    <p className="next-time">{day} <span>·</span> {session.start}–{session.end}</p>
    <h2>{sessionTitle(session)}</h2>
    <div className="next-bottom">
      <span><MapPin size={15} />{session.venue}</span>
      <button type="button" className="next-link" onClick={() => onOpen(session)}>Details <ArrowUpRight size={16} /></button>
    </div>
  </section>;
}

export default function Timetable({ clock }) {
  const [selection, setSelection] = useState(null);
  const [view, setView] = useState('day');
  const [detail, setDetail] = useState(null);
  const day = selection ?? clock.day;
  return <>
    <section className="hero timetable-hero" aria-labelledby="page-title">
      <div className="hero-copy">
        <span className="hero-label"><GraduationCap size={17} aria-hidden="true" /> UAUT <span className="inline-dot" /> BIT YEAR 2</span>
        <h1 id="page-title">My timetable<span>.</span></h1>
        <p>Habari, Mwijay! <span className="greeting-detail">Here’s your class week at a glance.</span></p>
        <div className="hero-meta"><CalendarDays size={16} aria-hidden="true" /> Semester 1 <span className="inline-dot" /> 2026/27</div>
      </div>
      <img className="hero-art" src="/art/planner.webp" alt="" width="645" height="609" fetchPriority="high" />
    </section>

    <div className="timetable-grid">
      <section className="schedule-column" aria-label="Class schedule">
        <div className="schedule-controls">
          <div className="section-heading">
            <div><h2>Class schedule</h2><p>Weekly timetable <span className="inline-dot" /> East Africa Time</p></div>
            <div role="group" className="view-toggle" aria-label="Schedule view">
              <button type="button" aria-pressed={view === 'day'} onClick={() => setView('day')}>Day</button>
              <button type="button" aria-pressed={view === 'week'} onClick={() => setView('week')}>Week</button>
            </div>
          </div>
          {view === 'day' && <div role="group" className="weekday-selector" aria-label="Choose a weekday">
            {weekdays.map((index) => {
              const count = sessionsFor(index).length;
              return <button type="button" key={index} aria-label={`${days[index]}, ${count} sessions${clock.day === index ? ', today' : ''}`} aria-pressed={day === index}
                className="weekday" onClick={() => setSelection(index)}>
                <span className="weekday-name">{days[index].slice(0, 3)}{clock.day === index && <span className="weekday-dot" />}</span>
                <span>{count} sessions</span>
              </button>;
            })}
          </div>}
        </div>

        <div className="schedule-list" aria-live="polite">
          {view === 'day' && selection !== null && day !== clock.day &&
            <button className="back-today text-link" type="button" onClick={() => setSelection(null)}>Back to today <ArrowRight size={14} /></button>}
          {(view === 'week' ? weekdays : [day]).map((index) => <SessionList key={index} day={index} today={clock.day} onOpen={setDetail} />)}
        </div>
      </section>

      <aside className="details-rail" aria-label="Timetable information">
        <div className="next-slot"><NextCard clock={clock} onOpen={setDetail} /></div>

        <div className="summary-slot">
          <section className="snapshot-card" aria-labelledby="snapshot-title">
            <h2 id="snapshot-title">Semester at a glance</h2>
            <div className="stats-row">
              <div className="stat"><span className="square-icon tone-violet"><BookOpen size={17} /></span><div><strong>{courseCount}</strong><span>Courses</span></div></div>
              <div className="stat"><span className="square-icon tone-green"><CalendarDays size={17} /></span><div><strong>{sessions.length}</strong><span>Weekly sessions</span></div></div>
            </div>
            <p className="snapshot-foot"><Clock3 size={15} /> {formatDuration(classMinutes)} of class time + 1h chapel / week</p>
          </section>
          <section className="draft-card" aria-labelledby="draft-title">
            <Info size={18} aria-hidden="true" />
            <div><h2 id="draft-title">Revised draft</h2>
              <p>From the UAUT timetable, p. {semester.sourcePage}. Confirm any room or time changes with the university.</p>
              <DownloadLink href={downloads.print}>Download timetable PDF</DownloadLink>
            </div>
          </section>
        </div>
      </aside>
    </div>
    {detail && <SessionDetails session={detail} onClose={() => setDetail(null)} />}
  </>;
}
