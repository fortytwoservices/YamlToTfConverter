resource "azurerm_log_analytics_saved_search" "hunt_9a5190c9-fc88-4ed8-a21a-70de877d2ff0" {
  count = alltrue([
    contains(var.active_connectors, "MicrosoftThreatProtection"),
    contains(var.active_tables, "DeviceProcessEvents")
  ]) ? 1 : 0
  name                       = "9a5190c9-fc88-4ed8-a21a-70de877d2ff0"
  display_name               = "wifikeys"
  query                      = <<QUERY
DeviceProcessEvents 
| where Timestamp > ago(7d)
| where ProcessCommandLine startswith "netsh.exe"
| where ProcessCommandLine has "key=clear"
| project Timestamp, DeviceName, InitiatingProcessFileName, FileName, ProcessCommandLine
| top 100 by Timestamp

	QUERY
  log_analytics_workspace_id = var.log_analytics_workspace_id
}

