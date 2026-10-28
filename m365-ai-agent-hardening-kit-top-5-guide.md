# M365 AI Agent Hardening Kit: Top 5

_Version 1.0 (2026-10-28; facts re-read on Microsoft Learn 2026-10-24, AG02 and AG05 again 2026-10-28; validated: quality gate, read-only guard, PowerShell 7.4 parse, Excel recalc)_

Five controls to put guardrails around AI agents in Microsoft 365: Copilot Studio agents and Microsoft Entra agent identities. Free. Each control has why, steps, a read-only PowerShell check, how to verify, licence, effort and the Microsoft Learn page it is based on. Controls AG01-AG04 work without Microsoft Agent 365. AG05 needs Agent 365, and the guide says so.

Read-only checks: run `m365-ai-agent-hardening-kit-top-5-readonly-checks.ps1` (read-only, changes nothing).

| # | Control | Area | Sprint | Priority | Effort |
|---|---|---|---|---|---|
| AG01 | Inventory every agent in the tenant | Agent inventory & monitoring | Sprint 1 - AI agent baseline | Highest | 1 h |
| AG02 | Require user authentication for Copilot Studio agents | Copilot Studio guardrails | Sprint 1 - AI agent baseline | Highest | 30 min |
| AG03 | Block HTTP requests and channels you don't use | Copilot Studio guardrails | Sprint 1 - AI agent baseline | High | 1 h |
| AG04 | Watch agent creation, publishing, sharing and authentication changes | Agent inventory & monitoring | Sprint 1 - AI agent baseline | High | 1 h |
| AG05 | Block high-risk agent identities with Conditional Access | Agent identities (Microsoft Entra Agent ID) | Sprint 1 - AI agent baseline | High | 30 min |

## AG01. Inventory every agent in the tenant

**Why:** You cannot govern agents you cannot see. Agents show up in two places: Copilot Studio agents in Power Platform environments, and Microsoft Entra agent identities, which act with their own permissions. Most tenants have never listed either.

**Steps:**
1. Power Platform admin center > Manage > Inventory (or Manage > Copilot Studio). It lists agents built in Copilot Studio and in Microsoft 365 Copilot Agent Builder. Select Download to export the full list to CSV with owner, environment and created date.
2. Entra agent identities: Microsoft Entra admin center > Agent ID, or run the read-only check below (Microsoft Graph, AgentIdentity.Read.All).
3. Record an owner and a business purpose for every agent in the tracker. An agent without a named owner goes on the review list.
4. Repeat monthly. New agents appear without any admin action.

**Impact:** None. The inventory export and the Graph check only read data.

**Rollback:** Nothing to roll back.

**Check (read-only PowerShell):**

```powershell
$u = 'https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentity?$select=id,displayName,accountEnabled,agentIdentityBlueprintId,createdDateTime'; $all = @(); while ($u) { $r = Invoke-MgGraphRequest -Method GET -Uri $u; $all += $r.value; $u = $r.'@odata.nextLink' }; "Agent identities: $($all.Count)"; $all | ForEach-Object { "$($_.displayName) | enabled: $($_.accountEnabled) | created: $($_.createdDateTime)" }
```

**Verify:** Every Copilot Studio agent and every agent identity has an owner and a purpose recorded in the tracker.

**Licence:** Any Microsoft 365 tenant. Inventory: Power Platform administrator, Global reader, or AI reader. Agent identities: AgentIdentity.Read.All (Agent ID Administrator for non-owners). · **Effort:** 1 h · **Priority:** Highest · **Sprint 1 - AI agent baseline**

**Microsoft Learn:** https://learn.microsoft.com/en-us/power-platform/admin/power-platform-inventory · https://learn.microsoft.com/en-us/graph/api/agentidentity-list?view=graph-rest-1.0

## AG02. Require user authentication for Copilot Studio agents

**Why:** An agent published with No authentication can be used by anyone who reaches its channel, and it answers from whatever knowledge and tools the maker connected. Blocking one connector in a data policy makes authentication mandatory for publishing.

