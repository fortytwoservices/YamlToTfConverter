[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [string]$filePath,
    [string]$fileOrUrl,
    [Parameter(Mandatory = $false)]
    [string]$currentGuid,
    [string]$custom_details,
    [string]$alert_details_override,
    [string]$ActualQuery,
    [string]$ActualSeverity,
    [string]$ActualConfig,
    [string]$ActualStatus
)

# TODO: Add an anytrue() clause to the connector check for the TI tables.
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
        $query,
        $ActualQuery
    )

    # Can be expanded to more escape sequences if needed: https://developer.hashicorp.com/terraform/language/expressions/strings
    $query = $query -replace "\$\{", "`$`$`$`${" # seemingly differing escape patterns

    Write-Output "`tquery = <<QUERY"
    if ([string]::IsNullOrEmpty($ActualQuery)) {
        Write-Output ($query.Trim())
    }
    else {
        Write-Output ($ActualQuery.Trim())        
    }
    Write-Output "QUERY"

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
        $version,
        $kind
    )

    if ($null -ne $version) {
        Write-Output ("`talert_rule_template_version = `"{0}`"" -f $version)
    }
}
function Handle-ID {
    param(
        [Parameter(Mandatory = $true)]
        $id,
        $kind
    )

    if ($null -ne $id) {
        if ($kind -eq "Scheduled" -or $kind -eq "NRT") {
            Write-Output "`talert_rule_template_guid = `"$id`""
        }
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
    if (([string]::IsNullOrEmpty($tactics))) {

        Write-Output ("`ttactics = []")
    }
    else {
        $tacticsList = $tactics -join '","'
        Write-Output ("`ttactics = [`n`t`t`"{0}`"`n`t]" -f ($tacticsList -replace ' '))
    }
}
function Handle-Techniques {
    param(
        [Parameter(Mandatory = $true)]
        $relevantTechniques
    )
    
    if ($null -ne $relevantTechniques -and $relevantTechniques.Count -gt 0) {
        $relevantTechniquesParts = foreach ($technique in $relevantTechniques) {
            $parts = $technique.Split(".")
            ($parts | Select-Object -First 1) -join '.'
        }
        $relevantTechniquesList = $relevantTechniquesParts -join '","'
        
        Write-Output ("`ttechniques = [`n`t`t`"{0}`"`n`t]" -f $relevantTechniquesList)
    }
}

<# function Handle-HuntingTags {
    Param(
        [Parameter(Mandatory = $true)]
        $Tactics,
        $Techniques,
        $Description,
        $version,
        $id
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
        `"id`" = `"$id`", 
        `"alert_rule_template_version`": `"$version`"
    } "


    # Optional: `"createdBy`":`"$Creator`",
    # Optional: `"createdTimeUtc`":`"$Time`" ,

} #>

function Handle-HuntingTags {
    Param(
        [Parameter(Mandatory = $true)]
        $Tactics,
        $Techniques,
        $Description,
        $version,
        $id
        # $Creator # Optional
    )
    $Description = $Description -replace "`n|`r|'", ""
    $Description = $Description -replace "\\", "\\"
    $Description = $Description -replace "`"", "\`"" 
    # $Time = Get-Date

    # Split the description into parts based on space
    $words = $Description -split ' '
    $descParts = @()
    $currentPart = ""
    foreach ($word in $words) {
        if (($currentPart + " " + $word).Length -le 150) { # Tags prop limit: 150chars - need to split it.
            if ($currentPart.Length -gt 0) {
                $currentPart += " "
            }
            $currentPart += $word
        } else {
            $descParts += $currentPart
            $currentPart = $word
        }
    }
    if ($currentPart.Length -gt 0) {
        $descParts += $currentPart
    }

    # Create descriptionX variables
    $descJsonParts = @()
    $i = 1
    foreach ($part in $descParts) {
        $descJsonParts += "`"description$i`": `"$part`""
        $i++
    }
    $descJson = $descJsonParts -join ",`n"

    Write-Output "tags = {
        `"tactics`" = `"$($Tactics -ne $null ? ($Tactics.split(" ") -join ",") : """")`"
        `"techniques`" = `"$($Techniques -ne $null ? ($Techniques.split(" ") -join ",") : """")`",
        $descJson,
        `"id`" = `"$id`", 
        `"alert_rule_template_version`": `"$version`"
    } "

    # Optional: `"createdBy`":`"$ Creator`",
    # Optional: `"createdTimeUtc`":`"$Time`" ,

}


