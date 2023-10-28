resource "azurerm_log_analytics_saved_search" "hunt_0725bbb8-bbb8-4d3e-8353-e821baac59e7" {
  count = alltrue([
    contains(var.active_connectors, "MicrosoftThreatProtection"),
    contains(var.active_tables, "DeviceProcessEvents")
  ]) ? 1 : 0
  name         = "0725bbb8-bbb8-4d3e-8353-e821baac59e7"
  display_name = "Crashing Applications"
  category     = "Hunting Queries"
  tags = {
    "tactics"    = "Execution,Misconfiguration"
    "techniques" = "",
    "description1" : "This query identifies crashing processes based on parameters passedto werfault.exe and attempts to find the associated process launchfrom DeviceProcessEvents.",
    "id" = "53b250f6-c684-4932-aca9-a06045a962d6",
    "alert_rule_template_version" : ""
  }
  query                      = <<QUERY
DeviceProcessEvents
| where Timestamp > ago(1d)
| where FileName =~ 'werfault.exe'
| project CrashTime = Timestamp, DeviceId, WerFaultCommand = ProcessCommandLine, CrashProcessId = extract("-p ([0-9]{1,5})", 1, ProcessCommandLine) 
| join kind= inner hint.strategy=shuffle DeviceProcessEvents on DeviceId
| where CrashProcessId == ProcessId and Timestamp between (datetime_add('day',-1,CrashTime) .. CrashTime)
| project-away ActionType
| project-rename ProcessStartTimestamp = Timestamp

	QUERY
  log_analytics_workspace_id = var.log_analytics_workspace_id
}

