$SteamPath = Get-ItemProperty HKCU:\Software\Valve\Steam | Select-Object -ExpandProperty SteamPath
$SpaceEngineers = Join-Path $SteamPath "steamapps\common\SpaceEngineers\Content"
$PrefabLocation = Join-Path $SpaceEngineers "Data\Prefabs\Economy\Sales\*.sbc"

$EconomyPrefabs = Get-ChildItem $PrefabLocation
$Blueprints = "$($env:APPDATA)\SpaceEngineers\Blueprints\local\Economy"

if(!(Test-Path $Blueprints)) {New-Item -ItemType Directory $Blueprints}

foreach ($Prefab in $EconomyPrefabs) {
    $Content = Get-Content -Path $Prefab.FullName -PipelineVariable xml |
        ForEach-Object {
            $xml `
            -replace '<Prefab','<ShipBlueprint' `
            -replace '</Prefab','</ShipBlueprint' `
            -replace 'MyObjectBuilder_PrefabDefinition','MyObjectBuilder_ShipBlueprintDefinition'
        }
    $xml = [xml]$Content
    $Displayname = $xml.Definitions.ShipBlueprints.ShipBlueprint.DisplayName
    $Thumbnail = Join-Path $SpaceEngineers $xml.Definitions.ShipBlueprints.ShipBlueprint.TooltipImage
    if($Prefab.BaseName -match 'Pirate') {
        $Displayname += ' (Pirate)'
    }
    $Blueprint = Join-Path $Blueprints $Displayname
    if (Test-Path $Blueprint) {
        Write-Warning "$Displayname already exists"
    } else {
        New-Item -ItemType Directory $Blueprint
        Set-Content -Path (Join-Path $Blueprint 'bp.sbc') -Value $Content
        Copy-Item $Thumbnail (Join-Path $Blueprint 'thumb.png')
    }
}