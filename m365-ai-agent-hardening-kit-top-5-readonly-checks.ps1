<#
 M365 AI Agent Hardening Kit: Top 5 - read-only checks (Runbook Lab)
 Read-only: Get-* and Search-* cmdlets and Microsoft Graph GET requests only. Changes nothing in your tenant.
 Requires: Microsoft.Graph (Conditional Access + agent identities), ExchangeOnlineManagement (audit search), Microsoft.PowerApps.Administration.PowerShell (data policies).
 Connect first:
   Connect-MgGraph -Scopes AgentIdentity.Read.All,Policy.Read.All
   Connect-ExchangeOnline
   Add-PowerAppsAccount
 Note: Microsoft retires Search-UnifiedAuditLog on 15 Oct 2027 (MC1505599). AG04 will move to the Graph AuditLogQuery API before then.
 Output: .\hardening-check-results.csv (ID, Control, Status, Output).
#>
$ErrorActionPreference = 'Stop'
$results = @()
function Invoke-Check($Id, $Title, [scriptblock]$Block) {
  try { $o = & $Block | Out-String -Width 400; $s = 'OK' } catch { $o = $_.Exception.Message; $s = 'ERROR' }
  Write-Host "[$Id] $Title -> $s"
  $script:results += [pscustomobject]@{ ID = $Id; Control = $Title; Status = $s; Output = $o.Trim() }
}

Invoke-Check 'AG01' 'Inventory every agent in the tenant' { $u = 'https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentity?$select=id,displayName,accountEnabled,agentIdentityBlueprintId,createdDateTime'; $all = @(); while ($u) { $r = Invoke-MgGraphRequest -Method GET -Uri $u; $all += $r.value; $u = $r.'@odata.nextLink' }; "Agent identities: $($all.Count)"; $all | ForEach-Object { "$($_.displayName) | enabled: $($_.accountEnabled) | created: $($_.createdDateTime)" } }
Invoke-Check 'AG02' 'Require user authentication for Copilot Studio agents' { $j = Get-DlpPolicy | ConvertTo-Json -Depth 30; if ($j -match 'Chat without Microsoft Entra ID authentication') { 'Connector is referenced in at least one data policy: confirm it is in the Blocked group for every Copilot Studio environment' } else { 'Connector not referenced in any data policy: agents can be published without authentication' } }
Invoke-Check 'AG03' 'Block HTTP requests and channels you don''t use' { $j = Get-DlpPolicy | ConvertTo-Json -Depth 30; foreach ($c in 'Direct Line channels in Copilot Studio','Facebook channel in Copilot Studio','WhatsApp channel in Copilot Studio','Omnichannel in Copilot Studio','SharePoint channel in Copilot Studio','Skills with Copilot Studio') { "$c referenced in a data policy: $($j -match [regex]::Escape($c))" }; "HTTP connector referenced: $($j -match '"HTTP"')" }
Invoke-Check 'AG04' 'Watch agent creation, publishing, sharing and authentication changes' { $ops = 'BotCreate','BotUpdateOperation-BotPublish','BotUpdateOperation-BotShare','BotUpdateOperation-BotAuthUpdate','BotDelete'; $e = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date) -Operations $ops -ResultSize 5000; if (-not $e) { 'No Copilot Studio create/publish/share/auth/delete events in the last 30 days' } else { $e | Group-Object Operations | ForEach-Object { "$($_.Name): $($_.Count)" }; $e | Group-Object UserIds | ForEach-Object { "by $($_.Name): $($_.Count)" } } }
Invoke-Check 'AG05' 'Block high-risk agent identities with Conditional Access' { $p = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { ($_ | ConvertTo-Json -Depth 10) -match 'agent' }; if (-not $p) { 'No Conditional Access policy references agents' } else { $p | ForEach-Object { "$($_.DisplayName) [state: $($_.State)]" } } }

$results | Export-Csv -NoTypeInformation -Encoding UTF8 .\hardening-check-results.csv
Write-Host "Done: $($results.Count) checks -> hardening-check-results.csv"
