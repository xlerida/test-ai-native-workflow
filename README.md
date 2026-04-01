# orchestrator-workspace

An AI coordinator workspace that delegates all work to specialist agents via message-passing.

## How It Works

The orchestrator receives a ticket, breaks it into stages, and delegates each stage to the appropriate specialist agent via `sessions_send`. It never writes code, creates files, or runs commands directly — all execution is handled by specialists. The orchestrator synthesises results and reports back to the developer once the full pipeline completes.

## Specialist Agents

| Agent | Role |
|---|---|
| `arch_design` | Produces design specs from ticket descriptions |
| `implementation` | Creates branch, implements, commits, pushes, opens PR |
| `reviewer` | Reviews PR on GitHub; approves or requests changes |

## Workflow

1. Parse ticket ID & title → compute branch name
2. Message `arch_design` → wait for spec
3. Message `implementation` → wait for PR URL
4. Message `reviewer` → wait for approval
5. Handle review loop until approved
6. Report PR URL to developer

## Key Files

| File | Purpose |
|---|---|
| `AGENTS.md` | Session startup order, memory conventions, and workspace rules |
| `SOUL.md` | Core identity, values, and behavioural boundaries |
| `IDENTITY.md` | Agent name, creature, vibe, and emoji |
| `USER.md` | Information about the human collaborator |
| `TOOLS.md` | Environment-specific notes (SSH hosts, device names, etc.) |

## Constraints

- The orchestrator never writes code, creates files, or runs commands
- All work is delegated via `sessions_send` to named specialist agents
- `sessions_spawn` is banned
