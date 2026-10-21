# Run from PowerShell. Passwords are entered only at psql's private prompt.
# The repository scripts and CSV are not edited by this test.
$ErrorActionPreference = 'Stop'
# A nonzero psql exit is expected during this test and checked explicitly.
$PSNativeCommandUseErrorActionPreference = $false
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
$repo = (Split-Path -Parent $PSScriptRoot)
$sourcePath = Join-Path $repo 'sql\13_refresh_and_upsert_worldbank.sql'
$helperPath = Join-Path $repo 'sql\maintenance\log_refresh_failure.sql'
$source = [IO.File]::ReadAllText($sourcePath)
$testName = 'logging_failure_test_' + [guid]::NewGuid().ToString('N')
$testFile = Join-Path $PSScriptRoot ($testName + '.sql')
$marker = '-- These rules apply to the saved 30-country, 2000-2023 snapshot.'
$include = '\ir maintenance/log_refresh_failure.sql'
$nameMarker = "VALUES ('worldbank_refresh_and_upsert')"
if (-not (Test-Path -LiteralPath $helperPath)) { throw 'Failure helper is missing.' }
foreach ($item in @($marker, $nameMarker)) {
    if ([regex]::Matches($source, [regex]::Escape($item)).Count -ne 1) {
        throw 'The refresh script has changed. Review the test before continuing.'
    }
}
if (-not $source.Contains($include)) { throw 'Expected error-handler include is missing.' }
$absoluteHelper = $helperPath.Replace('\', '/')
$testSql = $source.Replace($include, "\ir '$absoluteHelper'")
$testSql = $testSql.Replace($nameMarker, "VALUES ('$testName')")
$injection = @'
-- Test only: invalid percentage in the uncommitted staging batch.
UPDATE worldbank.indicators_staging
SET unemployment_rate = '101'
WHERE country_code = 'ZAF' AND year = '2023';

'@
$testSql = $testSql.Replace($marker, $injection + "`n" + $marker)

# Compare all column values and duplicate rows, not just row counts.
$snapshotQuery = @'
SELECT 'DATA|' || relation_name || '|' || row_value
FROM (
    SELECT 'staging' AS relation_name, to_jsonb(t)::text AS row_value
    FROM worldbank.indicators_staging AS t
    UNION ALL
    SELECT 'typed', to_jsonb(t)::text
    FROM worldbank.indicators_typed AS t
) AS snapshot
ORDER BY relation_name, row_value;
'@
$connection = @('-X', '-h', 'localhost', '-U', 'postgres', '-d', 'world_bank_analytics', '-W')
Write-Host '1/3: Read the original data. Enter your PostgreSQL password.'
$before = @(& $psql @connection -A -t -v ON_ERROR_STOP=1 -c $snapshotQuery)
if ($LASTEXITCODE -ne 0) { throw 'Could not read the baseline; test cancelled.' }
if ($before.Count -eq 0) { throw 'No baseline rows found; test cancelled.' }

try {
    [IO.File]::WriteAllText($testFile, $testSql, (New-Object Text.UTF8Encoding($false)))
    Write-Host '2/3: Run the invalid batch. Enter your password again. SQL errors are expected here.'
    & $psql @connection -f $testFile
    $testExit = $LASTEXITCODE

    $logQuery = @"
SELECT 'LOG|' || (COUNT(*) = 1 AND COALESCE(BOOL_AND(
    status = 'failed'
    AND finished_at IS NOT NULL
    AND finished_at >= started_at
    AND staging_rows IS NULL AND typed_rows IS NULL
    AND error_message = 'Year or indicator value outside the accepted range'
), false))::text
FROM worldbank.pipeline_runs
WHERE pipeline_name = '$testName';
"@
    Write-Host '3/3: Verify rollback and the saved failure log. Enter your password once more.'
    $results = @(& $psql @connection -A -t -v ON_ERROR_STOP=1 -c ($snapshotQuery + "`n" + $logQuery))
    if ($LASTEXITCODE -ne 0) { throw 'Verification query failed; the test is not verified.' }
    $after = @($results | Where-Object { $_.StartsWith('DATA|') })
    if (($before -join "`n") -cne ($after -join "`n")) {
        throw 'Table contents differ from the baseline. Stop and investigate.'
    }
    if ($testExit -ne 3) { throw "Expected psql exit code 3; received $testExit." }
    if ($results -cnotcontains 'LOG|true') { throw 'The expected failed log entry was not verified.' }
    Write-Host 'PASS: invalid batch rejected; both tables unchanged; failure log preserved; exit code 3.' -ForegroundColor Green
    Write-Host "Test run name: $testName"
}
finally {
    # Remove only the temporary SQL file this invocation created.
    if (Test-Path -LiteralPath $testFile) {
        Remove-Item -LiteralPath $testFile
    }
}
