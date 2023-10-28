resource "azurerm_sentinel_alert_rule_scheduled" "ar_a2d6f3ee-8acd-4472-94fe-ba295903406c" {
  count = alltrue([
    contains(var.active_connectors, "PingFederate"),
    contains(var.active_tables, "PingFederateEvent"),
    contains(var.active_connectors, "PingFederateAma")
  ]) ? 1 : 0
  name         = "a2d6f3ee-8acd-4472-94fe-ba295903406c"
  display_name = "Ping Federate - Abnormal password reset attempts"
  severity     = "High"
  description  = "Detects abnormal password reset attempts for user in short period of time."
  enabled      = true

  event_grouping {
    aggregation_method = "AlertPerResult"
  }



  query_period      = "P1D"
  query_frequency   = "P1D"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  tactics = [
    "CredentialAccess"
  ]
  techniques = [
    "T1110"
  ]
  entity_mapping {
    entity_type = "Account"
    field_mapping {
      column_name = "AccountCustomEntity"
      identifier  = "Name"
    }
  }
  alert_rule_template_guid    = "e45a7334-2cb4-4690-8156-f02cac73d584"
  alert_rule_template_version = "1.0.1"
  query                       = <<QUERY
let threshold = 10;
PingFederateEvent
| where EventType =~ 'PWD_RESET_REQUEST'
| summarize count() by DstUserName, bin(TimeGenerated, 30m)
| where count_ > threshold
| extend AccountCustomEntity = DstUserName
QUERY
  log_analytics_workspace_id  = var.log_analytics_workspace_id
}