**Steps:**
1. Power Platform admin center > Security > Data and privacy > Data policy.
2. Edit the policy that covers your Copilot Studio environments (or create one) and add the environments.
3. On Assign connectors, find 'Chat without Microsoft Entra ID authentication in Copilot Studio' and select Block.
4. Save, then open an agent in Copilot Studio: agents without authentication show an error banner and cannot be published until the maker selects Authenticate with Microsoft or Authenticate manually.
5. Tell makers before you switch it on. Use the downloadable violation list on the agent's Channels page to follow up.

**Impact:** Makers can no longer publish agents set to No authentication: the Publish button is unavailable and an error banner appears until they choose Authenticate with Microsoft or Authenticate manually. Users must then sign in to chat with those agents. Microsoft Learn does not say whether agents already published without authentication keep working, so test on one environment first and tell makers before you switch it on.

**Rollback:** Data policy > Edit Policy: move the connector out of Blocked (or remove the environment from the policy) and select Update policy. Agent-level exemptions are no longer supported, so roll back per policy or environment.

**Check (read-only PowerShell):**

```powershell
$j = Get-DlpPolicy | ConvertTo-Json -Depth 30; if ($j -match 'Chat without Microsoft Entra ID authentication') { 'Connector is referenced in at least one data policy: confirm it is in the Blocked group for every Copilot Studio environment' } else { 'Connector not referenced in any data policy: agents can be published without authentication' }
```

**Verify:** Trying to publish a test agent with No authentication fails with a data policy error.

**Licence:** Power Platform admin (included with Copilot Studio) · **Effort:** 30 min · **Priority:** Highest · **Sprint 1 - AI agent baseline**

**Microsoft Learn:** https://learn.microsoft.com/en-us/microsoft-copilot-studio/dlp-example-3 · https://learn.microsoft.com/en-us/microsoft-copilot-studio/admin-data-loss-prevention

## AG03. Block HTTP requests and channels you don't use

**Why:** The HTTP connector lets an agent call any endpoint, which is the easiest exfiltration path. Public channels (Direct Line websites, Facebook, WhatsApp) put agents in front of people outside your tenant. Block what you don't use; allow specific endpoints where you need them.

**Steps:**
1. List the channels and HTTP endpoints your approved agents actually use (AG01 inventory).
2. In the data policy for Copilot Studio environments, block 'HTTP', or keep it and use Configure connector > Connector endpoints to allow only the endpoints you listed.
3. Block unused channels: 'Direct Line channels in Copilot Studio', 'Facebook channel in Copilot Studio', 'WhatsApp channel in Copilot Studio', 'Omnichannel in Copilot Studio', 'SharePoint channel in Copilot Studio'.
4. Block 'Skills with Copilot Studio' if no agent uses Azure Bot Service skills.
5. Keep connectors used together in the same data group (Business, Non-business or Blocked): mixing groups in one agent is a policy violation.

**Impact:** Agents that call blocked endpoints or use blocked channels stop working on those channels and show a data policy error in Copilot Studio. Agents that mix connectors from different data groups are flagged as violations.

**Rollback:** Move the connector or channel back to the Business or Non-business group in the same data policy and select Update policy.

**Check (read-only PowerShell):**

```powershell
$j = Get-DlpPolicy | ConvertTo-Json -Depth 30; foreach ($c in 'Direct Line channels in Copilot Studio','Facebook channel in Copilot Studio','WhatsApp channel in Copilot Studio','Omnichannel in Copilot Studio','SharePoint channel in Copilot Studio','Skills with Copilot Studio') { "$c referenced in a data policy: $($j -match [regex]::Escape($c))" }; "HTTP connector referenced: $($j -match '"HTTP"')"
```

**Verify:** In the data policy, HTTP is blocked or endpoint-filtered, and every channel not on your approved list is in the Blocked group.

**Licence:** Power Platform admin (included with Copilot Studio) · **Effort:** 1 h · **Priority:** High · **Sprint 1 - AI agent baseline**

**Microsoft Learn:** https://learn.microsoft.com/en-us/microsoft-copilot-studio/admin-data-loss-prevention

## AG04. Watch agent creation, publishing, sharing and authentication changes

