$headingOfSynopsis = "## SYNOPSIS"
$headingOfSyntax = "## SYNTAX"
$headingOfDescription = "## DESCRIPTION"
$headingOfExamples = "## EXAMPLES"
$headingOfParameters = "## PARAMETERS"
$headingOfExampleRegex = "\n###\s*"
$headingOfExampleTitleRegex = "$headingOfExampleRegex.+"
$codeBlockRegex = "``````powershell(.*\n)+? *``````"
$outputBlockRegex = "``````output(.*\n)+? *``````"

function Get-ExamplesDetailsFromMd {
    param (
        [string]$MarkdownPath
    )

    $fileContent = Get-Content $MarkdownPath -Raw

    $indexOfExamples = $fileContent.IndexOf($headingOfExamples)
    $indexOfParameters = $fileContent.IndexOf($headingOfParameters)

    $exampleNumber = 0
    $examplesProperties = @()

    $examplesContent = $fileContent.Substring($indexOfExamples, $indexOfParameters - $indexOfExamples)
    $examplesTitles = ($examplesContent | Select-String -Pattern $headingOfExampleTitleRegex -AllMatches).Matches
    # Skip the 1st because it is $headingOfExamples.
    $examplesContentWithoutTitle = $examplesContent -split $headingOfExampleTitleRegex | Select-Object -Skip 1
    foreach ($exampleContent in $examplesContentWithoutTitle) {
        $exampleTitle = ($examplesTitles[$exampleNumber].Value -split $headingOfExampleRegex)[1].Trim()
        $exampleNumber++
        $exampleCodes = @()
        $exampleOutputs = @()
        $exampleDescriptions = @()

        $exampleCodeBlocks = ($exampleContent | Select-String -Pattern $codeBlockRegex -AllMatches).Matches
        $exampleOutputBlocks = ($exampleContent | Select-String -Pattern $outputBlockRegex -AllMatches).Matches
        if ($exampleCodeBlocks.Count -eq 0) {
            $description = $exampleContent.Trim()
            if ($description -ne "") {
                $exampleDescriptions += $description
            }
        }
        else {
            # From the start to the start of the first codeblock is example description.
            $description = $exampleContent.SubString(0, $exampleCodeBlocks[0].Index).Trim()
            if ($description -ne "") {
                $exampleDescriptions += $description
            }

            if ($exampleOutputBlocks.Count -eq 0) {
                foreach ($exampleCodeBlock in $exampleCodeBlocks) {
                    #$exampleCodeLines = ($exampleCodeBlock.Value | Select-String -Pattern "((\n(([A-Za-z \t\\:>])*(PS|[A-Za-z]:)(\w|[\\/\[\].\- ])*(>|&gt;)+( PS)*)*[ \t]*[A-Za-z]\w+-[A-Za-z]\w+\b(?!(-|   +\w)))|(\n(([A-Za-z \t\\:>])*(PS|[A-Za-z]:)(\w|[\\/\[\].\- ])*(>|&gt;)+( PS)*)*[ \t]*((@?\(.+\) *[|.-] *\w)|(\[.+\]\$)|(@{.+})|('[^\n\r']*' *[|.-] *\w)|(`"[^\n\r`"]*`" *[|.-] *\w)|\$)))([\w-~``'`"$= \t:;<>@()\[\]{},.+*/|\\&!?%#]*[``|] *(\n|\r\n))*[\w-~``'`"$= \t:;<>@()\[\]{},.+*/|\\&!?%#]*(?=\n|\r\n|#)" -CaseSensitive -AllMatches).Matches
                    #$exampleCodeLines = ($exampleCodeBlock.Value | Select-String -Pattern "\n(([A-Za-z \t])*(PS|[A-Za-z]:)(\w|[\\/\[\].\- ])*(>|&gt;)+( PS)*)*[ \t]*((([A-Za-z]\w+-[A-Za-z]\w+\b(?!(-|   +\w)))|((@?\(.+\) *[|.-] *\w)|(\[.+\]\$)|(@{.+})|('[^\n\r']*' *[|.-] *\w)|(`"[^\n\r`"]*`" *[|.-] *\w)|\$))([\w-~``'`"$= \t:;<>@()\[\]{},.+*/|\\&!?%#]*[``|][ \t]*(\n|\r\n)?)*([\w-~``'`"$= \t:;<>@()\[\]{},.+*/|\\&!?%#]*(?=\n|\r\n|#)))" -CaseSensitive -AllMatches).Matches
                    $codeRegex = "\n(([A-Za-z \t])*(PS|[A-Za-z]:)(\w|[\\/\[\].\- ])*(>|&gt;)+( PS)*)*[ \t]*((([A-Za-z]\w+-[A-Za-z]\w+\b(.ps1)?(?!(-|   +\w)))|(" +
                    "(@?\((?>\((?<pair>)|[^\(\)]+|\)(?<-pair>))*(?(pair)(?!))\) *[|.-] *\w)|" +
                    "(\[(?>\[(?<pair>)|[^\[\]]+|\](?<-pair>))*(?(pair)(?!))\]\$)|" +
                    "(@{(?>{(?<pair>)|[^{}]+|}(?<-pair>))*(?(pair)(?!))})|" +
                    "('(?>'(?<pair>)|[^']+|'(?<-pair>))*(?(pair)(?!))' *[|.-] *\w)|" +
                    "((?<!``)`"(?>(?<!``)`"(?<pair>)|[\s\S]|(?<!``)`"(?<-pair>))*(?(pair)(?!))(?<!``)`" *[|.-] *\w)|" +
                    "\$))(?!\.)([\w-~``'`"$= \t:;<>@()\[\]{},.+*/|\\&!?%#]*[``|][ \t]*(\n|\r\n)?)*([\w-~``'`"$= \t:;<>@()\[\]{},.+*/|\\&!?%#]*(?=\n|\r\n|#)))"
                    $exampleCodeLines = ($exampleCodeBlock.Value | Select-String -Pattern $codeRegex -CaseSensitive -AllMatches).Matches
                    if ($exampleCodeLines.Count -eq 0) {
                        $exampleCodes = @()
                        $exampleOutputs = @()
                    }
                    else {
                        for ($i = 0; $i -lt $exampleCodeLines.Count; $i++) {
                            # If a codeline contains " :", it's not a codeline but an output line of "Format-List".
                            if ($exampleCodeLines[$i].Value -notmatch " : *\w") {
                                # If a codeline ends with "`", "\r", or "\n", it should end at the last "`".
                                $lastCharacter = $exampleCodeLines[$i].Value.Substring($exampleCodeLines[$i].Value.Length - 1, 1)
                                if ($lastCharacter -eq "``" -or $lastCharacter -eq "`r" -or $lastCharacter -eq "`n") {
                                    $exampleCodes += $exampleCodeLines[$i].Value.Substring(0, $exampleCodeLines[$i].Value.LastIndexOf("``")).Trim()
                                }
                                else {
                                    $exampleCodes += $exampleCodeLines[$i].Value.Trim()
                                }

                                # Content before the first codeline, between codelines, and after the last codeline is output.
                                # If an output line starts with "-", it's an incomplete codeline, but it should still be added to output.
                                if ($i -eq 0) {
                                    $startIndex = $exampleCodeBlock.Value.IndexOfAny("`n")
                                    $output = $exampleCodeBlock.Value.Substring($startIndex, $exampleCodeLines[$i].Index - $startIndex).Trim()
                                    if ($output -ne "") {
                                        $exampleOutputs += $output
                                    }
                                }
                                $startIndex = $exampleCodeLines[$i].Index + $exampleCodeLines[$i].Length
                                if ($i -lt $exampleCodeLines.Count - 1) {
                                    $nextStartIndex = $exampleCodeLines[$i + 1].Index
                                }
                                else {
                                    $nextStartIndex = $exampleCodeBlock.Value.LastIndexOfAny("`n")
                                }
                                $output = $exampleCodeBlock.Value.Substring($startIndex, $nextStartIndex - $startIndex).Trim()
                                if ($output -match "^-+\w") {
                                    $exampleOutputs += $output
                                }
                                elseif ($output -ne "") {
                                    $exampleOutputs += $output
                                }
                            }
                        }
                    }
                }
            }
            else {
                foreach ($exampleCodeBlock in $exampleCodeBlocks) {
                    $code = $exampleCodeBlock.Value.Substring($exampleCodeBlock.Value.IndexOfAny("`n"), $exampleCodeBlock.Value.LastIndexOfAny("`n") - $exampleCodeBlock.Value.IndexOfAny("`n")).Trim()
                    if ($code -ne "") {
                        $exampleCodes += $code
                    }
                }
                foreach ($exampleOutputBlock in $exampleOutputBlocks) {
                    $output = $exampleOutputBlock.Value.Substring($exampleOutputBlock.Value.IndexOfAny("`n"), $exampleOutputBlock.Value.LastIndexOfAny("`n") - $exampleOutputBlock.Value.IndexOfAny("`n")).Trim()
                    if ($output -ne "") {
                        $exampleOutputs += $output
                    }
                }
            }

            # From the end of the last codeblock to the end is example description.
            $description = $exampleContent.SubString($exampleCodeBlocks[-1].Index + $exampleCodeBlocks[-1].Length).Trim()
            if ($description -ne "") {
                $exampleDescriptions += $description
            }
        }

        $examplesProperties += [PSCustomObject]@{
            Title = $exampleTitle
            Codes = $exampleCodes
            CodeBlocks = $exampleCodeBlocks
            Outputs = $exampleOutputs
            OutputBlocks = $exampleOutputBlocks
            Description = ([string]$exampleDescriptions).Trim()
        }
    }

    return $examplesProperties
}

