[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0,
            HelpMessage = 'Mod display name. Becomes mod_name, the root project name and the class prefix.')]
    [string] $ProjectName,

    [Parameter(Mandatory = $true, Position = 1,
            HelpMessage = 'Java package of the mod, for example cc.sighs.mymod.')]
    [string] $Package,

    [Parameter(Mandatory = $true, Position = 2, HelpMessage = 'mod_authors.')]
    [string] $Author,

    [Parameter(Mandatory = $true, Position = 3, HelpMessage = 'mod_license, for example MIT.')]
    [string] $License,

    [Parameter(Mandatory = $true, Position = 4, HelpMessage = 'mod_description shown by the loaders.')]
    [string] $Description,

    [Parameter(Position = 5,
            HelpMessage = 'Mod id, lowercase [a-z0-9_]. Derived from ProjectName when omitted.')]
    [string] $ModId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

# Template identity. Everything below is replaced exactly once, so the script
# refuses to run twice (see the guard below).
$OldProject = 'SighsTemple'
$OldPackage = 'cc.sighs.temple'
$OldClassPrefix = 'Temple'
$OldModId = 'temple'
$FrameworkUrl = 'https://github.com/Tower-of-Sighs/SighsTemple'

# Control characters that never occur in template text; used to park source
# tokens while replacing, so replacement values cannot be matched again.
$TokenPrefix = [string] [char] 1
$TokenSuffix = [string] [char] 2
$OldClassNames = @('TempleCommon', 'TempleCommonTest', 'TempleForge', 'TempleFabric', 'TempleNeoForge121',
    'TempleNeoForge261')

function Read-Text {
    param([Parameter(Mandatory = $true)][string] $Path)

    return [System.IO.File]::ReadAllText($Path)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Text {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Text
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrEmpty($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

# Values land in gradle.properties, which Gradle reads through
# Properties.load(InputStream) => ISO-8859-1. Escape non-ASCII as \uXXXX so
# non-Latin authors and descriptions survive.
function ConvertTo-PropertyValue {
    param([Parameter(Mandatory = $true)][string] $Value)

    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $Value.ToCharArray()) {
        switch ($character) {
            '\' { [void] $builder.Append('\\') }
            "`t" { [void] $builder.Append('\t') }
            '=' { [void] $builder.Append('\=') }
            ':' { [void] $builder.Append('\:') }
            default {
                if ([int] $character -lt 0x20 -or [int] $character -gt 0x7E) {
                    [void] $builder.Append(('\u{0:x4}' -f [int] $character))
                }
                else {
                    [void] $builder.Append($character)
                }
            }
        }
    }

    return $builder.ToString()
}

function Set-PropertyValue {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Value
    )

    $text = Read-Text -Path $Path
    $pattern = [regex] ('(?m)^' + [regex]::Escape($Name) + '=[^\r\n]*')
    if (-not $pattern.IsMatch($text)) {
        throw "gradle.properties has no '$Name' entry."
    }

    $escaped = ConvertTo-PropertyValue -Value $Value
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($match) return "$Name=$escaped" }
    Write-Text -Path $Path -Text $pattern.Replace($text, $evaluator)
}

# Shared code and resources: package, project name, class prefix and mod id all
# change in one pass. Each source token is first parked behind a control-character
# placeholder, so a replacement value that happens to contain another source token
# (for example a project named "TempleMod") is never rewritten a second time.
function Convert-SourceText {
    param([Parameter(Mandatory = $true)][string] $Text)

    $result = Protect-TemplateTokens -Text $Text
    return Expand-TemplateTokens -Text $result
}

# Documentation keeps the framework URL untouched and never mentions classes,
# so only the project name, package and mod id are rewritten there.
function Convert-DocumentationText {
    param([Parameter(Mandatory = $true)][string] $Text)

    $placeholder = '@@SIGHSTEMPLE_FRAMEWORK_URL@@'
    $result = $Text.Replace($FrameworkUrl, $placeholder)
    $result = Protect-TemplateTokens -Text $result -CodeOnly:$false
    $result = Expand-TemplateTokens -Text $result -CodeOnly:$false
    return $result.Replace($placeholder, $FrameworkUrl)
}

