# Tekton × Paperclip Setup Plan

Guide to set up the Tekton dev team in Paperclip at `https://paperclip.ramoneees.com`.

## Prerequisites

- [x] Paperclip running and account created
- [x] OpenClaw Tekton running at `openclaw-tekton.olympus.svc.cluster.local:18790`
- [x] Tekton gateway token: `1536e22daced3abe5b65775f335b2a6c1be260f175f9dbe1`
- [x] Gitea org `tekton` created with all agent users
- [ ] Agent avatar images generated (use prompts from `agent-avatar-prompts.txt`)

---

## Step 1: Create the Company

In Paperclip UI → "New Company":

| Field       | Value                                                                 |
|-------------|-----------------------------------------------------------------------|
| Name        | **Tekton**                                                            |
| Description | AI-powered software development studio. Builds projects autonomously. |

## Step 2: Set the Company Goal

After creating the company, set the top-level goal:

> **"Build and ship high-quality software projects — from architecture to deployment — as an autonomous dev team."**

This is the north star. All tasks trace back to it.

## Step 3: Hire the CEO (Apollo)

First agent must be the CEO — the top of the org chart.

| Field          | Value                                                                             |
|----------------|-----------------------------------------------------------------------------------|
| Name           | `apollo`                                                                          |
| Display Name   | Apollo                                                                            |
| Role/Title     | CTO / Chief Technology Officer                                                    |
| Capabilities   | Orchestrates the dev team. Breaks down goals into projects and tasks. Delegates work to engineers, reviews architecture decisions, manages priorities with Daedalus. |
| Adapter Type   | `openclaw_gateway`                                                                |
| Adapter Config | See below                                                                         |
| Reports To     | *(none — CEO)*                                                                    |
| Avatar         | Upload Apollo avatar image                                                        |

**Apollo Adapter Config:**
```json
{
  "gatewayUrl": "ws://openclaw-tekton.olympus.svc.cluster.local:18790",
  "token": "1536e22daced3abe5b65775f335b2a6c1be260f175f9dbe1",
  "agentId": "apollo"
}
```

## Step 4: Hire the Rest of the Team

Create each agent in order. All use adapter type `openclaw_gateway` with the same `gatewayUrl` and `token`, but different `agentId`.

### Daedalus — Product Owner
| Field          | Value |
|----------------|-------|
| Name           | `daedalus` |
| Role/Title     | Product Owner |
| Reports To     | **Apollo** |
| Capabilities   | Defines product specs and user stories. Prioritizes backlog. Plans sprints. Writes acceptance criteria. Researches market and user needs. |
| Adapter agentId| `daedalus` |

### Metis — Architect
| Field          | Value |
|----------------|-------|
| Name           | `metis` |
| Role/Title     | Software Architect |
| Reports To     | **Apollo** |
| Capabilities   | Designs system architecture. Writes technical RFCs. Reviews design decisions. Defines service boundaries, data models, and API contracts. |
| Adapter agentId| `metis` |

### Vulcan — Lead Engineer
| Field          | Value |
|----------------|-------|
| Name           | `vulcan` |
| Role/Title     | Lead Engineer (Backend/Fullstack) |
| Reports To     | **Apollo** |
| Capabilities   | Writes backend code, APIs, business logic. Implements core features. Reviews PRs. Mentors other engineers. |
| Adapter agentId| `vulcan` |

### Arachne — Frontend Engineer
| Field          | Value |
|----------------|-------|
| Name           | `arachne` |
| Role/Title     | Frontend Engineer |
| Reports To     | **Vulcan** |
| Capabilities   | Builds UI components, pages, and interactions. Implements designs. Handles CSS, React/Next.js, accessibility. |
| Adapter agentId| `arachne` |

### Cyclops — DevOps / Infrastructure
| Field          | Value |
|----------------|-------|
| Name           | `cyclops` |
| Role/Title     | DevOps / Infrastructure Engineer |
| Reports To     | **Apollo** |
| Capabilities   | Manages CI/CD pipelines, Docker images, K8s manifests, Gitea Actions. Handles deployments, monitoring, and infrastructure-as-code. |
| Adapter agentId| `cyclops` |

