resource "azurerm_sentinel_alert_rule_nrt" "nrt_0803ea63-bbe1-4bdf-aebe-db448e72e018" {
  count = alltrue([
    contains(var.active_connectors, "JamfProtect"),
    contains(var.active_tables, "jamfprotect_CL")
  ]) ? 1 : 0
  name         = "0803ea63-bbe1-4bdf-aebe-db448e72e018"
  display_name = "Jamf Protect - Unified Logs"
  severity     = "Informational"
  description  = "Creates an informational incident based on Jamf Protect Unified Log data in Microsoft Sentinel"
  enabled      = true

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      column_name = "DvcHostname"
      identifier  = "HostName"
    }
  }
  entity_mapping {
    entity_type = "IP"
    field_mapping {
      column_name = "Host_IPs"
      identifier  = "Address"
    }
  }
  alert_rule_template_guid    = "9eb2f758-003b-4303-83c6-97aed4c03e41"
  alert_rule_template_version = "1.0.2"
  query                       = <<QUERY
JamfProtect
| where EventType == "UnifiedLog"
| where isnotempty(EventSeverity)
| extend Host_IPs = tostring(parse_json(DvcIpAddr)[0])
QUERY
  log_analytics_workspace_id  = var.log_analytics_workspace_id
}

