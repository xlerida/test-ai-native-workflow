#!/usr/bin/env bash
# ============================================================
# OpenClaw Multi-Agent Setup: Orchestrator + 3 Specialists
# ============================================================
# Prerequisites:
#   - openclaw installed and onboarded (openclaw onboard)
#   - GitHub CLI installed and authenticated (gh auth login)
#   - git configured with push access to your repo
# ============================================================

set -e

# -------------------------------------------------------
# 0. Check prerequisites
# -------------------------------------------------------
echo ""
echo "==> Checking prerequisites..."

if ! command -v gh &>/dev/null; then
  echo "ERROR: GitHub CLI (gh) is not installed."
  echo "Install it from https://cli.github.com/ then run: gh auth login"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "ERROR: GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

echo "GitHub CLI: $(gh --version | head -1) — authenticated."

if ! command -v openclaw &>/dev/null; then
  echo "OpenClaw not found. Installing..."
  npm install -g openclaw@latest
  openclaw onboard --install-daemon
fi

echo "OpenClaw $(openclaw --version) ready."

# -------------------------------------------------------
# 1. Ask for repo path
# -------------------------------------------------------
echo ""
echo "Enter the absolute path to your project repository."
read -rp "Repo path (e.g. /Users/you/projects/myapp): " REPO_PATH

if [ ! -d "$REPO_PATH" ]; then
  echo "ERROR: Directory '$REPO_PATH' does not exist. Aborting."
  exit 1
fi

if [ ! -d "$REPO_PATH/.git" ]; then
  echo "WARNING: '$REPO_PATH' does not appear to be a git repo (no .git folder)."
  read -rp "Continue anyway? (y/N): " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 1
fi

echo "==> Repo: $REPO_PATH"

# -------------------------------------------------------
# 2. Create agent workspaces
# -------------------------------------------------------
echo ""
echo "==> Creating agent workspaces..."

openclaw agents add orchestrator
openclaw agents add arch_design
openclaw agents add implementation
openclaw agents add reviewer

echo "Agents created."

# -------------------------------------------------------
# 3. Write SOUL.md files
# -------------------------------------------------------

write_soul() {
  local agent_id="$1"
  local content="$2"
  local persona_dir="$HOME/.openclaw/persona-${agent_id}"
  mkdir -p "$persona_dir"
  printf '%s' "$content" > "${persona_dir}/SOUL.md"
}

write_soul "orchestrator" "# Orchestrator Agent

You are the **Orchestrator** in a multi-agent software development team.

## Role
- Receive tasks from the developer
- Decompose tasks into sub-tasks for your three specialists
- Coordinate: arch_design → implementation → reviewer
- Manage the review loop between implementation and reviewer
- Return the final approved PR link to the developer

## Specialists
- **arch_design** — architecture and design decisions
- **implementation** — coding, branching, committing, pushing, opening PRs
- **reviewer** — GitHub PR review, comments, approval

## Hard Rules
- Never write code yourself — delegate to implementation
- Never review PRs yourself — delegate to reviewer
- Always wait for reviewer approval before returning to the developer
- Return exactly one thing to the developer: the approved PR link
"

write_soul "arch_design" "# Architecture & Design Specialist

You are the **Architecture and Design** specialist.

## Role
- Define system architecture, component structure, and design patterns
- Produce a clear, actionable design spec the implementation agent can follow directly
- Respond to tasks delegated from the Orchestrator

## Hard Rules
- Do not implement code — design only
- Always explain your architectural decisions and trade-offs
- Flag any risks in the design
"

write_soul "implementation" "# Implementation & Coding Specialist

You are the **Implementation and Coding** specialist.

## Role
- Implement code based on the architecture spec from arch_design
- Own the full git and GitHub PR lifecycle:
  checkout → branch → implement → commit → push → open PR
- Receive review comments from the reviewer (via the Orchestrator) and resolve them
- Push fixes and request re-review

## Hard Rules
- Never write code directly on main, master, or develop
- Never skip error handling
- Always follow the architecture spec provided
- Commit logical units of work with clear commit messages
- You open the PR — the developer does not
"

write_soul "reviewer" "# Reviewer Specialist

You are the **Reviewer** specialist.

## Role
- Review PRs opened by the implementation agent on GitHub using gh CLI
- Add inline and general review comments where needed
- If the PR is acceptable: approve it and report back to the Orchestrator
- If changes are needed: leave comments and request changes, report back to the Orchestrator

