# Heartbeats

Automated routines managed via OpenClaw native cron. Jobs are seeded on first boot and persist at `~/.openclaw/cron/jobs.json`.

---

## Daily Briefing

- **Cron job name**: `daily-briefing`
- **Schedule**: `0 8 * * *` (Europe/Lisbon), every day
- **Agent**: hermes
- **Session**: `session:briefing-daily` (persistent across runs)
- **Deliver via**: WhatsApp

### Steps

**You (Hermes) must call these MCP tools directly — do NOT delegate to subagents.**

1. Call `google-calendar__list-calendars` → discover all calendar IDs (both personal and work accounts)
2. For EACH calendar: call `google-calendar__list-events` with today's date range (timeMin/timeMax as ISO 8601)
3. Call TickTick MCP tools directly (`ticktick__list_projects`, then relevant task queries) → today's tasks
4. Spawn Athena (the ONLY delegation step): "Find today's Bible verse of the day. Return only the verse reference and full text, nothing else."
5. Consolidate all results and deliver via WhatsApp

### Format

```
Good morning, Ramon.

**Today's Agenda** (Day, DD Month YYYY)

📅 Calendar
- HH:MM — Event title [Calendar Name]
- HH:MM — Event title [Calendar Name]
(or "No events today.")

✅ Tasks
- Task title (due/priority if set)
(or "No tasks due today.")

📖 Verse of the Day
> "Verse text" — Book Chapter:Verse

Have a good day.
```

### Rules

- If any data source fails (gcal, TickTick, Athena), include what you have and note the failure briefly.
- Do NOT include news — that is a separate on-demand workflow.

---

## Weekly Briefing

- **Cron job name**: `weekly-briefing`
- **Schedule**: `0 20 * * 0` (Europe/Lisbon), every Sunday
- **Agent**: hermes
- **Session**: `session:briefing-weekly` (persistent across runs)
- **Deliver via**: WhatsApp

### Steps

**You (Hermes) must call these MCP tools directly — do NOT delegate to subagents.**

1. Call `google-calendar__list-calendars` → discover all calendar IDs (both personal and work accounts)
2. For EACH calendar: call `google-calendar__list-events` for the full week (Monday–Sunday, ISO 8601 timeMin/timeMax)
3. Call TickTick MCP tools directly → this week's tasks
4. Consolidate by day of week and deliver via WhatsApp

### Format

```
**Week Ahead** (DD Mon – DD Mon YYYY)

**Monday**
- HH:MM — Event [Calendar]
- Task

**Tuesday**
- HH:MM — Event [Calendar]
...
(skip empty days or mark "Free")

**Summary**
- N events, N tasks
- Busiest day: Day (N items)
- Free days: Day, Day

Have a good week.
```

### Rules

- Group events and tasks by day of week. Skip empty days or mark them as "Free."
- If any data source fails, include what you have and note the failure.
