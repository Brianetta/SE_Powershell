param (
    [Parameter()][string]$OutputFolder
)

if ($null -eq $OutputFolder -or $OutputFolder.Length -eq 0) {
    $OutputFolder = Join-Path $env:USERPROFILE -ChildPath "SE Blueprint References"
    Write-Warning "Using default folder: $OutputFolder"
}

if(Test-Path HKCU:\Software\Valve\Steam) {
    # Windows!
    $SteamPath = Get-ItemProperty HKCU:\Software\Valve\Steam | Select-Object -ExpandProperty SteamPath
} elseif ($IsLinux) {
    $SteamPath = @(foreach ($package in 'steam','steambeta') {Join-Path $($env:HOME) -ChildPath '.steam',$package }) | Get-Item | Select-Object -First 1 -ExpandProperty LinkTarget
}
$SpaceEngineers = Join-Path $SteamPath "steamapps\common\SpaceEngineers\Content"
$Localization = @{}
Select-Xml -Path (Join-Path $SpaceEngineers "data\Localization\MyTexts.resx") -XPath "root/data" | Select-Object -ExpandProperty Node | ForEach-Object {$Localization[$_.name] = $_.value}

$BlockNames=@{}
foreach ($sbc in (Join-Path $SpaceEngineers 'data\CubeBlocks\Cube*' | Get-ChildItem)) {
    [xml]$cubeblocks = Get-Content $sbc.FullName
    foreach($cb in $cubeblocks.Definitions.CubeBlocks.Definition) {
        $BlockNames[("MyObjectBuilder_$($cb.Id.TypeId)/$($cb.Id.SubtypeId)")]=$Localization[$cb.DisplayName]
    }
}

[xml]$EntityComponents = Get-Content  (Join-Path $SpaceEngineers 'data\EntityComponents.sbc')
$ECEvent = $EntityComponents.Definitions.EntityComponents.EntityComponent | Where-Object -Property type -like 'MyObjectBuilder_Event*'

if($IsLinux) {
    $BluePrintBase = "$SpaceEngineers/steamapps/compatdata/244850/pfx/drive_c/users/steamuser/AppData/SpaceEngineers/Blueprints"
}else {
    $BlueprintBase = "$($env:APPDATA)\SpaceEngineers\Blueprints"
}

$Blueprints = Get-ChildItem $BlueprintBase -Recurse 'bp.sbc'

$i=0
if($IsLinux) {
    $selected = @(foreach ($Blueprint in $Blueprints) {
        $Blueprint |
            Select-Object `
                @{Name="ID";Expr={$i}}, `
                @{Name='Folder';Expr={Split-Path $_.FullName -Parent | Split-Path -Parent | Split-Path -Leaf}}, `
                @{Name='Name';Expr={$_.Directory | Split-Path -Leaf}}
        ++$i
    }) | Out-ConsoleGridView -Title "Use space to select blueprint(s)"
} else {
    $selected = @(foreach ($Blueprint in $Blueprints) {
        $Blueprint |
            Select-Object `
                @{Name="ID";Expr={$i}}, `
                @{Name='Folder';Expr={Split-Path $_.FullName -Parent | Split-Path -Parent | Split-Path -Leaf}}, `
                @{Name='Name';Expr={$_.Directory | Split-Path -Leaf}}
        ++$i
    }) | Out-GridView -Title "Select blueprint(s)" -PassThru
}

