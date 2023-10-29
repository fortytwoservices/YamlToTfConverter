Function Search-AzureSentinelRepo {
    param(
        [string]$repoDirectory
    )

    $newRulesList = @{}
    $foundFiles = Get-ChildItem -Path $repoDirectory -Recurse -File -Filter *.yaml

    foreach ($foundFile in $foundFiles) {
        try {
            $content = Get-Content -LiteralPath $foundFile.FullName -Raw
            $yamlContent = ConvertFrom-Yaml $content
            $id = $yamlContent.id
            $name = $yamlContent.name
            $query = $yamlContent.query
            $kind = $yamlContent.kind
            $description = $yamlContent.description

            if ($null -ne $id -and $null -ne $name -and $null -ne $query) {
                switch ($kind) {
                    "scheduled" { $type = "Scheduled" }
                    "nrt" { $type = "NRT" }
                    default { $type = "Hunting" }
                }

                # Get the link by calling the Search-AzureSentinelRepoForSingleGuid function
                $link = Search-AzureSentinelRepoForSingleGuid -filePath $foundFile.FullName -guid $id
                if ($null -eq $link) {
                    Write-Host "$foundFile"
                }

                # Add the rule to the newRulesList hashtable
                $newRulesList[$id] = @{
                    Name        = $name
                    Description = $description
                    Type        = $type
                    Added       = Get-Date
                    Link        = $link
                    Enabled     = $false  # Add this line to set Enabled to false
                }
            }
        }
        catch {
            # You've been caught!
        }
    }

    return $newRulesList
}

Function Search-AzureSentinelRepoForSingleGuid {
    param(
        [string]$filePath,
        [string]$guid
    )

    $githubBaseRawUrl = "https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/"

    # Check if the file exists and is valid
    $escapedFilePath = $filePath -replace '\[', '`[' -replace '\]', '`]'
    if (Test-Path -Path $escapedFilePath -PathType Leaf) {
        $content = Get-Content -LiteralPath $filePath -Raw
        if ($null -eq $content) {
            Write-Host "Skipping empty or invalid file: $($filePath)"
            return $null
        }
        
        # Search for the GUID in the file content
        if ($content -match $guid) {
            $escapedFilePath = $filePath -replace '\[', '%5B' -replace '\]', '%5D'
            $relativePathEncoded = [System.Web.HttpUtility]::UrlPathEncode($escapedFilePath)
            $githubRawUrl = "${githubBaseRawUrl}${relativePathEncoded}".Replace("\", "/").Replace("C:/temp/Azure-Sentinel/", "")
            
            return $githubRawUrl
        }
        else {
            return $null
        }
    }
    else {
        return $null
    }
}



# Initialize or load existing rules list
$existingRulesListPath = ".\existingRulesList.json"
if (Test-Path $existingRulesListPath) {
    $existingRulesList = Get-Content $existingRulesListPath -Raw | ConvertFrom-Json
    if ($existingRulesList -isnot [PSCustomObject]) {
        $existingRulesList = @{}
    }
}
else {
    $existingRulesList = @{}
}

# Function to convert PSCustomObject to Hashtable
function ConvertTo-HashTable {
    param (
        [PSCustomObject]$InputObject
    )
    $hash = @{}
    $InputObject.PSObject.Properties | ForEach-Object {
        $hash[$_.Name] = $_.Value
    }
    return $hash
}

# Convert the existing rules list to Hashtable
$existingRulesHashTable = ConvertTo-HashTable -InputObject $existingRulesList

# Set the path to the cloned Azure-Sentinel directory
$TempFolder = "C:\temp\Azure-Sentinel"

# Check if the Azure-Sentinel directory exists and pull updates or clone the repository
if (Test-Path $TempFolder) {
    Push-Location $TempFolder
    git pull
    Pop-Location
}
else {
    git clone https://github.com/Azure/Azure-Sentinel.git $TempFolder
}

# Search Azure Sentinel GitHub repository
$newRulesList = Search-AzureSentinelRepo -repoDirectory $TempFolder

# Check for new rules and update the existing rules list
foreach ($key in $newRulesList.Keys) {
    if (-Not $existingRulesHashTable.ContainsKey($key)) {
        $existingRulesHashTable[$key] = $newRulesList[$key]
        Write-Host "New rule added: $($newRulesList[$key].Name)"
    }
}


# Save updated existing rules list
$existingRulesHashTable | ConvertTo-Json | Set-Content $existingRulesListPath
