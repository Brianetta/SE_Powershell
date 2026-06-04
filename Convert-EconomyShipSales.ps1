param (
    [Parameter(ParameterSetName='Preset')][string]$BlueprintFolder,
    [Parameter(ParameterSetName='Preset')][ValidateSet('Gray','Red','Green','Blue','Yellow','DarkWhite','Black',
                'LightGray','LightRed','LightGreen','LightBlue','LightYellow','White','LightBlack',
                'Cyan','Magenta','LightCyan','LightMagenta','InternationalOrange')][string]$Color,
    [Parameter(ParameterSetName='Preset')][Alias('Ships')][string[]]$Ship
)

$ColorPreset = @{
    Gray = '<ColorMaskHSV x="0" y="-0.8" z="0" />';
    Red = '<ColorMaskHSV x="0" y="0" z="0.05" />';
    Green = '<ColorMaskHSV x="0.333333343" y="-0.48" z="-0.25" />';
    Blue = '<ColorMaskHSV x="0.575" y="0" z="0" />';
    Yellow = '<ColorMaskHSV x="0.122222222" y="-0.1" z="0.26" />';
    DarkWhite = '<ColorMaskHSV x="0" y="-0.8" z="0.4" />';
    Black = '<ColorMaskHSV x="0" y="-0.8" z="-0.45" />';
    LightGray = '<ColorMaskHSV x="0" y="-0.8" z="0.2" />';
    LightRed = '<ColorMaskHSV x="0" y="0.15" z="0.25" />';
    LightGreen = '<ColorMaskHSV x="0.333333343" y="-0.33" z="-0.05" />';
    LightBlue = '<ColorMaskHSV x="0.575" y="0.15" z="0.2" />';
    LightYellow = '<ColorMaskHSV x="0.122222222" y="0.05" z="0.46" />'
    White = '<ColorMaskHSV x="0" y="-0.8" z="0.55" />';
    LightBlack = '<ColorMaskHSV x="0" y="-0.8" z="-0.3" />';
    Test_Brown = '<ColorMaskHSV x="0.122222222" y="-0.1" z="0.26" />';
    Cyan = '<ColorMaskHSV x="0.5" y="0.1" z="0.275" />';
    Magenta = '<ColorMaskHSV x="0.833" y="0.1" z="0.3" />';
    LightCyan = '<ColorMaskHSV x="0.5" y="0.175" z="0.375" />';
    LightMagenta = '<ColorMaskHSV x="0.833" y="0.175" z="0.4" />';
    InternationalOrange = '<ColorMaskHSV x="0.052" y="0.2" z="0.55" />'
}

$SteamPath = Get-ItemProperty HKCU:\Software\Valve\Steam | Select-Object -ExpandProperty SteamPath
$SpaceEngineers = Join-Path $SteamPath "steamapps\common\SpaceEngineers\Content"
$PrefabLocation = Join-Path $SpaceEngineers "Data\Prefabs\Economy\Sales\*.sbc"

$EconomyPrefabs = Get-ChildItem $PrefabLocation

if ($null -eq $Ship) {
    $Ship = @(
        foreach ($Prefab in $EconomyPrefabs) {
            $Content = Get-Content -Path $Prefab.FullName |
                ForEach-Object {
                    $_ `
                    -replace '<Prefab','<ShipBlueprint' `
                    -replace '</Prefab','</ShipBlueprint' `
                    -replace 'MyObjectBuilder_PrefabDefinition','MyObjectBuilder_ShipBlueprintDefinition' `
                    -replace $DefaultColor,$ColorPreset[$Color]
                }
            $xml = [xml]$Content
            $Displayname = $xml.Definitions.ShipBlueprints.ShipBlueprint.DisplayName
            if($Prefab.BaseName -match 'Pirate') {
                $Displayname += ' (Pirate)'
            }
            $true | Select-Object `
                @{Name='Blueprint';Expr={$Prefab.BaseName}},
                @{Name='DisplayName';Expr={$Displayname}},
                @{Name='Description';Expr={$xml.Definitions.ShipBlueprints.ShipBlueprint.Description}}
        }
    ) | Out-GridView -Title 'Please select your desired blueprint(s)' -PassThru | Select-Object -ExpandProperty Blueprint
}

if($null -eq $Color -or $Color.Length -eq 0) {
    $Color = $ColorPreset.Keys | Out-GridView -Title 'Please select your desired color' -PassThru | Select-Object -First 1
}
if($null -eq $Color -or $Color.Length -eq 0) {
    Write-Error "No color selected; aborting."
} else {
    if ($null -eq $BlueprintFolder -or $BlueprintFolder.Length -eq 0) {$BlueprintFolder = "Economy - $Color"}
    $Blueprints = "$($env:APPDATA)\SpaceEngineers\Blueprints\local\$BlueprintFolder"

    $DefaultColor = '<ColorMaskHSV x="1" y="0.2" z="0.55" />'

    if(!(Test-Path $Blueprints)) {New-Item -ItemType Directory $Blueprints}

    foreach ($Prefab in $EconomyPrefabs) {
        if($Ship -contains $Prefab.BaseName) {
            $Content = Get-Content -Path $Prefab.FullName |
                ForEach-Object {
                    $_ `
                    -replace '<Prefab','<ShipBlueprint' `
                    -replace '</Prefab','</ShipBlueprint' `
                    -replace 'MyObjectBuilder_PrefabDefinition','MyObjectBuilder_ShipBlueprintDefinition' `
                    -replace $DefaultColor,$ColorPreset[$Color]
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
    }
}
