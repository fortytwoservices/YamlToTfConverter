# About
This script is built to make updating community rules as simple and automatic as possible. All rules are kept in a JSON and to convert it you simply set it to "true" and run the ConversionRunner.ps1 file. 

The script is created in such a way that updating those rules already enabled will be able to maintain your status of the given key:value pair. As an example, if the version of your local file is the same as the community version but the query is differing, your old query will be kept as it thinks it is different because you have tuned the rule. If there is a new version, it will replace your tunings making you able to see the changes in the blade and leaves you with the task of reiterating the need of the update vs your own tunings or watchlist addition and so on. There are still more fields to add this functionality for, but as of now it works pretty well.

## Prerequisite
Install Powershell-YAML (also found at [Powershell Gallery](https://www.powershellgallery.com/))

```
Install-Module powershell-yaml
```
# Usage

### Convert a single rule (NRT, Schedule or Hunting)
```
.\ConvertSingleYamlToTF.ps1 -filePath <PathOrURLToTheFile> [-fileOrUrl "url"]
```

### Convert every enabled rule and update those that previously was converted

First you need to populate the file in neede by running GetAllRules.ps1 and then run: 
```
.\ConversionRunner.ps1
```

Next up is simply going through and checking everything got converted correctly. These scripts has made me able to spot simple bugs at the community repo where rules have been misplaced or are missing different stuff. 

## TODO: 
- A little more fix to make the JSON stay intact across all runs (especially the "enabled" feature)
- Paths with a square brackets is causing some issues leaving those rules without a link.
- There are a few rules that in between everything I'm trying to catch, so I might have to do some more bughunting and open some issues, unless I can think of an easier way to detect them and bring them into this runner.
- I know of at least one rule that is buggy, and will dive into why soon.
- More fields to compare old vs new based on the current version will be added
- Custom details will be added from community and not only from your old rule
- Alert details override from community...