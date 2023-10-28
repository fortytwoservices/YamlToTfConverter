# Read existing rules from existingRulesList.json
$existingRulesListPath = ".\existingRulesList.json"
if (Test-Path $existingRulesListPath) {
    $jsonObject = Get-Content $existingRulesListPath -Raw | ConvertFrom-Json
    if ($jsonObject -isnot [PSCustomObject]) {
        Write-Host "Invalid existing rules list."
        return
    }
} else {
    Write-Host "existingRulesList.json not found."
    return
}


# Print results
$output = ""
 
function Convert-YamlToTerraform {
  param (
    [string]$filePath,
    [string]$outputFolder
  )

  # Create the folder if it doesn't exist
  if (-Not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Force -Path $outputFolder
  }

  # Fetch the YAML content
  $yamlContent = ConvertFrom-Yaml (Invoke-RestMethod -Uri $filePath)

  # Get the "name" field from the YAML content
  $nameField = $yamlContent.name

  # Replace invalid characters in the filename
  $validName = $nameField -replace '[\\/:*?"<>|]', '_'

  # Get the current new query
  $NewestQuery = $yamlContent.query
  # Get the newest version
  $NewestVersion = $yamlContent.version
  $ActualQuery = $null

  # Get the community severity
  $CommunitySeverity = $yamlContent.severity
  $ActualSeverity

  # Var to hold incident configuration
  $ActualConfig = $null

  # Var to hold current status
  $ActualStatus = $null


  # Check for existing file with the same name
  $existingFile = Get-ChildItem $outputFolder | Where-Object { $_.Name -eq "$validName.tf" }
  if ($existingFile) {
    $existingContent = Get-Content $existingFile.FullName -Raw
    if ($existingContent -match 'name\s+=\s+"([^"]+)"') {
      $currentGuid = $matches[1]
    }
    else {
      $currentGuid = [System.Guid]::NewGuid()
    }

    if ($existingContent -match 'alert_details_override\s*([\s\S]*?"\s*\})') {
      $alert_details_override = "`nalert_details_override" + $matches[1].Trim()
    }
    else {
      $alert_details_override = $null
    }
        
    # Check for existing custom_details
    if ($existingContent -match 'custom_details\s+=\s+\{([\s\S]*?)\}') {
      $custom_details = "`ncustom_details = {`n" + $matches[1].Trim() + "`n}`n"
    }
    else {
      $custom_details = $null 
    }

    # Figure out if incident_configuration is set to default or tuned
    if ($existingContent -match 'incident_configuration\s*{.*?[a-zA-Z\s_={"0-9\[\],]+}\s*}') {
      $current_inc_config = $matches[0]
          
      $default_config = @"
          incident_configuration {
            create_incident = true
            grouping {
              enabled                = true
              entity_matching_method = "AllEntities"
              lookback_duration      = "PT8H"
            }
          }
"@
      $normalizedCurrentConfig = ($current_inc_config -replace '\s', '')
      $normalizedDefaultConfig = ($default_config -replace '\s', '')

      if ($normalizedCurrentConfig -match '"AllEntities"') {
        # Most often this is replaced with "Selected" for tuning purposes. 
        $ActualConfig = $default_config
      }
      else {
        $ActualConfig = $current_inc_config
      }
    }

    # Check if the rule is disabled or enable based on equality of version
    if ($existingContent -match 'enabled\s*=\s*(true|false)') {
      $CurrentStatus = $matches[1]
    }
    if ($CurrentStatus -ne "true" ) {
      # assuming true is wanted scenario - look for outliars
      Write-Warning "$($currentGuid) is not enabled"
      $ActualStatus = "false"
    }
    else {
      $ActualStatus = "true"
    }
        
    # Decide on keeping query tuned or go with newest:
    if ($existingContent -match '<<QUERY\s*([\s\S]*)QUERY') {
      $oldQuery = $matches[1]
    }
    if ($existingContent -match 'alert_rule_template_version\s+=\s+"([\d\.]*?)"') {
      $oldVersion = $matches[1]
    }
    else {
      $oldVersion = $null
    }

    # Then proceed with the normalization
    $normalizedOldQuery = ($oldQuery -replace '\s', '')
    $normalizedNewQuery = ($NewestQuery -replace '\s', '')

    if ($oldVersion -eq $NewestVersion -and $normalizedOldQuery -ne $normalizedNewQuery) {
      $ActualQuery = $oldQuery
    }
    else {
      $ActualQuery = $NewestQuery
    }

    if ($existingContent -match 'severity\s*=\s*"(Informational|Low|Medium|High)"') {
      $CurrentSeverity = $matches[1] # Capture the matched severity level
    }
      
    # Check for tuned severity
    if ($oldVersion -eq $NewestVersion -and $CurrentSeverity -ne $CommunitySeverity) {
      $ActualSeverity = $CurrentSeverity
    }
    else {
      $ActualSeverity = $CommunitySeverity
    }
      
  }
  else {
    $currentGuid = [System.Guid]::NewGuid()
    $custom_details = $null
    $alert_details_override = $null  
  }

  # Create the output filename
  $outputFile = Join-Path -Path $outputFolder -ChildPath ("{0}.tf" -f $validName)

  # Run the conversion script and save the output
  & '.\ConvertSingleYamlToTF.ps1' -filePath $filePath -fileOrUrl "url" -currentGuid $currentGuid -custom_details $custom_details -alert_details_override $alert_details_override -ActualQuery $ActualQuery -ActualSeverity $ActualSeverity -ActualConfig $ActualConfig -ActualStatus $ActualStatus | Out-File -FilePath $outputFile
}

