## How to invoke

Trigger phrases (any of these will route the agent to this skill):

- "Triage Dependabot alerts in `<repo>`"
- "Which vuln should I fix first? <github.com/.../security/dependabot URL>"
- "Fix Dependabot alert #<N> in this repo"
- "Bump `<pkg>` to a non-vulnerable version"

Provide one of:
- Repo-level Dependabot security URL (`github.com/<org>/<repo>/security/dependabot`), OR
- Repo path + alert number(s), OR
- Just the package name if you already know the vuln.

**Org-level fan-out is opt-in only.** Even if the user pastes an org URL (`github.com/orgs/<org>/security/alerts/dependabot`), do NOT auto-enumerate the entire org. Confirm first: "This will paginate alerts across every repo in the org and may use significant API rate limit. Proceed?" Then run only on `yes`. The trigger phrases for explicit org fan-out:
- "Fan out across the org"
- "Triage all repos in `<org>`"
- "Run org-wide triage"