function Protect-TemplateTokens {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [bool] $CodeOnly = $true
    )

    $result = $Text.Replace($OldPackage, "${script:TokenPrefix}PACKAGE${script:TokenSuffix}")
    $result = $result.Replace($OldProject, "${script:TokenPrefix}PROJECT${script:TokenSuffix}")
    if ($CodeOnly) {
        $result = $result.Replace($OldClassPrefix, "${script:TokenPrefix}CLASS${script:TokenSuffix}")
    }
    return $result.Replace($OldModId, "${script:TokenPrefix}MODID${script:TokenSuffix}")
}

function Expand-TemplateTokens {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [bool] $CodeOnly = $true
    )

    $result = $Text.Replace("${script:TokenPrefix}PACKAGE${script:TokenSuffix}", $Package)
    $result = $result.Replace("${script:TokenPrefix}PROJECT${script:TokenSuffix}", $ProjectName)
    if ($CodeOnly) {
        $result = $result.Replace("${script:TokenPrefix}CLASS${script:TokenSuffix}", $ClassPrefix)
    }
    return $result.Replace("${script:TokenPrefix}MODID${script:TokenSuffix}", $ModId)
}

$requiredValues = @{
    'ProjectName' = $ProjectName
    'Package'     = $Package
    'Author'      = $Author
    'License'     = $License
    'Description' = $Description
}
foreach ($entry in $requiredValues.GetEnumerator()) {
    if ([string]::IsNullOrWhiteSpace($entry.Value)) {
        throw "$($entry.Key) must not be empty."
    }
    if ($entry.Value -match '[\r\n]') {
        throw "$($entry.Key) must be a single line."
    }
}

$ProjectName = $ProjectName.Trim()
$Package = $Package.Trim()
$Author = $Author.Trim()
$License = $License.Trim()
$Description = $Description.Trim()