$html=@{}
if($selected.Count -eq 0) {break};
foreach($Blueprint in $Blueprints[$selected.ID]){
    [xml]$bp = Get-Content -Encoding UTF8 (Get-Item $Blueprint.FullName)
    $ShipName = (Get-Item $Blueprint.Directory).BaseName
    $Blocks = $bp.Definitions.ShipBlueprints.ChildNodes.CubeGrids.ChildNodes.CubeBlocks.MyObjectBuilder_CubeBlock
    $ReferencingBlocks = $Blocks | Where-Object { $null -ne $_.SelectedBlocks -or $null -ne $_.Toolbar }

    $Thumbnail = Join-Path (Get-Item $Blueprint.FullName).Directory -ChildPath 'thumb.png'

    $BlockReferences = @{}
    $ToolbarActions = @{}
    $EventControllerEvent = @{}
    $OnLockedToolbarActions = @{}
    foreach ($block in $ReferencingBlocks) {
        $block_key = ($block | Select-Object -Property @{Name='Referencing Block';Expr={$BlockNames[$_.Type,$_.SubtypeName -join '/']}},CustomName)
        if($block.SelectedBlocks) {
            $BlockReferences[$block_key] = $Blocks |
            Where-Object {$null -ne $_.EntityId -and $_.EntityId -In $block.SelectedBlocks.long} |
                Select-Object -Property @{
                        Name='Name';
                        Expr={if($_.CustomName){$_.CustomName} else {$BlockNames[$_.Type,$_.SubtypeName -join '/']}}
                    },
                    @{
                        Name='Referenced Block';
                        Expr={$BlockNames[$_.Type,$_.SubtypeName -join '/']}
                    }
        }
        if($block.Toolbar.Slots) {
            $ToolbarActions[$block_key] = $block.Toolbar.Slots.Slot |
                Select-Object -Property Index -ExpandProperty Data |
                Select-Object -Property `
                    Index,
                    @{Name='Action';Expr={if ($null -eq $_.Action){'Tool/Weapon'} else {$_.Action}}},
                    GroupName,
                    @{Name='Name';Expr={
                        if($null -eq $_.GroupName) {
                            $b = $blocks | Where-Object -Property EntityId -eq $_.BlockEntityId;
                            if($null -eq $b.CustomName) {
                                $BlockNames[$b.Type,$b.SubtypeName -join '/']
                            } else {
                                $b.CustomName
                            }
                        } else {$null}
                        if($null -eq $_.GroupName) {
                            if($null -eq $_.CustomName) {
                                $blocks | Where-Object -Property EntityId -eq $_.BlockEntityId | Select-Object -ExpandProperty @{Name='Referencing Block';Expr={$BlockNames[$_.Type,$_.SubtypeName -join '/']}}
                            } else {
                                $blocks | Where-Object -Property EntityId -eq $_.BlockEntityId | Select-Object -ExpandProperty CustomName
                            }
                        } else {$null}
                    }},                    
                    @{Name='Block';Expr={                        
                        if($null -eq $_.GroupName) {
                            if($null -eq $_.Action) {
                                $_.DefinitionId | Select-Object -ExpandProperty SubType
                            } else {
                                $b = $blocks | Where-Object -Property EntityId -eq $_.BlockEntityId; $BlockNames[$b.Type,$b.SubtypeName -join '/']
                            }
                        } else {$null}
                    }},
                    @{Name='Parameters';Expr={
                        ($_.Parameters | Select-Object -ExpandProperty MyObjectBuilder_ToolbarItemActionParameter).value -join ','
                    }},
                    CustomIconTitle
        }
        if($block.OnLockedToolbar.Slots){
            $OnLockedToolbarActions[$block_key] = $block.OnLockedToolbar.Slots.Slot |
                Select-Object -Property Index -ExpandProperty Data |
                Select-Object -Property `
                    Index,
                    Action,
                    GroupName,
                    @{Name='Name';Expr={
                        if($null -eq $_.GroupName) {
                            $b = $blocks | Where-Object -Property EntityId -eq $_.BlockEntityId;
                            if($null -eq $b.CustomName) {
                                $BlockNames[$b.Type,$b.SubtypeName -join '/']
                            } else {
                                $b.CustomName
                            }
                        } else {$null}
                        if($null -eq $_.GroupName) {
                            if($null -eq $_.CustomName) {
                                $blocks | Where-Object -Property EntityId -eq $_.BlockEntityId | Select-Object -ExpandProperty @{Name='Referencing Block';Expr={$BlockNames[$_.Type,$_.SubtypeName -join '/']}}
                            } else {
                                $blocks | Where-Object -Property EntityId -eq $_.BlockEntityId | Select-Object -ExpandProperty CustomName
                            }
                        } else {$null}
                    }},                    
                    @{Name='Block';Expr={                        
                        if($null -eq $_.GroupName) {
                            if($null -eq $_.Action) {
                                $_.DefinitionId | Select-Object -ExpandProperty SubType
                            } else {
                                $b = $blocks | Where-Object -Property EntityId -eq $_.BlockEntityId; $BlockNames[$b.Type,$b.SubtypeName -join '/']
                            }
                        } else {$null}
                    }},
                    @{Name='Parameters';Expr={
                        ($_.Parameters | Select-Object -ExpandProperty MyObjectBuilder_ToolbarItemActionParameter).value -join ','
                    }},
                    CustomIconTitle
        }
        if($block.SelectedEvent){
            $EventControllerEvent[$block_key] = $block |
                Select-Object -Property `
                    @{Name='Event';Expr={
                        $Localization['DisplayName_'+(
                            $ECEvent |
                            Where-Object -Property UniqueSelectionId -eq $block.SelectedEvent | 
                            Select-Object -ExpandProperty Id |
                            Select-Object -ExpandProperty TypeId
                        ) `
                        -replace 'EventCargoFilledEntityComponent','CargoFilledEntityComponent' `
                        -replace 'EventBlockOnOff','MyEventBlockOnOff' `
                        ] # Get your act together, Keen...
                    }},
                    ANDGate,
                    Threshold
        }
    }

    $AllKeys = ($ToolbarActions.Keys + $BlockReferences.Keys + $OnLockedToolbarActions.Keys) | Sort-Object -Property 'Referencing Block',CustomName -Unique

    $html[$ShipName] = @'