# Function to find duplicate alert_rule_template_guid in .tf files
function Find-DuplicateGuids {
  $guidCounts = @{} # Hash table to store GUID counts

  # Get all .tf files recursively
  $tfFiles = Get-ChildItem -Recurse -Filter "*.tf"

  # Loop through each .tf file and search for alert_rule_template_guid
  foreach ($file in $tfFiles) {
    if (Test-Path $file.FullName) {
      try {
        $content = Get-Content $file.FullName -Raw
        if ($content -match 'alert_rule_template_guid\s*=\s*"([^"]+)"') {
          $guid = $matches[1]
          if ($guidCounts.ContainsKey($guid)) {
            $guidCounts[$guid] += , $file.FullName
          }
          else {
            $guidCounts[$guid] = @($file.FullName)
          }
        }
      }
      catch {
        Write-Warning "Could not read file: $($file.FullName)"
      }
    }
    else {
      Write-Warning "File does not exist: $($file.FullName)"
    }
  }

  # Check for duplicate GUIDs
  $duplicateGuids = $guidCounts.Keys | Where-Object { $guidCounts[$_].Count -gt 1 }

  if ($duplicateGuids.Count -gt 0) {
    $output += "Duplicate alert_rule_template_guids found:`r`n"
    foreach ($guid in $duplicateGuids) {
      $output += "GUID: $guid`r`n"
      $output += ($guidCounts[$guid] -join "`r`n") + "`r`n"
    }
  }
  else {
    Write-Host "No duplicate alert_rule_template_guids found."
  }
  $output | Out-File -FilePath ".\DuplicateSummary.txt"

}

# Iterate through each category and call the original script
foreach ($key in $jsonObject.PSObject.Properties.Name) {
  $entries = $jsonObject.$key

  foreach ($entry in $entries) {
    # Check if the rule is enabled
    if ($entry.Enabled -eq $true) {
        $filePath = $entry.Link # Assuming the 'Link' field is where the filePath is stored
        Convert-YamlToTerraform -filePath $filePath -outputFolder $entry.Type
    }
  }
}

# Format according to official style and do not display format changes
Write-Output ("Formatting all rules........")
terraform fmt -recursive -list=false ./ 

Find-DuplicateGuids

Write-Host("If there are any files that appear new, the reason may be that the name has changed as the name of the rule is the `"name`" key from the or added a new link you did not have previously.")

# Possible error when pushing is filename too long. Fix with admin privs and run: "git config --system core.longpaths true"

terraform fmt --recursive