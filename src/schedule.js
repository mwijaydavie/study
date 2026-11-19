import semester from './data/semester.json' with { type: 'json' };

export { semester };
export const { courses, sessions, timezone } = semester;
export const weekdays = [1, 2, 3, 4, 5];
export const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
export const kindLabels = { lecture: 'Lecture', practical: 'Practical / Tutorial', chapel: 'Chapel' };

const dateParts = new Intl.DateTimeFormat('en-GB', {
  timeZone: timezone,
  weekday: 'long', year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
});
const dayAndMonth = new Intl.DateTimeFormat('en-GB', {
  timeZone: timezone, weekday: 'short', day: 'numeric', month: 'short',
});
const weekDay = new Intl.DateTimeFormat('en-GB', { timeZone: 'UTC', day: 'numeric', month: 'short' });
const weekEnd = new Intl.DateTimeFormat('en-GB', { timeZone: 'UTC', day: 'numeric', month: 'short', year: 'numeric' });
const dayMs = 86_400_000;

export function minutesOf(time) {
  const [hour, minute] = time.split(':').map(Number);
  return hour * 60 + minute;
}

export function duration(item) {
  return minutesOf(item.end) - minutesOf(item.start);
}

export function formatDuration(minutes) {
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return [hours && `${hours}h`, rest && `${rest}m`].filter(Boolean).join(' ') || '0m';
}

export function sessionsFor(day) {
  return sessions.filter((session) => session.day === day);
}

export function eatClock(instant = new Date()) {
  const parts = Object.fromEntries(dateParts.formatToParts(instant).map(({ type, value }) => [type, value]));
  const day = days.indexOf(parts.weekday);
  const midnight = Date.UTC(+parts.year, +parts.month - 1, +parts.day);
  const monday = new Date(midnight - ((day + 6) % 7) * dayMs);
  const sunday = new Date(monday.getTime() + 6 * dayMs);
  const first = monday.getUTCMonth() === sunday.getUTCMonth() ? monday.getUTCDate() : weekDay.format(monday);
  return {
    day, minute: +parts.hour * 60 + +parts.minute,
    label: dayAndMonth.format(instant), weekKey: monday.toISOString().slice(0, 10),
    weekLabel: `${first}–${weekEnd.format(sunday)}`,
  };
}

export function upcomingSession({ day, minute }) {
  const weekdaysAhead = 7;
  for (let offset = 0; offset <= weekdaysAhead; offset += 1) {
    const session = sessionsFor((day + offset) % 7).find((item) => offset || minutesOf(item.end) > minute);
    if (session) {
      const inProgress = offset === 0 && minutesOf(session.start) <= minute;
      return { session, offset, inProgress };
    }
  }
  return null;
}

export function sessionTitle(session) {
  return courses[session.code]?.title ?? 'Chapel';
}