<!DOCTYPE html>
<html>
<head>
<title>Block references for {0}</title>
<link rel="stylesheet" href="../matcha.css">
</head>
<body>
<h1>{1}</h1><i>{2}</i>
'@ -f $ShipName,$ShipName,$Blueprint.FullName
    if(Test-Path ($Thumbnail)) {
        $html[$ShipName] += "<br /><img src=""$ShipName.png"" alt=""Thumbnail image of $Shipname from blueprint"" />"
    }
    foreach($block in ($AllKeys)) {
        $html[$ShipName] += '<h1>{0}</h1><h2>{1}</h2>' -f "$(if($block.CustomName){$block.CustomName}else{$block.'Referencing Block'})",$block.'Referencing Block'
        if($ToolbarActions[$block]){$html[$ShipName] += $ToolbarActions[$block] |  ConvertTo-Html -Fragment -PreContent '<h3>Toolbar Actions</h3>'}
        if($OnLockedToolbarActions[$block]){$html[$ShipName] += $OnLockedToolbarActions[$block] |  ConvertTo-Html -Fragment -PreContent '<h3>Target Lock Actions</h3>'}
        if($EventControllerEvent[$block]){$html[$ShipName] += $EventControllerEvent[$block] |  ConvertTo-Html -Fragment -PreContent '<h3>Event Details</h3>'}
        if($BlockReferences[$block]){$html[$ShipName] += $BlockReferences[$block] |  ConvertTo-Html -Fragment -PreContent '<h3>Referenced/Measured Blocks</h3>'}
    }
    $html[$ShipName] += @'
</body>
</html>
'@
    $ShipSubfolder = Join-Path $OutputFolder -ChildPath $ShipName
    If(Test-Path $ShipSubfolder) {
        Write-Warning "Overwriting existing output in $ShipSubFolder"
    } else {
        mkdir $ShipSubfolder
    }
    Copy-Item $Thumbnail "$ShipSubfolder\$ShipName.png"
    $html[$ShipName] | Set-Content "$ShipSubfolder\$ShipName.html"
}

$index = @'
<!DOCTYPE html>
<html>
<head>
<title>Block references for blueprints</title>
<link rel="stylesheet" href="matcha.css">
</head>
<body>
<h1>Block References for ship blueprints</h1>
<ul>
'@

Push-Location $OutputFolder
foreach($file in Get-ChildItem *\*.html) {
    $rfile = Get-Item $file | Resolve-Path -Relative
    $index += "<li><a href=""$rfile"">$($file.BaseName)</li>"
}

$index +=@'
</ul>
</body>
</html>
'@

Invoke-WebRequest 'https://matcha.mizu.sh/matcha.css' -UseBasicParsing -OutFile (Join-Path $OutputFolder -ChildPath 'matcha.css')
$location = Join-Path $OutputFolder -ChildPath 'index.html'
$index | Set-Content ($location)
Pop-Location
Invoke-Item $location