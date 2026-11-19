import test from 'node:test';
import assert from 'node:assert/strict';
import plan from '../src/data/plan.json' with { type: 'json' };
import { courses, duration, eatClock, minutesOf, sessions, sessionsFor, upcomingSession } from '../src/schedule.js';

const sourceRows = [
  [1, '08:00', '11:00', 'CS243', 'lecture', 'BH302', 'Mr. Florian'],
  [1, '11:00', '14:00', 'IS274', 'lecture', 'BH302', 'Mr. Gambadu'],
  [2, '11:00', '14:00', 'IS264', 'lecture', 'BH301', 'Mr. Jonas'],
  [2, '14:00', '15:30', 'ST119', 'practical', 'Computer Lab', 'Mr. Nyamu'],
  [3, '08:00', '09:30', 'IS264', 'practical', 'Computer Lab', 'Mr. Jonas'],
  [3, '11:00', '12:00', null, 'chapel', 'Church Venue', null],
  [3, '14:00', '17:00', 'IS237', 'lecture', 'BH301', 'Mr. Gambadu'],
  [4, '08:00', '09:30', 'IS237', 'practical', 'Computer Lab', 'Mr. Gambadu'],
  [4, '11:00', '14:00', 'FN200', 'lecture', 'BH301', 'Mr. James'],
  [5, '08:00', '11:00', 'ST119', 'lecture', 'BH302', 'Mr. Nyamu'],
  [5, '11:00', '14:00', 'IS274', 'practical', 'BH301', 'Mr. Gambadu'],
  [5, '14:00', '15:30', 'CS243', 'practical', 'Computer Lab', 'Mr. Florian'],
];
const at = (value) => eatClock(new Date(value));

test('every session matches the BIT Year 2 draft, page 2, with no empty rows', () => {
  assert.deepEqual(sessions.map(({ day, start, end, code, kind, venue }) => [day, start, end, code, kind, venue, courses[code]?.lecturer ?? null]), sourceRows);
  assert.equal(sessions.reduce((total, row) => total + duration(row), 0), 28 * 60);
  assert.equal(sessionsFor(6).length, 0);
});

test('the EAT clock rolls over at 21:00 UTC, including the study week', () => {
  const sunday = at('2026-11-22T20:59:59Z');
  assert.equal(sunday.day, 0);
  assert.equal(sunday.minute, 1439);
  assert.equal(sunday.weekKey, '2026-11-16');
  const monday = at('2026-11-22T21:00:00Z');
  assert.equal(monday.day, 1);
  assert.equal(monday.minute, 0);
  assert.equal(monday.weekKey, '2026-11-23');
  assert.equal(monday.weekLabel, '23–29 Nov 2026');
});

test('next session prefers the current session and switches at a boundary', () => {
  const before = upcomingSession(at('2026-11-23T04:59:00Z'));
  assert.equal(before.session.id, 'mon-cs243');
  assert.equal(before.inProgress, false);
  const start = upcomingSession(at('2026-11-23T05:00:00Z'));
  assert.equal(start.session.id, 'mon-cs243');
  assert.equal(start.inProgress, true);
  const boundary = upcomingSession(at('2026-11-23T08:00:00Z'));
  assert.equal(boundary.session.id, 'mon-is274');
  assert.equal(boundary.inProgress, true);
});

test('next session skips overnight and weekends, and includes Chapel', () => {
  const afterFriday = upcomingSession(at('2026-11-20T12:30:00Z'));
  assert.equal(afterFriday.session.id, 'mon-cs243');
  assert.equal(afterFriday.offset, 3);
  assert.equal(upcomingSession(at('2026-11-22T10:00:00Z')).offset, 1);
  assert.equal(upcomingSession(at('2026-11-18T07:00:00Z')).session.id, 'wed-chapel');
});

test('suggested study blocks leave a gap after and before any class', () => {
  assert.deepEqual(new Set(plan.map(({ code }) => code)), new Set(Object.keys(courses)));
  for (const item of plan) {
    assert.ok(duration(item) >= 30);
    for (const session of sessionsFor(item.day)) {
      assert.ok(minutesOf(item.end) + 10 <= minutesOf(session.start) || minutesOf(item.start) >= minutesOf(session.end) + 10);
    }
  }
});
