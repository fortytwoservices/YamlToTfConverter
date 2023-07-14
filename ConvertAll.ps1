param(
    [string]$Type,
    [string]$OutPath
)

# Set the path to the cloned Azure-Sentinel directory
$TempFolder = "c:\temp\azsentinel"

if ($null -eq $OutPath) {
    $OutPath = $PSScriptRoot # set to the script's directory
}

# Check if the Azure-Sentinel directory exists and pull updates or clone the repository
if (Test-Path $TempFolder) {
    Push-Location $TempFolder
    git pull
    Pop-Location
}
else {
    git clone https://github.com/Azure/Azure-Sentinel.git $TempFolder
}

# Map each yaml file in the Azure-Sentinel directory to its corresponding id
function ProcessFolder($folder) {
    Get-ChildItem "$folder" -Recurse -Filter "*.yaml" |
    ForEach-Object {
        $yaml = Get-Content -Path $_.FullName -Raw | ConvertFrom-Yaml
        if ($yaml.kind -eq "Scheduled" -and $Type -eq "scheduled") {
            Write-Output $yaml.kind
            if ($yaml.id) {
                $communitymap[$yaml.id] = $_.FullName
            }
        }  
        elseif ($yaml.kind -eq "NRT" -and $Type -contains "nrt") {
            Write-Output $yaml.kind
            if ($yaml.id) {
                $communitymap[$yaml.id] = $_.FullName
            }
        }
        elseif ($Type -eq "hunting" -and $yaml.kind -ne "Scheduled" -and $yaml.kind -ne "nrt") {
            $OutPath = "$OutPath\..\Hunting Queries"
            if ($yaml.id) {
                $communitymap[$yaml.id] = $_.FullName
            }
        }
        elseif ($Type -eq "all") {
            if ($yaml.id) {
                $communitymap[$yaml.id] = $_.FullName
            }
        }
    }
    Write-Output "Rule number after scanning $folder is:  $($communitymap.Count)"
}

$communitymap = @{}
ProcessFolder "$TempFolder\Detections"
ProcessFolder "$TempFolder\Solutions"

Write-Output "Rule number after scanning $($TempFolder)\Solutions is:  $($communitymap.Count)"

foreach ($rule_id in $communitymap.Keys) {
    # Check if a yaml file with the same id exists
    $yamlFilePath = $communitymap[$rule_id]
    if ($yamlFilePath -and (Test-Path $yamlFilePath)) {
        $tfContent = .\ConvertSingle.ps1 -filePath $yamlFilePath | Out-String

        # Replace the content of the terraform file with the new content
        $fileNameWithoutExtension = (Split-Path -Leaf $yamlFilePath) -replace '\.yaml$', ''
        $newFileName = Join-Path -Path $OutPath -ChildPath "$fileNameWithoutExtension.tf"
        if ($newFileName) {
            New-Item -ItemType File -Path $newFileName -Force
            Set-Content -Path $newFileName -Value $tfContent
            Write-Output "Content changed on $(Split-Path -Leaf $newFileName)" 
        }
        else {
            Write-Warning "Unable to generate new file name for: `"$($yamlFilePath.split("\")[-1])`""
        }
    }
    else {
        Write-Warning "No corresponding YAML found for: `"$($yamlFilePath.split("\")[-1])`""
    }
}



# Run the terraform formatter
terraform fmt -recursive
    
