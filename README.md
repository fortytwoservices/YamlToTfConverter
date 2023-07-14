# About
This script will convert any community rules found at https://github.com/Azure/Azure-Sentinel/tree/f34ee344c20bf443c6c51305430d5df5ec250872 and probably more resources as well.
First it clones the repo into a temp folder on C:\temp and then scans through it looking for rules. You can go for conversion for a single file and it should convert it according to the type, limited to NRT, Scheduled and Hunting rules.

If you need a script to convert multiple rules (aka ALL) you could run the script ***ConvertAl.ps1***.

# Usage

### Convert a single rule (NRT, Schedule or Hunting)
```
& .\ConvertSingle.ps1 -filePath <PathToTheFile>
```

### Convert All the Scheduled rules
You specify the type: ***Scheduled, NRT, Hunting or All*** and optionally specify the output path by ***-OutPath***, this is by default set to the script path if not used.
```
& .\ConvertAll.ps1 -Type "Scheduled" -OutPath ".\ScheduledRules"
```

```
& .\ConvertAll.ps1 -Type "NRT" -OutPath ".\NRT"
```

```
& .\ConvertAll.ps1 -Type "Hunting" -OutPath ".\Hunting"
```

```
& .\ConvertAll.ps1 -Type "All" -OutPath ".\All"
```

###
Run ```
terraform fmt -recursive
```

## 
TODO: 
- more testing to see if all rule differences have been caught
- extend more options according to terraform language (comments in code)
- Consider changing content building using "Write-Output", maybe aim for string building?
- Hunting rules are a bit messy as they use Saved Search and are poorly documented - more testing on each outputed rule