**Why:** Copilot Studio logs maker activity to the Microsoft Purview audit log by default. The events that matter most are an agent being published, shared, or having its authentication changed. Reviewing them catches an agent that went public overnight.

**Steps:**
1. Microsoft Purview portal > Solutions > Audit. Filter Activities for Copilot Studio activities and save the search.
2. Review these operations weekly: BotCreate, BotUpdateOperation-BotPublish, BotUpdateOperation-BotShare, BotUpdateOperation-BotAuthUpdate, BotDelete.
3. If you use Microsoft Sentinel, send the audit events there and alert on BotUpdateOperation-BotAuthUpdate and BotUpdateOperation-BotShare.
4. For every unexpected event, confirm with the agent owner and record the outcome in the tracker.

**Impact:** None. Searching the audit log and saving a search change nothing. A Sentinel connector only adds ingestion cost for the events you send.

**Rollback:** Delete the saved search or disable the analytics rule.

**Check (read-only PowerShell):**

```powershell
$ops = 'BotCreate','BotUpdateOperation-BotPublish','BotUpdateOperation-BotShare','BotUpdateOperation-BotAuthUpdate','BotDelete'; $e = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date) -Operations $ops -ResultSize 5000; if (-not $e) { 'No Copilot Studio create/publish/share/auth/delete events in the last 30 days' } else { $e | Group-Object Operations | ForEach-Object { "$($_.Name): $($_.Count)" }; $e | Group-Object UserIds | ForEach-Object { "by $($_.Name): $($_.Count)" } }
```

**Verify:** A saved audit search (or SIEM rule) exists for the five operations, and last week's events were reviewed.

**Licence:** Microsoft 365 audit (Standard). Users need an assigned Microsoft 365 licence for Copilot Studio events to be recorded. · **Effort:** 1 h · **Priority:** High · **Sprint 1 - AI agent baseline**

**Microsoft Learn:** https://learn.microsoft.com/en-us/microsoft-copilot-studio/admin-logging-copilot-studio

## AG05. Block high-risk agent identities with Conditional Access

**Why:** Autonomous agents sign in with their own agent identity, not a user, so your user Conditional Access policies don't cover them. Microsoft provides a policy that blocks agent identities that Entra ID Protection flags as high risk.

**Steps:**
1. Microsoft Entra admin center > Entra ID > Conditional Access > Policies > New policy.
2. Users, agents or workload identities > What does this policy apply to? > Agents > Include: All agent identities.
3. Target resources > Include: All resources.
4. Conditions > Agent risk (Preview) > Configure: Yes > High.
5. Grant > Block. Enable policy: Report-only. Review the impact, then switch to On.
6. Agents that act through a user account or an agent user need separate policies: a policy on agent identities does not cover agent users.

**Impact:** Agent identities that ID Protection rates as high risk are blocked from signing in to all resources, including legitimate agents if the risk signal is a false positive. Agent users and agents acting on behalf of a user are not covered by this policy. Run it in Report-only first and check the sign-in logs for agents that would be blocked.

**Rollback:** Set Enable policy back to Report-only or Off. Keep the policy so you can switch it on again after the review.

**Check (read-only PowerShell):**

```powershell
$p = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { ($_ | ConvertTo-Json -Depth 10) -match 'agent' }; if (-not $p) { 'No Conditional Access policy references agents' } else { $p | ForEach-Object { "$($_.DisplayName) [state: $($_.State)]" } }
```

**Verify:** A policy targeting All agent identities with Agent risk = High and Block exists and is On (state: enabled) after the Report-only review.

**Licence:** Microsoft Agent 365 + Entra ID P2 or Microsoft 365 E5 (risk-based), or Microsoft 365 E7. Agent risk is in preview. · **Effort:** 30 min · **Priority:** High · **Sprint 1 - AI agent baseline**

**Microsoft Learn:** https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-agent-block-high-risk · https://learn.microsoft.com/en-us/entra/identity/conditional-access/agent-id

---
Not affiliated with or endorsed by Microsoft. Test every change in Report-only or on a pilot group first. Licence names and portal paths change; check Microsoft Learn if a menu has moved.