## Hard Rules
- Never approve a PR with missing error handling
- Never approve a PR that doesn't match the architecture spec
- Always be specific in comments — reference file and line number where possible
- You approve or request-changes — never merge
"

echo "SOUL.md files written."

# -------------------------------------------------------
# 4. Write AGENTS.md files
# -------------------------------------------------------

write_agents_md() {
  local agent_id="$1"
  local content="$2"
  local persona_dir="$HOME/.openclaw/persona-${agent_id}"
  mkdir -p "$persona_dir"
  printf '%s' "$content" > "${persona_dir}/AGENTS.md"
}

write_agents_md "orchestrator" "# Orchestrator: Standing Orders

## Task flow

When you receive a task from the developer:

1. **Extract ticket ID and title** (e.g. 'GHA-9999: Make the header white')
2. **Compute branch name** using Branch Rules below — pass it to implementation
3. **Send to arch_design**: full task description, ask for architecture + design spec
4. **Wait** for arch_design response
5. **Send to implementation**: architecture spec + branch name + ticket ID
   - implementation will: branch → implement → commit → push → open PR
   - Wait for implementation to return the PR URL
6. **Send to reviewer**: PR URL, architecture spec, ticket description
   - reviewer will inspect the PR on GitHub and either:
     a. Approve → return 'approved' + PR URL
     b. Request changes → return list of comments
7. **If reviewer requests changes**:
   - Send comments back to implementation
   - Implementation pushes fixes
   - Send updated PR back to reviewer
   - Repeat until approved
8. **Once approved**: return to the developer:
   - PR URL
   - One-line summary of what was done

---

## Branch Rules (MANDATORY)

Format: TICKET-ID_TitleInPascalCase
Example: GHA-9999_MakeHeaderWhite

- Never allow commits to main, master, or develop
- Always pass the computed branch name to implementation before it starts

---

## Final response to developer

Once reviewer approves, send exactly this to the developer:

---
✅ PR approved and ready for your review.

**PR:** <url>
**Branch:** <branch>
**Summary:** <one sentence>

Merge when ready.
---
"

write_agents_md "arch_design" "# Architecture Agent: Standing Orders

When delegated a task by the Orchestrator:
1. Analyse the requirements
2. Propose architecture (components, interfaces, patterns, file locations)
3. Produce a structured spec the implementation agent can follow step by step
4. Return spec to Orchestrator
"

write_agents_md "implementation" "# Implementation Agent: Standing Orders

## Step 1 — Set up the branch

You will receive a branch name from the Orchestrator. Run these commands first, no exceptions:

  git -C <repo> checkout main   # or the default branch
  git -C <repo> pull origin main
  git -C <repo> checkout -b <branch_name>

Never write code on main/master/develop.

## Step 2 — Implement

Follow the architecture spec exactly. Write clean code with error handling.

## Step 3 — Commit and push

Commit logical units:
  git -C <repo> add -A
  git -C <repo> commit -m '[TICKET-ID] Short description'
  git -C <repo> push origin <branch_name>

## Step 4 — Open the PR

Use gh CLI to open the PR:

  gh pr create \
    --title 'TICKET-ID: Short title' \
    --body 'Description of what changed and why' \
    --base main \
    --head <branch_name>

Capture the PR URL from the output.

## Step 5 — Report back

Return to the Orchestrator:
  - PR URL
  - Branch name
  - Short summary of changes

## Step 6 — If the reviewer requests changes

When the Orchestrator sends you reviewer comments:
  - Fix each issue on the existing branch
  - Commit and push:
      git -C <repo> commit -am '[TICKET-ID] Address review: <brief description>'
      git -C <repo> push origin <branch_name>
  - Report back to Orchestrator: 'fixes pushed, ready for re-review'

## Hard Rules
- Never open more than one PR per task
- Never merge the PR — the developer does that
- Never commit to main/master/develop
"

write_agents_md "reviewer" "# Reviewer Agent: Standing Orders

When delegated a PR review by the Orchestrator:

## Step 1 — Check out the PR

  gh pr checkout <PR_NUMBER_OR_URL>

Or review without checking out:
  gh pr diff <PR_NUMBER_OR_URL>
  gh pr view <PR_NUMBER_OR_URL>

## Step 2 — Review the changes

