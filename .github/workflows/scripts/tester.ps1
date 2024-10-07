param (
    
    [string]$AppPoolType
)

$TemplateName = "ADVSessionHostReplacer-$AppPoolType"

Write-Host "AppPoolType: $AppPoolType"