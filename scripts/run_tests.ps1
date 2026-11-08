param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,
    [string[]]$TestName = @()
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
    if ($TestName.Count -gt 0) {
        $unknown = @($TestName | Where-Object { $_ -notin $testScenes.BaseName })
        if ($unknown.Count -gt 0) { throw ('Unknown test names: ' + ($unknown -join ', ')) }
        $testScenes = @($testScenes | Where-Object { $_.BaseName -in $TestName })
    }


    foreach ($scene in $testScenes) {
        $scenePath = 'res://tests/' + $scene.Name
        $output = & $enginePath --headless --path $projectRoot $scenePath --max-fps 60 --quit-after 1800 --log-file (Join-Path $logDirectory ($scene.BaseName + '.log')) 2>&1 |
            ForEach-Object { $_.ToString() }
        $engineExitCode = $LASTEXITCODE
        if ($engineExitCode -ne 0 -or -not ($output -match '^(PASS:|[A-Za-z0-9_]+_test: PASS$)') -or
            ($output -match '^(SCRIPT ERROR|ERROR|WARNING):')) {
            $failedTests += $scene.BaseName
            Write-Host ('FAIL: ' + $scene.BaseName + ' (engine exit ' + $engineExitCode + ')')
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
$scope = if ($TestName.Count -gt 0) { 'selected' } else { 'all' }
Write-Host ('PASS: ' + $scope + ' ' + $testScenes.Count + ' test scenes, without engine errors or warnings.')