# Check if the file or URL exists
if ($fileOrUrl -eq "filepath" -and !(Test-Path $filePath)) {
    Write-Error "File $filePath does not exist."
    return
}

# Read YAML content based on the type of input
if ($fileOrUrl -eq "url") {
    $webClient = New-Object System.Net.WebClient
    $yamlContentRaw = $webClient.DownloadString($filePath)
}
else {
    $yamlContentRaw = Get-Content $filePath -Raw
}

# Use the passed-in GUID if available, otherwise generate a new one
if (-Not $currentGuid) {
    $currentGuid = New-Guid
}
$yamlContent = ConvertFrom-Yaml $yamlContentRaw
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
            if (([string]::IsNullOrEmpty($ActualSeverity))) {
                Write-Output (Handle-Severity -severity $yamlContent.severity)
            }
            else {
                Write-Output (Handle-Severity -severity $ActualSeverity)
            }
        }
    
        if ($null -ne $yamlContent.description) {
            Write-Output (Handle-Description -description $yamlContent.description)
        }
    }

    if ($yamlContent.kind -eq "Scheduled" -or $yamlContent.kind -eq "NRT") {
        if (([string]::IsNullOrEmpty($ActualStatus))) {
            Write-Output ("`tenabled = true`n")
        }
        else {
            Write-Output ("`tenabled = " + $ActualStatus + "`n")

        }
    } # TODO: Create an alternative grouping block for nrt rules (they seem to differ somehow): https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_alert_rule_nrt

    if ($yamlContent.kind -eq "Scheduled") {
        if ($null -ne $ActualConfig) {
            Write-Output("`tevent_grouping {
                `taggregation_method = `"AlertPerResult`"
                }
        `n" + $ActualConfig + "`n")    
        }
        else {
            # Hardcoded, as yaml file does not include this:
            Write-Output("`tevent_grouping {
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
                ")
        }
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

        if ($alert_details_override) {
            Write-Output($alert_details_override)
        }

        if ($custom_details) {
            Write-Output($custom_details)
        }


    }
    if ($null -ne $yamlContent.id) {
        Write-Output (Handle-ID -id $yamlContent.id -kind $yamlContent.kind)
    }
    if ($yamlContent.kind -eq "Scheduled" -or $yamlContent.kind -eq "NRT") {    

        if ($null -ne $yamlContent.version) {
            Write-Output (Handle-Version -version $yamlContent.version -kind $yamlContent.kind)
        }
    }

    if ($yamlContent.kind -ne "Scheduled" -and $yamlContent.kind -ne "NRT") {   
        if ($null -ne $yamlContent.tactics) {
            Write-Output("category = `"Hunting Queries`"")
            Write-Output(Handle-HuntingTags -Tactics $yamlContent.tactics -Techniques $yamlContent.relevantTechniques -Description $yamlContent.description -version $yamlContent.version -id $yamlContent.id)
        }
    }



    if ($yamlContent.kind -eq "Scheduled" -or $yamlContent.kind -eq "NRT") {
        if ($null -ne $yamlContent.query) {
            Write-Output (Handle-Query -query $yamlContent.query -ActualQuery $ActualQuery)

        }
    }
    else {
        # If it contains "_0_" it most likely has entities in the query. Works for hunting rules.
        if ($yamlContent.query -notmatch "_0_") {
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


#TODO add conversion for alert details override: https://github.com/Azure/Azure-Sentinel/blob/7f1b9e743f19f4a084c946e7152ab79a56d71b0e/Solutions/Theom/Analytic%20Rules/TRIS0012_Dev_secrets_exposed.yaml#L22