### Argos — QA / Code Reviewer
| Field          | Value |
|----------------|-------|
| Name           | `argos` |
| Role/Title     | QA Engineer / Code Reviewer |
| Reports To     | **Vulcan** |
| Capabilities   | Reviews all code before merge. Writes and runs tests. Identifies bugs, security issues, and performance problems. Nothing ships without Argos approval. |
| Adapter agentId| `argos` |

## Step 5: Org Chart

After all agents are created, verify the hierarchy:

```
You (Board Operator / ramoneees)
 └── Apollo (CTO)
      ├── Daedalus (Product Owner)
      ├── Metis (Architect)
      ├── Vulcan (Lead Engineer)
      │    ├── Arachne (Frontend)
      │    └── Argos (QA)
      └── Cyclops (DevOps)
```

## Step 6: Set Budgets

Budgets are in dollars/month (token spend tracked by Paperclip).
Suggested starting budgets — conservative, increase as you validate:

| Agent    | Monthly Budget | Rationale                                    |
|----------|---------------|----------------------------------------------|
| Apollo   | $60           | Orchestration uses moderate tokens            |
| Daedalus | $30           | Mostly text generation (specs, stories)       |
| Metis    | $40           | Architecture docs, deep reasoning             |
| Vulcan   | $80           | Heaviest coding workload                      |
| Arachne  | $60           | Frontend coding, moderate volume              |
| Cyclops  | $40           | IaC, configs, pipeline work                   |
| Argos    | $50           | Reviews all code, reasoning-heavy model       |
| **Total**| **$360/mo**   |                                               |

Paperclip will warn at 80% and auto-pause at 100%.

## Step 7: Configure Heartbeats

Heartbeats are how agents wake up and check for work. Set per agent:

| Agent    | Interval  | Rationale                                       |
|----------|-----------|------------------------------------------------|
| Apollo   | 30 min    | Checks for new goals, delegates frequently      |
| Daedalus | 60 min    | Plans change less often                          |
| Metis    | 120 min   | Architecture reviews are infrequent              |
| Vulcan   | 15 min    | Active coding, needs fast task pickup            |
| Arachne  | 15 min    | Active coding, needs fast task pickup            |
| Cyclops  | 30 min    | Infra work is steady but not constant            |
| Argos    | 15 min    | Reviews should not block other engineers long    |

Agents also wake on **events**: task assignment, @-mentions, comments.

## Step 8: Create First Project

To test the full pipeline:

1. In Paperclip → create a **Project** under Tekton (e.g., "Hello Tekton")
2. Create a **Goal**: "Build a simple landing page for Tekton at tekton.ramoneees.com"
3. Create a **Task** and assign to **Apollo**: "Plan and coordinate building the Tekton landing page"
4. Apollo should:
   - Wake on next heartbeat
   - Break the task into subtasks
   - Delegate to Daedalus (specs), Metis (architecture), Vulcan/Arachne (implementation), Cyclops (deployment), Argos (review)

Monitor from the Paperclip dashboard — you should see tasks flowing through the org chart.

## Step 9: Verify End-to-End

Checklist:
- [ ] Paperclip dashboard shows all 7 agents as `active`
- [ ] Apollo's first heartbeat runs successfully
- [ ] Task delegation creates subtasks assigned to correct agents
- [ ] Engineers produce code commits to `git.ramoneees.com/tekton/*`
- [ ] Argos reviews PRs before merge
- [ ] Cost tracking shows token usage per agent
- [ ] Activity log shows full trace of all actions

## Connection Reference

| Service            | Internal URL                                                  |
|--------------------|---------------------------------------------------------------|
| Paperclip UI       | `https://paperclip.ramoneees.com`                             |
| Tekton Gateway     | `ws://openclaw-tekton.olympus.svc.cluster.local:18790`        |
| Tekton Gateway ext | `wss://tekton.ramoneees.com`                                  |
| Tekton Gateway Token| `1536e22daced3abe5b65775f335b2a6c1be260f175f9dbe1`           |
| Gitea Org          | `https://git.ramoneees.com/tekton`                            |
| LiteLLM            | `http://litellm.olympus.svc.cluster.local:4000`               |
