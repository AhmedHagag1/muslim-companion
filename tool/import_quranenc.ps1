param(
    [string]$OutputDirectory = "assets/quran_study"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$snapshotDate = "2026-08-14"
$expectedAyahCount = 6236
$utf8 = New-Object System.Text.UTF8Encoding($false)

$resources = @(
    [ordered]@{
        id = "quranenc-english-rwwad"
        apiKey = "english_rwwad"
        type = "translation"
        language = "en"
        title = "English Translation - Rowwad Translation Center"
        publisher = "Rowwad Translation Center, Rabwah Dawah Association, Islamic Content Service Association in Languages, and IslamHouse.com"
        version = "1.0.19"
        lastUpdate = "2026-03-12"
    },
    [ordered]@{
        id = "quranenc-arabic-moyassar"
        apiKey = "arabic_moyassar"
        type = "tafsir"
        language = "ar"
        title = "Arabic Language - At-Tafsir Al-Muyassar"
        publisher = "King Fahd Complex for Printing the Holy Quran in Madinah"
        version = "1.0.0"
        lastUpdate = "2017-02-15"
    },
    [ordered]@{
        id = "quranenc-arabic-seraj"
        apiKey = "arabic_seraj"
        type = "wordMeanings"
        language = "ar"
        title = "Arabic Language - Meanings of Words"
        publisher = "As-Siraj fi Bayan Gharib Al-Quran, via QuranEnc.com"
        version = "1.0.0"
        lastUpdate = "2025-12-17"
    }
)

function Get-QuranEncSurah([string]$apiKey, [int]$surah) {
    $uri = "https://quranenc.com/api/v1/translation/sura/$apiKey/$surah"
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            return Invoke-RestMethod -Uri $uri -TimeoutSec 60
        }
        catch {
            if ($attempt -eq 3) { throw }
            Start-Sleep -Seconds 2
        }
    }
}

function Get-Sha256([byte[]]$bytes) {
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace("-", "")
    }
    finally {
        $algorithm.Dispose()
    }
}

$resolvedOutput = Join-Path (Get-Location) $OutputDirectory
[System.IO.Directory]::CreateDirectory($resolvedOutput) | Out-Null
$manifestResources = New-Object 'System.Collections.Generic.List[object]'

foreach ($resource in $resources) {
    Write-Output "Importing $($resource.apiKey)..."
    $entries = New-Object 'System.Collections.Generic.List[object]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($surah = 1; $surah -le 114; $surah++) {
        $response = Get-QuranEncSurah $resource.apiKey $surah
        foreach ($item in $response.result) {
            $itemSurah = [int]$item.sura
            $ayah = [int]$item.aya
            $coordinate = "$itemSurah`:$ayah"
            if ($itemSurah -lt 1 -or $itemSurah -gt 114 -or $ayah -lt 1) {
                throw "$($resource.apiKey): invalid coordinate $coordinate"
            }
            if (-not $seen.Add($coordinate)) {
                throw "$($resource.apiKey): duplicate coordinate $coordinate"
            }
            $entry = [ordered]@{
                surahNumber = $itemSurah
                ayahNumber = $ayah
                text = [string]$item.translation
            }
            if (-not [string]::IsNullOrEmpty([string]$item.footnotes)) {
                $entry.footnotes = [string]$item.footnotes
            }
            # `arabic_text` is deliberately not copied: the app already owns
            # one protected canonical Quran and must not bundle a second copy.
            $entries.Add([PSCustomObject]$entry)
        }
        if (($surah % 20) -eq 0) {
            Write-Output "  completed surah $surah"
        }
    }
    if ($entries.Count -ne $expectedAyahCount) {
        throw "$($resource.apiKey): expected $expectedAyahCount records, got $($entries.Count)"
    }
    $payload = [ordered]@{
        schemaVersion = 1
        resourceId = $resource.id
        entries = $entries
    }
    $payloadJson = ($payload | ConvertTo-Json -Depth 8 -Compress) + "`n"
    $payloadBytes = $utf8.GetBytes($payloadJson)
    $filename = "$($resource.apiKey).json"
    [System.IO.File]::WriteAllBytes((Join-Path $resolvedOutput $filename), $payloadBytes)
    $nonEmptyCount = @($entries | Where-Object { -not [string]::IsNullOrEmpty($_.text) }).Count
    $manifestResources.Add([PSCustomObject][ordered]@{
        id = $resource.id
        apiKey = $resource.apiKey
        type = $resource.type
        language = $resource.language
        title = $resource.title
        publisher = $resource.publisher
        provider = "QuranEnc.com"
        version = $resource.version
        lastUpdate = $resource.lastUpdate
        retrievedAt = $snapshotDate
        source = "https://quranenc.com/api/v1/translation/sura/$($resource.apiKey)/{surah}"
        sourcePage = "https://quranenc.com/en/home"
        termsUrl = "https://quranenc.com/en/home"
        license = "Redistribution permitted by QuranEnc Terms and Policies: verbatim content, attribution, version disclosure, transcript information, feedback to source, updates, and no inappropriate advertising."
        asset = "$OutputDirectory/$filename"
        recordCount = $entries.Count
        nonEmptyRecordCount = $nonEmptyCount
        size = $payloadBytes.Length
        sha256 = Get-Sha256 $payloadBytes
    })
}

$manifest = [ordered]@{
    schemaVersion = 1
    snapshotDate = $snapshotDate
    provider = "QuranEnc.com"
    termsSummary = "Content is reproduced verbatim. Publisher, source, and version are displayed in the app. No Quran text from the API is bundled."
    canonicalQuranIncluded = $false
    remoteActivation = [ordered]@{
        enabled = $false
        requires = @(
            "signed manifest",
            "publisher authenticity verification",
            "checksum verification",
            "rollback and downgrade protection"
        )
    }
    resources = $manifestResources
}
$manifestJson = ($manifest | ConvertTo-Json -Depth 8) + "`n"
[System.IO.File]::WriteAllText((Join-Path $resolvedOutput "manifest.json"), $manifestJson, $utf8)
Write-Output "Wrote $($manifestResources.Count) verified resources."
