# Azure Sentinel Rule Updater

## About

This PowerShell script automates the process of updating Azure Sentinel community rules. It keeps track of rule configurations in a JSON file. To enable or disable a rule, simply toggle the corresponding key-value pair in the JSON file and execute `ConversionRunner.ps1`.

### Features

- **Preservation of Settings**: When updating rules that are already enabled, your custom configurations, like query alterations or watchlist additions, are preserved.
- **Version Comparison**: If a community rule gets updated, the script replaces your custom configurations only if the rule's version has changed. This allows you to review and decide whether to adopt the new update or keep your customizations.

## Prerequisites

1. PowerShell
2. PowerShell-YAML Module: Install it using the following command or visit [PowerShell Gallery](https://www.powershellgallery.com/):

    ```powershell
    Install-Module powershell-yaml
    ```

## Usage

### Convert a Single Rule (NRT, Scheduled, or Hunting)

To convert a single YAML rule to Terraform (TF) format, use the following command:

```powershell
.\ConvertSingleYamlToTF.ps1 -filePath <PathOrURLToTheFile> [-fileOrUrl "url"]
```

## Batch Conversion and Update
- **Initialize Rule List**: Run GetAllRules.ps1 to populate the JSON file with available rules.
- **Enable Rules**: Edit the JSON file to set the rules you want to convert to true.
- **Run the Conversion**:
```powershell
.\ConversionRunner.ps1
```
- **Review**: Manually review to ensure all rules are correctly converted. Any bugs or features? Please feel free to raise an issue!

# Known Issues and TODO
- **URL Encoding**: Rules with square brackets in the path are currently not linked correctly.
- **Bug Hunting**: Some rules may not be captured correctly, requiring further debugging.
- **Rule Errors**: Investigate issues with specific rules that are not behaving as expected.
- **Field Comparisons**: Add more fields for comparing new community rules against existing custom rules.
- **Community Contributions**: Allow for custom details to be pulled from community contributions.