Check:
- Does the implementation match the architecture spec?
- Is error handling present throughout?
- Are there any obvious bugs, security issues, or maintainability concerns?
- Is the code clean and readable?

## Step 3a — If changes are needed

  gh pr review <PR_NUMBER_OR_URL> \
    --request-changes \
    --body 'Summary of issues'

Add inline comments where needed:
  gh api repos/{owner}/{repo}/pulls/{pull_number}/comments \
    --method POST \
    -f body='Comment text' \
    -f path='path/to/file.ts' \
    -F line=42 \
    -f side='RIGHT' \
    -F commit_id=<latest_commit_sha>

Return to Orchestrator: list of issues found (match comments left on GitHub).

## Step 3b — If the PR is acceptable

  gh pr review <PR_NUMBER_OR_URL> --approve --body 'LGTM'

Return to Orchestrator: 'approved' + PR URL

## Hard Rules
- Never approve with missing error handling
- Never merge
- Always reference file + line in inline comments
- If re-reviewing after fixes: verify all previous comments are resolved before approving
"

echo "AGENTS.md files written."

# -------------------------------------------------------
# 5. Patch openclaw.json
# -------------------------------------------------------
echo ""
echo "==> Patching openclaw.json..."

node - "$REPO_PATH" <<'EOF'
const fs = require('fs');
const os = require('os');
const path = require('path');
const repoPath = process.argv[2];

const configPath = path.join(os.homedir(), '.openclaw', 'openclaw.json');
let config = {};

if (fs.existsSync(configPath)) {
  config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  fs.copyFileSync(configPath, configPath + '.bak');
  console.log('Backed up existing openclaw.json');
}

config.agents = config.agents || {};
config.agents.defaults = config.agents.defaults || {};

const newAgents = [
  {
    id: 'orchestrator',
    workspace: repoPath,
    agentDir: path.join(os.homedir(), '.openclaw', 'agents', 'orchestrator', 'agent'),
    personaDir: path.join(os.homedir(), '.openclaw', 'persona-orchestrator'),
  },
  {
    id: 'arch_design',
    workspace: repoPath,
    agentDir: path.join(os.homedir(), '.openclaw', 'agents', 'arch_design', 'agent'),
    personaDir: path.join(os.homedir(), '.openclaw', 'persona-arch_design'),
    tools: { allow: ['read', 'message'], deny: ['exec', 'write', 'apply_patch'] },
  },
  {
    id: 'implementation',
    workspace: repoPath,
    agentDir: path.join(os.homedir(), '.openclaw', 'agents', 'implementation', 'agent'),
    personaDir: path.join(os.homedir(), '.openclaw', 'persona-implementation'),
    tools: { allow: ['exec', 'write', 'read', 'message'], deny: ['browser'] },
  },
  {
    id: 'reviewer',
    workspace: repoPath,
    agentDir: path.join(os.homedir(), '.openclaw', 'agents', 'reviewer', 'agent'),
    personaDir: path.join(os.homedir(), '.openclaw', 'persona-reviewer'),
    // exec needed for gh CLI; deny write/apply_patch so it can't touch code
    tools: { allow: ['exec', 'read', 'message'], deny: ['write', 'apply_patch'] },
  },
];

const existing = config.agents.list || [];
for (const agent of newAgents) {
  const idx = existing.findIndex(a => a.id === agent.id);
  if (idx >= 0) {
    existing[idx] = { ...existing[idx], ...agent };
  } else {
    existing.push(agent);
  }
}
config.agents.list = existing;
config.agents.defaults.agentId = 'orchestrator';

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
console.log('openclaw.json updated. Repo: ' + repoPath);
EOF

# -------------------------------------------------------
# 6. Done
# -------------------------------------------------------
echo ""
echo "============================================="
echo " Setup complete!"
echo "============================================="
echo ""
echo "Repo:   $REPO_PATH"
echo "Agents: orchestrator, arch_design, implementation, reviewer"
echo ""
echo "Next steps:"
echo "  1. openclaw gateway restart"
echo "  2. openclaw agents list --bindings    # verify all 4 agents"
echo "  3. Talk to your orchestrator!"
echo ""
echo "Flow:"
echo "  You → Orchestrator → arch_design → implementation → reviewer"
echo "                                   ↑_________↓ (review loop)"
echo "  Orchestrator returns approved PR link to you."
echo "============================================="