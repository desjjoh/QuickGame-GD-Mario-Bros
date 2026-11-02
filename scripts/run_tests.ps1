param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
$logDirectory = Join-Path $projectRoot '.godot/validation'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
$failedTests = @()

try {
    $env:APPDATA = Join-Path $logDirectory 'appdata'
    $env:LOCALAPPDATA = Join-Path $logDirectory 'localappdata'
    $testScenes = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter '*_test.tscn' |
        Sort-Object Name
    if ($testScenes.Count -eq 0) { throw 'No test scenes found.' }

    foreach ($scene in $testScenes) {
        $scenePath = 'res://tests/' + $scene.Name
        $output = & $enginePath --headless --path $projectRoot $scenePath --max-fps 60 --quit-after 1800 --log-file (Join-Path $logDirectory ($scene.BaseName + '.log')) 2>&1 |
            ForEach-Object { $_.ToString() }
        $engineExitCode = $LASTEXITCODE
        if ($engineExitCode -ne 0 -or -not ($output -match '^PASS:') -or
            ($output -match '^(SCRIPT ERROR|ERROR|WARNING):')) {
            $failedTests += $scene.BaseName
            Write-Host ('FAIL: ' + $scene.BaseName)
            $output | ForEach-Object { Write-Host $_ }
        } else {
            Write-Host ('PASS: ' + $scene.BaseName)
        }
    }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}

if ($failedTests.Count -gt 0) {
    throw ('Failed checks: ' + ($failedTests -join ', '))
}
Write-Host ('PASS: all ' + $testScenes.Count + ' test scenes, without engine errors or warnings.')
