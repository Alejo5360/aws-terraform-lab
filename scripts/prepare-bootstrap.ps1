[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]{12}$')]
    [string] $ExpectedAccountId,

    [string] $StateDirectory = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/state/aws-terraform-lab/bootstrap'),

    [ValidateNotNullOrEmpty()]
    [string] $AwsProfile = 'devops-free'
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($AwsProfile)) {
    throw 'AwsProfile must be a non-empty AWS CLI profile name.'
}
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd([IO.Path]::DirectorySeparatorChar)
if (-not [IO.Path]::IsPathRooted($StateDirectory)) {
    throw 'StateDirectory must be an absolute path outside the repository.'
}
$stateRoot = [IO.Path]::GetFullPath($StateDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar)
$comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$separator = [IO.Path]::DirectorySeparatorChar
if ($stateRoot.Equals($repository, $comparison) -or $stateRoot.StartsWith($repository + $separator, $comparison)) {
    throw 'StateDirectory must be outside the repository.'
}
if ($stateRoot -eq [IO.Path]::GetPathRoot($stateRoot).TrimEnd($separator)) {
    throw 'Use a dedicated state directory, not a filesystem root.'
}

# Reject existing linked ancestors so a seemingly external path cannot redirect
# writes into the checkout or another location.
$ancestor = $stateRoot
while ($ancestor) {
    if (Test-Path -LiteralPath $ancestor) {
        $item = Get-Item -LiteralPath $ancestor -Force
        if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'StateDirectory and its ancestors must be real directories, not links or files.'
        }
    }
    $parent = [IO.Directory]::GetParent($ancestor)
    if ($null -eq $parent) { break }
    $ancestor = $parent.FullName
}

$backendFile = Join-Path $stateRoot 'bootstrap.local.tfbackend.json'
$variablesFile = Join-Path $stateRoot 'bootstrap.inputs.tfvars.json'
$stateFile = Join-Path $stateRoot 'terraform.tfstate'
$workspaces = Join-Path $stateRoot 'workspaces'
$dataDirectory = Join-Path $stateRoot 'terraform-data'
$planFile = Join-Path $stateRoot 'bootstrap.tfplan'

foreach ($target in @($stateFile, $planFile, $dataDirectory, $workspaces)) {
    if (Test-Path -LiteralPath $target) {
        $item = Get-Item -LiteralPath $target -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'State, plan, and Terraform data paths must not be links.'
        }
        if (($target -eq $dataDirectory -or $target -eq $workspaces) -and -not $item.PSIsContainer) {
            throw 'Terraform data and workspace paths must be directories.'
        }
    }
}

$backend = [ordered]@{
    path = $stateFile.Replace('\', '/')
    workspace_dir = $workspaces.Replace('\', '/')
} | ConvertTo-Json
$variables = [ordered]@{
    expected_account_id = $ExpectedAccountId
    aws_region = 'us-east-2'
    aws_profile = $AwsProfile
} | ConvertTo-Json
$artifacts = [ordered]@{ $backendFile = $backend; $variablesFile = $variables }

# Validate every destination before writing anything. Existing different inputs
# may belong to another project or recovery operation and must not be replaced.
foreach ($entry in $artifacts.GetEnumerator()) {
    if (Test-Path -LiteralPath $entry.Key) {
        $item = Get-Item -LiteralPath $entry.Key -Force
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Refusing to overwrite a non-regular file: $($entry.Key)"
        }
        if ([IO.File]::ReadAllText($entry.Key) -ne $entry.Value) {
            throw "Existing bootstrap configuration differs; inspect it before changing it: $($entry.Key)"
        }
    }
}

New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
foreach ($entry in $artifacts.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Key)) {
        [IO.File]::WriteAllText($entry.Key, $entry.Value, [Text.UTF8Encoding]::new($false))
    }
}

# This helper never runs Terraform, contacts AWS, creates state, or changes ACLs.
[pscustomobject]@{
    StateDirectory = $stateRoot
    BackendConfig = $backendFile
    VariablesFile = $variablesFile
    StateFile = $stateFile
    TerraformDataDir = $dataDirectory
    PlanFile = $planFile
}