# PascalCase class prefix: "my-cool mod" => "MyCoolMod".
$ClassPrefix = (($ProjectName -split '[^A-Za-z0-9]+') |
        Where-Object { $_.Length -gt 0 } |
        ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join ''
if ($ClassPrefix -notmatch '^[A-Za-z_$][A-Za-z0-9_$]*$') {
    throw "Cannot derive a Java class name from ProjectName '$ProjectName'."
}

if ([string]::IsNullOrWhiteSpace($ModId)) {
    $ModId = ($ProjectName.ToLowerInvariant() -replace '[^a-z0-9_]', '')
}
$ModId = $ModId.Trim()
if ($ModId -cnotmatch '^[a-z][a-z0-9_]{0,63}$') {
    throw "ModId '$ModId' must match ^[a-z][a-z0-9_]{0,63}$; pass -ModId explicitly when the derived value is unsuitable."
}

# Lowercase only: an uppercase package segment would be ambiguous with the
# class-prefix replacement below.
if ($Package -cnotmatch '^[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)*$') {
    throw "Package '$Package' must be a lowercase Java package, for example cc.sighs.mymod."
}

$oldPackagePath = $OldPackage -replace '\.', '/'
$newPackagePath = $Package -replace '\.', '/'
$templatePackageDirectory = Join-Path (Join-Path $repoRoot 'common/src/main/java') $oldPackagePath

if (-not (Test-Path -LiteralPath $templatePackageDirectory -PathType Container)) {
    throw "Template already initialized: '$templatePackageDirectory' does not exist. Run this script once against a fresh SighsTemple checkout."
}

$rootProperties = Join-Path $repoRoot 'gradle.properties'
if (-not (Test-Path -LiteralPath $rootProperties -PathType Leaf)) {
    throw "gradle.properties not found at $rootProperties"
}
if (-not (Read-Text -Path $rootProperties).Contains("mod_id=$OldModId")) {
    throw "Template already initialized: gradle.properties no longer declares mod_id=$OldModId."
}

$changed = New-Object System.Collections.Generic.List[string]

function Add-Changed {
    param([Parameter(Mandatory = $true)][string] $Path)

    $changed.Add($Path)
}

$targetsRoot = Join-Path $repoRoot 'targets'
if (-not (Test-Path -LiteralPath $targetsRoot -PathType Container)) {
    throw "Targets directory not found: $targetsRoot"
}
$targetDirectories = @(Get-ChildItem -LiteralPath $targetsRoot -Directory | Sort-Object Name)

# 1. Mod identity in gradle.properties.
Set-PropertyValue -Path $rootProperties -Name 'mod_id' -Value $ModId
Set-PropertyValue -Path $rootProperties -Name 'mod_name' -Value $ProjectName
Set-PropertyValue -Path $rootProperties -Name 'mod_group_id' -Value $Package
Set-PropertyValue -Path $rootProperties -Name 'mod_authors' -Value $Author
Set-PropertyValue -Path $rootProperties -Name 'mod_license' -Value $License
Set-PropertyValue -Path $rootProperties -Name 'mod_description' -Value $Description
Add-Changed $rootProperties

# 2. Root project names.
$settingsFiles = @((Join-Path $repoRoot 'settings.gradle'), (Join-Path $repoRoot 'common/settings.gradle'))
$settingsFiles += @($targetDirectories | ForEach-Object { Join-Path $_.FullName 'settings.gradle' })
foreach ($settingsFile in $settingsFiles) {
    if (-not (Test-Path -LiteralPath $settingsFile -PathType Leaf)) {
        throw "settings.gradle not found: $settingsFile"
    }
    $text = Read-Text -Path $settingsFile
    Write-Text -Path $settingsFile -Text (Convert-SourceText -Text $text)
    Add-Changed $settingsFile
}

# 3. Java sources: move into the new package and rename the templated classes.
$sourceRoots = @((Join-Path $repoRoot 'common/src'))
$sourceRoots += @($targetDirectories | ForEach-Object { Join-Path $_.FullName 'src' })

foreach ($sourceRoot in $sourceRoots) {
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        continue
    }

    $javaFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.java' |
            Where-Object { $_.FullName -notmatch '[\\/]build[\\/]' })

    foreach ($javaFile in $javaFiles) {
        $fullPath = $javaFile.FullName
        $match = [regex]::Match($fullPath, '^(?<root>.*[\\/]src[\\/](?:main|test)[\\/]java)[\\/]')
        if (-not $match.Success) {
            continue
        }

        $javaRoot = $match.Groups['root'].Value
        $relativePath = $fullPath.Substring($javaRoot.Length).TrimStart([char[]] @('\', '/')) -replace '\\', '/'

        if ($relativePath.StartsWith($oldPackagePath + '/')) {
            $relativePath = $newPackagePath + $relativePath.Substring($oldPackagePath.Length)
        }

        $lastSlash = $relativePath.LastIndexOf('/')
        $relativeDirectory = if ($lastSlash -ge 0) { $relativePath.Substring(0, $lastSlash) } else { '' }
        $fileName = if ($lastSlash -ge 0) { $relativePath.Substring($lastSlash + 1) } else { $relativePath }

        if ($fileName.StartsWith($OldClassPrefix, [System.StringComparison]::Ordinal)) {
            $fileName = $ClassPrefix + $fileName.Substring($OldClassPrefix.Length)
        }

        $separator = [System.IO.Path]::DirectorySeparatorChar
        $targetPath = if ([string]::IsNullOrEmpty($relativeDirectory)) {
            Join-Path $javaRoot $fileName
        }
        else {
            Join-Path (Join-Path $javaRoot ($relativeDirectory -replace '/', $separator)) $fileName
        }

        Write-Text -Path $targetPath -Text (Convert-SourceText -Text (Read-Text -Path $fullPath))
        Add-Changed $targetPath

        if ($targetPath -ne $fullPath) {
            Remove-Item -LiteralPath $fullPath -Force
        }
    }

    # Drop the now empty template package directories, up to the java source root.
    $emptyDirectory = Join-Path $javaRoot $oldPackagePath
    while ($emptyDirectory.Length -gt $javaRoot.Length -and
            (Test-Path -LiteralPath $emptyDirectory -PathType Container) -and
            -not (Get-ChildItem -LiteralPath $emptyDirectory -Force)) {
        Remove-Item -LiteralPath $emptyDirectory -Force
        $emptyDirectory = Split-Path -Parent $emptyDirectory
    }
}

# 4. Shared and per-target resources: rename assets/<modid> and data/<modid>.
$resourceRoots = @((Join-Path $repoRoot 'common/src/main/resources'))
$resourceRoots += @($targetDirectories | ForEach-Object {
        Join-Path $_.FullName 'src/main/resources'
    })
$resourceRoots += @($targetDirectories | ForEach-Object {
        Join-Path $_.FullName 'src/generated/resources'
    })

foreach ($resourceRoot in $resourceRoots) {
    if (-not (Test-Path -LiteralPath $resourceRoot -PathType Container)) {
        continue
    }
    foreach ($namespace in @('assets', 'data')) {
        $oldNamespace = Join-Path (Join-Path $resourceRoot $namespace) $OldModId
        if (-not (Test-Path -LiteralPath $oldNamespace -PathType Container) -or $ModId -eq $OldModId) {
            continue
        }
        $newNamespace = Join-Path (Join-Path $resourceRoot $namespace) $ModId
        if (Test-Path -LiteralPath $newNamespace) {
            throw "Refusing to merge $newNamespace into an existing directory."
        }
        Move-Item -LiteralPath $oldNamespace -Destination $newNamespace
        Add-Changed $newNamespace
    }
}

$resourceExtensions = @('.json', '.toml', '.mcmeta', '.cfg', '.txt', '.lang', '.json5')
foreach ($resourceRoot in $resourceRoots) {
    if (-not (Test-Path -LiteralPath $resourceRoot -PathType Container)) {
        continue
    }
    $resourceFiles = @(Get-ChildItem -LiteralPath $resourceRoot -Recurse -File |
            Where-Object { $resourceExtensions -contains $_.Extension.ToLowerInvariant() })
    foreach ($resourceFile in $resourceFiles) {
        $text = Read-Text -Path $resourceFile.FullName
        $converted = Convert-SourceText -Text $text
        Write-Text -Path $resourceFile.FullName -Text $converted
        if ($converted -ne $text) {
            Add-Changed $resourceFile.FullName
        }
    }
}

# 5. Documentation: project name only, framework URL preserved.
$documentationFiles = @((Join-Path $repoRoot 'README.md'), (Join-Path $repoRoot 'AGENT.md'))
$docsRoot = Join-Path $repoRoot 'docs'
if (Test-Path -LiteralPath $docsRoot -PathType Container) {
    $documentationFiles += @(Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter '*.md' |
            ForEach-Object { $_.FullName })
}
foreach ($documentationFile in $documentationFiles) {
    $text = Read-Text -Path $documentationFile
    $converted = Convert-DocumentationText -Text $text
    if ($converted -ne $text) {
        Write-Text -Path $documentationFile -Text $converted
        Add-Changed $documentationFile
    }
}

# 6. Fail loudly on leftovers instead of shipping a half-renamed template.
$stale = @()
$scanned = @(Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Include '*.java', '*.gradle', '*.properties',
    '*.json', '*.toml', '*.md', '*.cfg', '*.mcmeta' -ErrorAction SilentlyContinue |
        Where-Object {
            $relative = $_.FullName.Substring($repoRoot.Length) -replace '\\', '/'
            -not ($relative.Contains('/.git/') -or
                $relative.Contains('/.gradle/') -or
                $relative.Contains('/.tmp/') -or
                $relative.Contains('/build/') -or
                $relative.StartsWith('/scripts/'))
        })
foreach ($file in $scanned) {
    $text = Read-Text -Path $file.FullName
    $withoutFrameworkUrl = $text.Replace($FrameworkUrl, '')
    $isStale = $false
    if ($Package -ne $OldPackage -and $text.Contains($OldPackage)) {
        $isStale = $true
    }
    if (-not $isStale -and $ProjectName -ne $OldProject -and $withoutFrameworkUrl.Contains($OldProject)) {
        $isStale = $true
    }
    if (-not $isStale -and $ClassPrefix -ne $OldClassPrefix) {
        foreach ($oldClassName in $OldClassNames) {
            if ($withoutFrameworkUrl.Contains($oldClassName)) {
                $isStale = $true
                break
            }
        }
    }
    if ($isStale) {
        $stale += $file.FullName
    }
}

Write-Host ''
Write-Host 'Initialized project'
Write-Host "  mod_id      : $ModId"
Write-Host "  mod_name    : $ProjectName"
Write-Host "  package     : $Package"
Write-Host "  class prefix: $ClassPrefix"
Write-Host "  author      : $Author"
Write-Host "  license     : $License"
Write-Host "  changed     : $($changed.Count) file(s)"
Write-Host ''
Write-Host 'Next steps'
Write-Host '  1. .\gradlew.bat -p common build'
Write-Host '  2. cd targets\forge-1.20.1; .\gradlew.bat clean build'
Write-Host '  3. delete stale build/ output from the template (clean build does this)'
Write-Host ''

if ($stale.Count -gt 0) {
    Write-Warning 'Template identifiers remain in these files; finish the rename by hand:'
    $stale | ForEach-Object { Write-Warning "  $_" }
}
