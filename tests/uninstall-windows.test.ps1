# Fixture-only deletion tests. Never runs a real uninstaller or removes app data.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptFile = Join-Path $repoRoot 'Uninstall-Strata-V1.ps1'
$tokens = $null
$parseErrors = $null
$tree = [Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$scriptText = (Get-Content -LiteralPath $scriptFile -Raw).Replace("`r`n", "`n").Trim()
$pasteText = (Get-Content -LiteralPath (Join-Path $repoRoot 'COPY-PASTE-UNINSTALL.txt') -Raw).Replace("`r`n", "`n").Trim()
if (-not $pasteText.EndsWith("& {`n$scriptText`n}")) { throw 'Copy/paste block differs from the reviewed cleanup script.' }
foreach ($definition in $tree.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    if ($definition.Name -in @('Get-V1FullPath', 'Assert-V1NoLinkedParents', 'Remove-V1Tree')) {
        . ([scriptblock]::Create($definition.Extent.Text))
    }
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('StrataV1-Cleanup-Test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$approved = Join-Path $testRoot 'approved'
$protected = Join-Path $testRoot 'V2-protected'
New-Item -ItemType Directory -Path $approved, $protected, (Join-Path $approved 'nested') | Out-Null
[IO.File]::WriteAllText((Join-Path $protected 'keep.txt'), 'must survive')
[IO.File]::WriteAllText((Join-Path $approved 'nested\remove.txt'), 'fixture')
[IO.File]::WriteAllText((Join-Path $approved '.hidden'), 'fixture')
[IO.File]::SetAttributes((Join-Path $approved '.hidden'), [IO.FileAttributes]'ReadOnly,Hidden')
$refused = $false
try { Remove-V1Tree -Target $protected -ApprovedPaths @($approved) } catch { $refused = $true }
if (-not $refused -or -not (Test-Path -LiteralPath (Join-Path $protected 'keep.txt'))) { throw 'Allowlist boundary failed.' }
New-Item -ItemType Junction -Path (Join-Path $approved 'external-junction') -Target $protected | Out-Null
Remove-V1Tree -Target $approved -ApprovedPaths @($approved)
if ((Test-Path -LiteralPath $approved) -or -not (Test-Path -LiteralPath (Join-Path $protected 'keep.txt'))) { throw 'Junction-safe deletion failed.' }
$link = Join-Path $testRoot 'linked-parent'
New-Item -ItemType Junction -Path $link -Target $protected | Out-Null
$refused = $false
try { Remove-V1Tree -Target (Join-Path $link 'keep.txt') -ApprovedPaths @((Join-Path $link 'keep.txt')) } catch { $refused = $true }
if (-not $refused -or -not (Test-Path -LiteralPath (Join-Path $protected 'keep.txt'))) { throw 'Linked-parent boundary failed.' }
$refused = $false
try { Get-V1FullPath '..\other-folder' | Out-Null } catch { $refused = $true }
if (-not $refused) { throw 'Relative path was accepted.' }
$refused = $false
try { Get-V1FullPath '\\server\share\strata' | Out-Null } catch { $refused = $true }
if (-not $refused) { throw 'Network path was accepted.' }
# Remove only this exact, generated fixture root, through the tested helper.
if (-not $testRoot.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($testRoot) -notmatch '^StrataV1-Cleanup-Test-[a-f0-9]{32}$') { throw 'Fixture cleanup boundary failed.' }
Remove-V1Tree -Target $testRoot -ApprovedPaths @($testRoot)
Write-Host 'PASS: PowerShell parser, allowlist, read-only/hidden cleanup, child-junction isolation, linked-parent refusal, relative/network path refusal.'

