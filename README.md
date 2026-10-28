# M365 AI Agent Hardening Kit: Top 5 (free)

Five controls to put guardrails around AI agents in Microsoft 365: Copilot Studio agents (including agents built in Microsoft 365 Copilot Agent Builder) and Microsoft Entra agent identities. Packaged as a project you can run this week: guide, Jira backlog, tracker and read-only PowerShell checks.

| File | What it is |
|---|---|
| `m365-ai-agent-hardening-kit-top-5-guide.md` | Why, steps, impact, rollback, check, verify, licence, effort and the Microsoft Learn source for each control |
| `m365-ai-agent-hardening-kit-top-5-jira-import.csv` | Jira Cloud import: epics + stories with parent links, priority, sprint and labels |
| `m365-ai-agent-hardening-kit-top-5-tracker.csv` | Same backlog for Planner, Azure DevOps, Excel or Linear |
| `m365-ai-agent-hardening-kit-top-5-project-plan.xlsx` | Excel project plan for teams without Jira: owner, dates, status drop-down, % complete and a progress dashboard by area and sprint |
| `m365-ai-agent-hardening-kit-top-5-readonly-checks.ps1` | Get-* / Search-* cmdlets and Graph GET requests only. Changes nothing. Writes `hardening-check-results.csv` |

| # | Control | Needs Agent 365? |
|---|---|---|
| AG01 | Inventory every agent in the tenant | No |
| AG02 | Require user authentication for Copilot Studio agents | No |
| AG03 | Block HTTP requests and channels you don't use | No |
| AG04 | Watch agent creation, publishing, sharing and authentication changes | No |
| AG05 | Block high-risk agent identities with Conditional Access | Yes (+ Entra ID P2 or M365 E5) |

## Import into Jira
Jira Cloud > Settings > System > External system import > CSV. Map `Issue ID` and `Parent` so stories land under their epics.

## Run the checks
```powershell
Install-Module Microsoft.Graph, ExchangeOnlineManagement, Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser
Connect-MgGraph -Scopes AgentIdentity.Read.All,Policy.Read.All
Connect-ExchangeOnline
Add-PowerAppsAccount
./m365-ai-agent-hardening-kit-top-5-readonly-checks.ps1
```

## Scope and limits
- Built from Microsoft Learn (links in the guide; re-read 24 and 28 October 2026). Validated before release: every control has why, steps, impact, rollback, verify, licence and a Learn source; the script contains read commands only and parses cleanly in PowerShell 7.4; the Excel plan recalculates with no errors. If a check misreads your setup, open an issue.
- Get-DlpPolicy output is not documented by Microsoft, so AG02 and AG03 search the policy JSON for connector names. Treat a "referenced" result as a prompt to confirm the connector is in the Blocked group.
- Conditional Access for agent identities supports Block only, and a policy on agent identities does not cover agent users or agents acting on behalf of a user.
- Search-UnifiedAuditLog retires on 15 October 2027 (MC1505599); AG04 will move to the Graph AuditLogQuery API before then.

## Related
- **M365 Hardening Kit: Emergency Top 10** (free): the ten tenant-wide controls to do first → https://github.com/runbooklabhq/m365-hardening-kit-free
- **M365 Copilot Readiness Kit: Top 5** (free): fix oversharing before Copilot finds it → https://runbooklab.gumroad.com/l/copilot-readiness-top5?utm_source=free-kit

## Complete kit
All 20 controls plus an agent register (.xlsx) and an agent approval workflow: https://runbooklab.gumroad.com/l/ai-agent-hardening-kit?utm_source=github&utm_campaign=agents-free-repo

MIT licence. Not affiliated with or endorsed by Microsoft. Test changes in Report-only or on a pilot group first.
