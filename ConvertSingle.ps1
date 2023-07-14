[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [string]$filePath
)
function Handle-EntityMapping {
    param(
        [Parameter(Mandatory = $true)]
        $entityMappings
    )

    # Looping through each entity mapping
    foreach ($entityMapping in $entityMappings) {
        Write-Output "`tentity_mapping {"
        Write-Output ("`t`tentity_type = `"{0}`"" -f $entityMapping.entityType)

        # Check if fieldMappings exist for the entity
        if ($null -ne $entityMapping.fieldMappings) {
            # Looping through each field mapping
            foreach ($fieldMapping in $entityMapping.fieldMappings) {
                Write-Output "`t`tfield_mapping {"
                Write-Output ("`t`t`t`tcolumn_name = `"{0}`"" -f $fieldMapping.columnName)
                Write-Output ("`t`t`t`tidentifier  = `"{0}`"" -f $fieldMapping.identifier)
                Write-Output "`t`t}"
            }
        }
        Write-Output "`t}"
    }
}
function Handle-Query {
    param(
        [Parameter(Mandatory = $true)]
        $query
    )

    if ($null -ne $query) {
        # Can be expanded to more escape sequences if needed: https://developer.hashicorp.com/terraform/language/expressions/strings
        $query = $query -replace "\$\{", "`$`$`$`${" # seemingly differing escape patterns
        Write-Output "`tquery = <<QUERY"
        Write-Output ($query.Trim())        
        Write-Output "`tQUERY"
    }
}

function Handle-HuntingEntityQueries { 
    param(
        [Parameter(Mandatory = $true)]
        $query,
        $entityMappings
    )

    # Idea based on https://goodworkaround.com/2022/10/25/deploying-sentinel-hunting-queries-using-terraform/
        
    $dupTracker = @{}
    $outputLines = @()
        
    foreach ($entityMapping in $entityMappings) {
        $entityType = $entityMapping.entityType
        $fieldMappings = $entityMapping.fieldMappings
        
        foreach ($fieldMapping in $fieldMappings) {
            $identifier = $fieldMapping.identifier
            $columnName = $fieldMapping.columnName

            $key = $entityType + '_' + $identifier
            if ($dupTracker.ContainsKey($key)) {
                $dupTracker[$key]++
            }
            else {
                $dupTracker[$key] = 0
            }

            $line = "| extend {0}_{1}_{2} = {3}" -f $entityType, $dupTracker[$key], $identifier, $columnName
            $outputLines += $line
        }
    }

    if ($null -ne $query) {
        $query = $query -replace "where", "`$`$`{"
        Write-Output "`tquery = <<QUERY"
        Write-Output ($query.Trim())        

        # outputLines is joined and written out once here
        $outputString = $outputLines -join "`n"
        Write-Output $outputString

        Write-Output "`tQUERY"
    }
}

        
    
    
function Handle-Version {
    param(
        [Parameter(Mandatory = $true)]
        $version
    )

    # Handling the version part
    if ($null -ne $version) {
        Write-Output ("`talert_rule_template_version = `"{0}`"" -f $version)
    }
}
function Handle-ID {
    param(
        [Parameter(Mandatory = $true)]
        $id
    )

    # Handling the version part
    if ($null -ne $id) {
        Write-Output ("`talert_rule_template_guid = `"{0}`"" -f $id)
    }
}
function Handle-DataConnectors {
    param(
        [Parameter(Mandatory = $true)]
        $dataConnectors
    )

    # Handling the requiredDataConnectors
    if ($null -ne $dataConnectors) {
        $checksSet = New-Object System.Collections.Generic.HashSet[string]
        
        foreach ($dataConnector in $dataConnectors) {
            $connectorId = $dataConnector.connectorId
            foreach ($dataType in $dataConnector.dataTypes) {
                # Split to avoid things like "SecurityAlert (ASC)"
                $dataTypeCheck = "`n`t`tcontains(var.active_tables, `"$($dataType.split(" ")[0])`")"
                $connectorCheck = "`n`t`tcontains(var.active_connectors, `"$connectorId`")"
                # Don't wrap these in alltrue
                $checksSet.Add($connectorCheck) | Out-Null
                $checksSet.Add($dataTypeCheck) | Out-Null
            }
        }

        # Join all the checks in the set into a single string separated by commas
        $allChecks = $checksSet -join ', '
        Write-Output ("`tcount = alltrue([`t`t$allChecks`n`t]) ? 1 : 0")
    }
}
function Handle-DisplayName {
    param(
        [Parameter(Mandatory = $true)]
        $name
    )
    if ($null -ne $name) {
        Write-Output ("`tdisplay_name = `"{0}`"" -f $name)
    }
}
function Handle-Severity {
    param(
        [Parameter(Mandatory = $true)]
        $severity
    )
    if ($null -ne $severity) {
        Write-Output ("`tseverity = `"{0}`"" -f $severity)
    }
}
function Handle-Description {
    param(
        [Parameter(Mandatory = $true)]
        $description
    )

    # Handling the description part
    if ($null -ne $description) {
        $description = $description -replace "`n|`r|'", ""
        $description = $description -replace "\\", "\\"
        $description = $description -replace "`"", "\`"" 
        Write-Output ("  description = `"{0}`"" -f $description)
    }
}
function Handle-QueryFrequency {
    param(
        [Parameter(Mandatory = $true)]
        $queryFrequency
    )
    
    # Probably needs to be expanded with more options
    if ($null -ne $queryFrequency) {
        if ($queryFrequency -match "h") {
            Write-Output ("`tquery_frequency = `"PT{0}H`"" -f ($queryFrequency -replace 'h', '').ToUpper())
        }
        elseif ($queryFrequency -match "d") {
            Write-Output ("`tquery_frequency = `"P{0}D`"" -f ($queryFrequency -replace 'd', '').ToUpper())
        }
        elseif ($queryFrequency -match "m") {
            Write-Output ("`tquery_frequency = `"PT{0}M`"" -f ($queryFrequency -replace 'm', '').ToUpper())
        }
    }
}
function Handle-QueryPeriod {
    param(
        [Parameter(Mandatory = $true)]
        $queryPeriod
    )
    if ($null -ne $queryPeriod) {
        # Might need an update/addition if needed
        if ($queryPeriod -match "h") {
            Write-Output ("`tquery_period = `"PT{0}H`"" -f ($queryPeriod -replace 'h', '').ToUpper())
        }
        elseif ($queryPeriod -match "d") {
            Write-Output ("`tquery_period = `"P{0}D`"" -f ($queryPeriod -replace 'd', '').ToUpper())
        }
        elseif ($queryPeriod -match "m") {
            Write-Output ("`tquery_period = `"PT{0}M`"" -f ($queryPeriod -replace 'm', '').ToUpper())
        }
    }
}
function Handle-TriggerOperator {
    param(
        [Parameter(Mandatory = $true)]
        $triggerOperator
    )
    if ($null -ne $triggerOperator) {
        if ($triggerOperator -eq "gt") {
            $triggerOperator = "GreaterThan"
        }
        elseif ($triggerOperator -eq "lt") {
            $triggerOperator = "LessThan"
        }
        elseif ($triggerOperator -eq "eq") {
            $triggerOperator = "Equal"
        }
        elseif ($triggerOperator -eq "ne") {
            $triggerOperator = "NotEqual"
        }
        Write-Output ("`ttrigger_operator = `"{0}`"" -f $triggerOperator)
    }
}
function Handle-TriggerThreshold {
    param(
        [Parameter(Mandatory = $true)]
        $triggerThreshold
    )
    if ($null -ne $triggerThreshold) {
        Write-Output ("`ttrigger_threshold = {0}" -f $triggerThreshold)
    }
}
function Handle-Tactics {
    param(
        [Parameter(Mandatory = $true)]
        $tactics
    )
    if ($null -ne $tactics) {
        $tacticsList = $tactics -join '","'
        Write-Output ("`ttactics = [`n`t`t`"{0}`"`n`t]" -f $tacticsList)
    }
    else {
        Write-Output ("`ttactics = []")
    }
}
function Handle-Techniques {
    param(
        [Parameter(Mandatory = $true)]
        $relevantTechniques
    )
    if ($null -ne $relevantTechniques) {
        # if tf ever gets possibility to add sub mitre attack values, use this:
        # $relevantTechniquesList = $relevantTechniques.split -join '","'
        $relevantTechniquesParts = foreach ($technique in $relevantTechniques) {
            $parts = $technique.Split(".")
            ($parts | Select-Object -First 1) -join '.'
        }
        $relevantTechniquesList = $relevantTechniquesParts -join '","'
        Write-Output ("`ttechniques = [`n`t`t`"{0}`"`n`t]" -f $relevantTechniquesList)
        
    }
    else {
        Write-Output ("`ttechniques = []") 
    }
}
function Handle-HuntingTags {
    Param(
        [Parameter(Mandatory = $true)]
        $Tactics,
        $Techniques,
        $Description
        # $Creator # Optional
    )
    $Description = $description -replace "`n|`r|'", ""
    $Description = $description -replace "\\", "\\"
    $Description = $description -replace "`"", "\`"" 
    $Time = Get-Date

    Write-Output "tags = {
        `"tactics`" = `"$($Tactics -ne $null ? ($Tactics.split(" ") -join ",") : """")`"
        `"techniques`" = `"$($Techniques -ne $null ? ($Techniques.split(" ") -join ",") : """")`",
        `"description`": `"$Description`",
        `"createdTimeUtc`":`"$Time`" 
    } "


    # Optional: `"createdBy`":`"$Creator`",

}

# Check if the file exists
if (!(Test-Path $filePath)) {
    Write-Error "File $filePath does not exist."
    return
}

# Current rule GUID
$currentGuid = New-Guid
$yamlContent = ConvertFrom-Yaml (Get-Content $filePath -Raw)
if ($null -eq $yamlContent.query) {
    Write-Warning "YAML file at $filePath is missing 'query' field. Skipping this file."
    continue
}

$terraformOutput = . {
    if ($yamlContent.kind -eq "Scheduled") {
        Write-Output ("resource `"azurerm_sentinel_alert_rule_scheduled`" `"ar_$currentGuid`" {")
    }
    elseif ($yamlContent.kind -eq "NRT") {
        Write-Output ("resource `"azurerm_sentinel_alert_rule_nrt`" `"nrt_$currentGuid`" {")
    }
    else {
        Write-Output ("resource `"azurerm_log_analytics_saved_search`" `"hunt_$currentGuid`" {")
    }

    $dataConnectorsOutput = Handle-DataConnectors -dataConnectors $yamlContent.requiredDataConnectors
    if ($null -ne $dataConnectorsOutput) {
        Write-Output $dataConnectorsOutput
    }
    Write-Output ("`tname = `"$currentGuid`"")
    if ($null -ne $yamlContent.name) {
        Write-Output (Handle-DisplayName -name $yamlContent.name)
    }
    if ($yamlContent.kind -eq "Scheduled" -or $yamlContent.kind -eq "NRT") {    
        if ($null -ne $yamlContent.severity) {
            Write-Output (Handle-Severity -severity $yamlContent.severity)
        }
    
        if ($null -ne $yamlContent.description) {
            Write-Output (Handle-Description -description $yamlContent.description)
        }
    }

    if ($yamlContent.kind -eq "Scheduled") {
        Write-Output ("`tenabled = true`n")

        # Hardcoded, as yaml file does not include this:
        Write-Output("
        // BEGIN hardcoded block, remove comments once set to wanted values (These blocks are optional)
        `tevent_grouping {
        `t`taggregation_method = `"AlertPerResult`"
        `t}

        `tincident_configuration {
        `t`tcreate_incident = true
        `t`tgrouping {
        `t`tenabled                = true
        `t`tentity_matching_method = `"AllEntities`"
        `t`tlookback_duration      = `"PT8H`"
        `t`t}
        `t}
        // END")

        if ($null -ne $yamlContent.queryPeriod) {
            Write-Output (Handle-QueryPeriod -queryPeriod $yamlContent.queryPeriod)
        }
        if ($null -ne $yamlContent.queryFrequency) {
            Write-Output (Handle-QueryFrequency -queryFrequency $yamlContent.queryFrequency)
        }
        if ($null -ne $yamlContent.triggerOperator) {
            Write-Output (Handle-TriggerOperator -triggerOperator $yamlContent.triggerOperator)
        }
        if ($null -ne $yamlContent.triggerThreshold) {
            Write-Output (Handle-TriggerThreshold -triggerThreshold $yamlContent.triggerThreshold)
        }
    }


    if ($yamlContent.kind -eq "Scheduled" -or $yamlContent.kind -eq "NRT") {    

        if ($null -ne $yamlContent.tactics) {
            Write-Output (Handle-Tactics -tactics $yamlContent.tactics)
        }
        if ($null -ne $yamlContent.relevantTechniques) {
            Write-Output (Handle-Techniques -relevantTechniques $yamlContent.relevantTechniques)
        }
    
        if ($null -ne $yamlContent.entityMappings) {
            Write-Output (Handle-EntityMapping -entityMappings $yamlContent.entityMappings)
        }
    }
    if ($null -ne $yamlContent.id) {
        Write-Output (Handle-ID -id $yamlContent.id)
    }
    if ($null -ne $yamlContent.version) {
        Write-Output (Handle-Version -version $yamlContent.version)
    }

    if ($yamlContent.kind -ne "Scheduled" -and $yamlContent.kind -ne "NRT") {   
        if ($null -ne $yamlContent.tactics) {

            Write-Output(Handle-HuntingTags -Tactics $yamlContent.tactics -Techniques $yamlContent.relevantTechniques -Description $yamlContent.description)
        }
    }



    if ($yamlContent.kind -eq "Scheduled" -and $yamlContent.kind -eq "NRT") {
        if ($null -ne $yamlContent.query) {
            Write-Output (Handle-Query -query $yamlContent.query)

        }
    }
    else {
        # If it contains "_0_" it most likely has entities in the query. Works for hunting rules.
        if ($yamlContent.query  -notmatch "_0_") {
            Write-Output (Handle-HuntingEntityQueries  -query $yamlContent.query -entityMappings $yamlContent.entityMappings)
        }
        else {
            Write-Output (Handle-Query -query $yamlContent.query)


        }
    }



    # Closing variable and bracket
    Write-Output ("`tlog_analytics_workspace_id = var.log_analytics_workspace_id`n}")
} | Out-String

Write-Output($terraformOutput)



# TODO: add metadata https://github.com/hashicorp/terraform-provider-azurerm/blob/78a74423d9f084fa0f5453ef33b31f522a37eb1b/website/docs/r/sentinel_metadata.html.markdown?plain=1#L73