function Get-ScriptAnalyzerResult {
    param (
        [string]$Module,
        [string]$ScriptPath,
        [string[]]$RulePath,
        [switch]$IncludeDefaultRules
    )

    # Validate script file exists.
    if (!(Test-Path $ScriptPath -PathType Leaf)) {
        throw "Cannot find cached script file '$ScriptPath'."
    }

    if ($RulePath -eq $null) {
        $results = Invoke-ScriptAnalyzer -Path $ScriptPath -IncludeDefaultRules:$IncludeDefaultRules.IsPresent
    }
    else {
        $results = Invoke-ScriptAnalyzer -Path $ScriptPath -CustomRulePath $RulePath -IncludeDefaultRules:$IncludeDefaultRules.IsPresent
    }
    $scriptBaseName = [IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    return $results | Select-Object -Property @{Name = "Module"; Expression = {$Module}},
        @{Name = "Cmdlet";Expression={$scriptBaseName.Split("-")[0..1] -join "-"}},
        @{Name="Example";Expression={$scriptBaseName.Split("-")[2]}},
        RuleName, Message, Extent
}

function Measure-SectionMissingAndScriptError {
    param (
        [string]$Module,
        [string]$Cmdlet,
        [string]$MarkdownPath,
        [string[]]$PublishedCmdletDocs,
        [Parameter(Mandatory, HelpMessage = "PSScriptAnalyzer custom rules path. Supports wildcard.")]
        [string[]]$RulePath,
        [switch]$AnalyzeExampleScript,
        [switch]$IncludeDefaultRules,
        [switch]$OutputExampleScript,
        [string]$OutputPath
    )

    $fileContent = Get-Content $MarkdownPath -Raw

    $indexOfSynopsis = $fileContent.IndexOf($headingOfSynopsis)
    $indexOfSyntax = $fileContent.IndexOf($headingOfSyntax)
    $indexOfDescription = $fileContent.IndexOf($headingOfDescription)
    $indexOfExamples = $fileContent.IndexOf($headingOfExamples)

    $exampleNumber = 0
    $missingSynopsis = 0
    $missingDescription = 0
    $missingExampleTitle = 0
    $missingExampleCode = 0
    $missingExampleOutput = 0
    $missingExampleDescription = 0
    $needDeleting = 0
    $needSplitting = 0

    # If Synopsis section exists
    if ($indexOfSynopsis -ne -1) {
        $synopsisContent = $fileContent.Substring($indexOfSynopsis + $headingOfSynopsis.Length, $indexOfSyntax - ($indexOfSynopsis + $headingOfSynopsis.Length))
        if ($synopsisContent.Trim() -eq "") {
            $missingSynopsis = 1
        }
        else {
            $missingSynopsis = ($synopsisContent | Select-String -Pattern "{{[A-Za-z ]*}}").Count
        }
    }
    else {
        $missingSynopsis = 1
    }

    # If Description section exists
    if ($indexOfDescription -ne -1) {
        $descriptionContent = $fileContent.Substring($indexOfDescription + $headingOfDescription.Length, $indexOfExamples - ($indexOfDescription + $headingOfDescription.Length))
        if ($descriptionContent.Trim() -eq "") {
            $missingDescription = 1
        }
        else {
            $missingDescription = ($descriptionContent | Select-String -Pattern "{{[A-Za-z ]*}}").Count
        }
    }
    else {
        $missingDescription = 1
    }

    $examplesDetails = Get-ExamplesDetailsFromMd $MarkdownPath
    # If no examples
    if ($examplesDetails.Count -eq 0) {
        $missingExampleTitle++
        $missingExampleCode++
        $missingExampleOutput++
        $missingExampleDescription++
    }
    else {
        foreach ($exampleDetails in $examplesDetails) {
            $exampleNumber++

            switch ($exampleDetails) {
                {$exampleDetails.Title -eq ""} {
                    $missingExampleTitle++
                }
                {$exampleDetails.Codes.Count -eq 0} {
                    $missingExampleCode++
                }
                {$exampleDetails.OutputBlocks.Count -ne 0 -and $exampleDetails.Outputs.Count -eq 0} {
                    $missingExampleOutput++
                }
                {$exampleDetails.OutputBlocks.Count -eq 0 -and $exampleDetails.Outputs.Count -ne 0} {
                    $needSplitting++
                }
                {$exampleDetails.Description -eq ""} {
                    $missingExampleDescription++
                }
            }
            $needDeleting = ($examplesDetails.CodeBlocks | Select-String -Pattern "\n([A-Za-z \t\\:>])*(PS|[A-Za-z]:)(\w|[\\/\[\].\- ])*(>|&gt;)+( PS)*[ \t]*" -CaseSensitive).Count +
                ($examplesDetails.CodeBlocks | Select-String -Pattern "(?<=[A-Za-z]\w+-[A-Za-z]\w+)\.ps1" -CaseSensitive).Count

            # Delete prompts
            $exampleCodes = $exampleDetails.Codes
            for ($i = $exampleCodes.Count - 1; $i -ge 0; $i--) {
                $newCode = $exampleDetails.Codes[$i] -replace "\n([A-Za-z \t\\:>])*(PS|[A-Za-z]:)(\w|[\\/\[\].\- ])*(>|&gt;)+( PS)*[ \t]*", "`n"
                $newCode = $newCode -replace "(?<=[A-Za-z]\w+-[A-Za-z]\w+)\.ps1", ""
                $exampleCodes[$i] = $newCode
            }

            $cmdletExamplesScriptPath = "$OutputPath\$module"
            # Output codes by example
            if ($OutputExampleScript.IsPresent) {
                $null = New-Item -ItemType Directory -Path $cmdletExamplesScriptPath -ErrorAction SilentlyContinue
                [IO.File]::WriteAllText("$cmdletExamplesScriptPath\$cmdlet-$exampleNumber.ps1", $exampleDetails.Codes -join "`n", (New-Object Text.UTF8Encoding($false)))
            }
            # Analyze codes
            if ($AnalyzeExampleScript.IsPresent) {
                $analysisResults = Get-ScriptAnalyzerResult $module $cmdletExamplesScriptPath $RulePath -IncludeDefaultRules:$IncludeDefaultRules.IsPresent -ErrorAction Continue
            }
        }
    }

    $status = $null
    $missing = $null
    $deletePromptAndSeparateOutput = $null

    # StatusTable
    $examples = $examplesDetails.Count
    if ($PublishedCmdletDocs -ne $null -and !$PublishedCmdletDocs.Contains($cmdlet)) {
        $isInPublishedDocs = "False"
    }
    else {
        $isInPublishedDocs = $null
    }
    $status = [PSCustomObject]@{
        Module = $module
        Cmdlet = $cmdlet
        Examples = $examples
        isInPublishedDocs = $isInPublishedDocs
    }

    if ($isInPublishedDocs -eq $null) {
        # MissingTable
        $missingExampleTitle += ($examplesDetails.Title | Select-String -Pattern "{{[A-Za-z ]*}}").Count
        $missingExampleCode += ($examplesDetails.Codes | Select-String -Pattern "{{[A-Za-z ]*}}").Count
        $missingExampleOutput += ($examplesDetails.Outputs | Select-String -Pattern "{{[A-Za-z ]*}}").Count
        $missingExampleDescription += ($examplesDetails.Description | Select-String -Pattern "{{[A-Za-z ]*}}").Count

        if ($missingSynopsis -ne 0 -or $missingDescription -ne 0 -or $missingExampleTitle -ne 0 -or $missingExampleCode -ne 0 -or $missingExampleOutput -ne 0 -or $missingExampleDescription -ne 0) {
            $missing = [PSCustomObject]@{
                Module = $module
                Cmdlet = $cmdlet
                MissingSynopsis = $missingSynopsis
                MissingDescription = $missingDescription
                MissingExampleTitle = $missingExampleTitle
                MissingExampleCode = $missingExampleCode
                MissingExampleOutput = $missingExampleOutput
                MissingExampleDescription = $missingExampleDescription
            }
        }

        # DeletePromptAndSeparateOutputTable
        if ($needDeleting -ne 0 -or $needSplitting -ne 0) {
            $deletePromptAndSeparateOutput = [PSCustomObject]@{
                Module = $module
                Cmdlet = $cmdlet
                NeedDeleting = $needDeleting
                NeedSplitting = $needSplitting
            }
        }
    }

    return @{
        Status = $status
        Missing = $missing
        DeletePromptAndSeparateOutput = $deletePromptAndSeparateOutput
        AnalysisResults = $analysisResults
    }
}
