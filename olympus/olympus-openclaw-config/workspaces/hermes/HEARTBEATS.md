# Heartbeats

Automated, hook-triggered routines. Each heartbeat is fired by an n8n scheduled workflow that POSTs to the OpenClaw hooks endpoint. Hermes executes the routine and delivers the result via the specified channel.

---

## Daily Briefing

- **Schedule**: 08:00 Europe/Lisbon, every day
- **Trigger**: hook, sessionKey `briefing:daily`
- **Deliver via**: WhatsApp

### Steps

1. `gcal_list_calendars` → discover all calendar IDs
2. For EACH calendar (personal + work): `gcal_list_events` with today's date range
3. TickTick MCP tools → today's tasks and calendar items
4. Spawn Athena: "Find today's Bible verse of the day. Return only the verse reference and full text, nothing else."
5. Consolidate and deliver via WhatsApp

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

- **Schedule**: Sunday 20:00 Europe/Lisbon
- **Trigger**: hook, sessionKey `briefing:weekly`
- **Deliver via**: WhatsApp

### Steps

1. `gcal_list_calendars` → discover all calendar IDs
2. For EACH calendar (personal + work): `gcal_list_events` for the full week (Monday–Sunday)
3. TickTick MCP tools → this week's tasks
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
