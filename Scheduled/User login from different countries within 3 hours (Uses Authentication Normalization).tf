resource "azurerm_sentinel_alert_rule_scheduled" "ar_610e730d-127f-4617-9cde-58dba2940c9b" {
  count = alltrue([
  ]) ? 1 : 0
  name         = "610e730d-127f-4617-9cde-58dba2940c9b"
  display_name = "User login from different countries within 3 hours (Uses Authentication Normalization)"
  severity     = "High"
  description  = "This query searches for successful user logins from different countries within 3 hours. To use this analytics rule, make sure you have deployed the [ASIM normalization parsers](https://aka.ms/ASimAuthentication)"
  enabled      = true

  event_grouping {
    aggregation_method = "AlertPerResult"
  }



  query_period      = "PT3H"
  query_frequency   = "PT3H"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  tactics = [
    "InitialAccess"
  ]
  techniques = [
    "T1078"
  ]
  entity_mapping {
    entity_type = "Account"
    field_mapping {
      column_name = "Name"
      identifier  = "Name"
    }
    field_mapping {
      column_name = "UPNSuffix"
      identifier  = "UPNSuffix"
    }
  }
  alert_rule_template_guid    = "09ec8fa2-b25f-4696-bfae-05a7b85d7b9e"
  alert_rule_template_version = "1.2.3"
  query                       = <<QUERY
let timeframe = ago(3h);
let threshold = 2;
imAuthentication
| where TimeGenerated > timeframe
| where EventType == 'Logon'
    and EventResult == 'Success'
| where isnotempty(SrcGeoCountry)
| summarize
    StartTime        = min(TimeGenerated)
    , EndTime        = max(TimeGenerated)
    , Vendors        = make_set(EventVendor, 128)
    , Products       = make_set(EventProduct, 128)
    , NumOfCountries = dcount(SrcGeoCountry)
    , Countries      = make_set(SrcGeoCountry, 128)
    by TargetUserId, TargetUsername, TargetUserType
| where NumOfCountries >= threshold
| extend
  Name = iif(
      TargetUsername contains "@"
          , tostring(split(TargetUsername, '@', 0)[0])
          , TargetUsername
      ),
  UPNSuffix = iif(
      TargetUsername contains "@"
      , tostring(split(TargetUsername, '@', 1)[0])
      , ""
  )
QUERY
  log_analytics_workspace_id  = var.log_analytics_workspace_id
}

