function New-RandomAzureNames {
    param(
        [int]$Count = 10,
        [int]$WordsPerName = 3,
        [int]$WordLength = 8 # optional: filter by word length; adjust or remove as desired
    )

    $totalWordsNeeded = $Count * $WordsPerName

    # Build API URL (Vercel random-word API)
    $url = "https://random-word-api.vercel.app/api?words=$($totalWordsNeeded)"

    # You can optionally filter by length: &length=$WordLength
    # $url += "&length=$WordLength"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
    }
    catch {
        Write-Error "Failed to fetch random words: $_"
        return
    }

    if ($response -isnot [System.Array] -or $response.Count -lt $totalWordsNeeded) {
        Write-Error "Unexpected response or insufficient words returned."
        return
    }

    for ($i = 0; $i -lt $Count; $i++) {
        $segment = $response[($i * $WordsPerName) .. ($i * $WordsPerName + $WordsPerName - 1)]
        $segment -join '-'
    }
}
