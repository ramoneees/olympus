# Heartbeat Tasks

## Daily Briefing (07:00, Monday–Friday)

When the heartbeat poll arrives between 06:50–07:20 on a weekday:

**You (Hermes) must call these MCP tools directly — do NOT delegate to subagents.**

1. Call Google Calendar MCP tools → today's events (all accounts)
2. Call TickTick MCP tools → pending tasks due today + overdue tasks
3. Build a concise briefing **in Portuguese**:
   - 📅 Agenda do dia (events, times)
   - ✅ Tarefas pendentes (by priority)
   - ⚠️ Itens vencidos (overdue)
4. Deliver as voice (sag) + text summary via WhatsApp to +351926565596
5. Respond HEARTBEAT_OK

If outside 06:50–07:20 or not a weekday → respond HEARTBEAT_OK.

---

## Weekly Briefing (08:00, Monday)

When the heartbeat poll arrives between 07:50–08:20 on a Monday:

**You (Hermes) must call these MCP tools directly — do NOT delegate to subagents.**

1. Call Google Calendar MCP tools → this week's events (all accounts)
2. Call TickTick MCP tools → this week's tasks + overdue tasks
3. Build a weekly briefing **in Portuguese**:
   - 📅 Visão da semana (events by day)
   - ✅ Tarefas da semana (by day/priority)
   - ⚠️ Débitos acumulados (overdue backlog)
   - 📊 Resumo de progresso
4. Deliver as voice (sag) + text summary via WhatsApp to +351926565596
5. Respond HEARTBEAT_OK

If not Monday or outside 07:50–08:20 → respond HEARTBEAT_OK.

---

## General Rules

- Outside the time windows above → HEARTBEAT_OK
- If MCP tools are unavailable → send error message via WhatsApp and HEARTBEAT_OK
- Use `sag` for voice generation, `wacli` to send the audio file
- All briefing content must be written in Portuguese (PT)
