#-------------------------------------------------------------------
#  Vidtools
#  Manage hashtags inside filenames
#-------------------------------------------------------------------

param (
    [switch]$list=$false,
    [switch]$l=$false,

    [switch]$browse=$false,
    [switch]$b=$false,

    [switch]$onlyuntagged=$false,
    [switch]$ou=$false,

    [switch]$onlytagged=$false,
    [switch]$ot=$false,

    [switch]$quiet=$false,
    [switch]$q=$false,

    [switch]$tagcloud=$false,
    [switch]$rewrite=$false,
    [switch]$nowrite=$false,

    [string]$filespec="*",
    [string]$f="*",

    [string]$bulktag="",
    [string]$bt="",

    [string]$addtags="",
    [string]$add="",
    [string]$deltags="",
    [string]$del="",

    [string]$output="n",
    [string]$o="n",

    [string]$all="",
    [string]$none="",
    [string]$any="",
    [string]$notin="",
    
    [string]$toss="",
    [string]$t="",

    [string]$indexfolder="",
    [string]$i="",

    [string]$tossindex="",
    [string]$tagsfromfile="",
    [switch]$tagsfromexif=$false,
    [switch]$clearexif=$false,

    [string]$replace="",
    [string]$with="",

    [string]$quote='',
    [string]$separator=","
)

# Get some values into variables
$cCurrentpath = (Resolve-Path ".\").Path + [IO.Path]::DirectorySeparatorChar
$cTagDelimiter = "#"
$cAllowedHashChars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
$sTempFolder = "." + [IO.Path]::DirectorySeparatorChar

#-------------------------------------------------------------------
# Accept a string that is a filename and return only the portion before the tags begin, trimmed of spaces
#-------------------------------------------------------------------
function fGetBaseName( $sI ) {
    # Isolate filename from path safely
    if ($sI.Contains([IO.Path]::DirectorySeparatorChar)) { 
        $sI = $sI.SubString($sI.LastIndexOf([IO.Path]::DirectorySeparatorChar) + 1) 
    }
    
    # Strip extension safely
    if ($sI.Contains(".")) { 
        $sI = $sI.SubString(0, $sI.LastIndexOf(".")) 
    }

    # Strip tags at the first delimiter
    if ($sI.Contains($cTagDelimiter)) { 
        $sI = $sI.SubString(0, $sI.IndexOf($cTagDelimiter)) 
    }

    return $sI.TrimEnd(" ")
}

#-------------------------------------------------------------------
# Accept a string and return a parsed List of Tags. Duplicates ignored and sorted.
#-------------------------------------------------------------------
function fTagsFromString( $sI ) {
    $aTags = [System.Collections.Generic.List[string]]::new()
    
    if ($sI.Contains([IO.Path]::DirectorySeparatorChar)) { 
        $sI = $sI.SubString($sI.LastIndexOf([IO.Path]::DirectorySeparatorChar) + 1) 
    }
    
    if ($sI.Contains(".")) { 
        $sI = $sI.SubString(0, $sI.LastIndexOf(".")) 
    }

    if ($sI.IndexOf($cTagDelimiter) -eq -1) { 
        return $aTags 
    } else { 
        $sI = $sI.Substring($sI.IndexOf($cTagDelimiter)) 
    } 
                                                                                                                                                                                
    $aTempTags = $sI.Split($cTagDelimiter)
    foreach ($sTempTag in $aTempTags) {
        $sTempTag = $cTagDelimiter + $sTempTag.Trim(" ")

        if (($sTempTag.Length -gt 1) -and
            ($cAllowedHashChars.Contains($sTempTag.SubString(1, 1))) -and
            (-not $aTags.Contains($sTempTag))) { 
                $aTags.Add($sTempTag)
        }
    }

    $aTags.Sort()
    return $aTags
}

#-------------------------------------------------------------------
# Main executable body begin
#-------------------------------------------------------------------

if ($ot) { $onlytagged = $ot }
if ($ou) { $onlyuntagged = $ou }
if ($q) { $quiet = $q }
if ($l) { $list = $l }
if ($f -ne "*") { $filespec = $f }
if ($o -ne "n") { $output = $o }
if ($t -ne "") { $toss = $t }
if ($add -ne "") { $addtags = $add }
if ($del -ne "") { $deltags = $del }
if ($bt -ne "") { $bulktag = $bt }
if ($b) { $browse = $b }
if ($i -ne "") { $indexfolder = $i }

if (-not $quiet) {
    Write-Host ------------------------------------------
    Write-Host " "VIDTOOLS - Work with video metadata
    Write-Host ------------------------------------------
}

if ($onlytagged -and $onlyuntagged) {
    if (-not $quiet) { Write-Host "ERROR: Command-line switches -onlyuntagged and -onlytagged are mutually exclusive" -ForegroundColor Red }
    exit
}
if (($onlytagged -or $onlyuntagged) -and $all) {
    if (-not $quiet) { Write-Host "ERROR: Command-line switches -onlyuntagged or -onlytagged cannot be used in conjunction with -all" -ForegroundColor Red }
    exit
}
if (($onlytagged -or $onlyuntagged) -and $none) {
    if (-not $quiet) { Write-Host "ERROR: Command-line switches -onlyuntagged or -onlytagged cannot be used in conjunction with -none" -ForegroundColor Red }
    exit
}
if (($onlytagged -or $onlyuntagged) -and $any) {
    if (-not $quiet) { Write-Host "ERROR: Command-line switches -onlyuntagged or -onlytagged cannot be used in conjunction with -any" -ForegroundColor Red }
    exit
}
if (($onlytagged -or $onlyuntagged) -and $notin) {
    if (-not $quiet) { Write-Host "ERROR: Command-line switches -onlyuntagged or -onlytagged cannot be used in conjunction with -notin" -ForegroundColor Red }
    exit
}

if ($replace) {
    if (Test-Path -Path $replace -PathType Leaf) {
        $sReplaceMode = "file"
        if ($with -and (-not $quiet)) { 
            Write-Host "ERROR: Cannot use the switch -with if -replace points to an input file" -ForegroundColor Red 
            exit
        }
    }
    else {
        $sReplaceMode = "string"
        if (-not $with) {
            if (-not $quiet) { 
                Write-Host "ERROR: The command -replace must be paired with the switch -with" -ForegroundColor Red 
            }
            exit
        }
    }
}

# Initialize a strongly-typed .NET List for tags that MUST be present (-all)
$aAndTags = [System.Collections.Generic.List[string]]::new()
if ($all) {
    # If the argument points to a valid file, read its contents line by line
    if (Test-Path -Path $all -PathType Leaf) {
        foreach ($sTag in (Get-Content -Path $all)) { $aAndTags.Add($sTag) }
    }
    # Otherwise, parse the tags directly from the string argument.
    # The foreach loop forces PowerShell to safely unwrap any Object[] array 
    # and coerce each individual item into a clean [string] upon insertion.
    else { 
        foreach ($sTag in (fTagsFromString($all))) { $aAndTags.Add($sTag) }
    }
}

# Initialize a strongly-typed .NET List for tags that MUST NOT be present (-none)
$aNotTags = [System.Collections.Generic.List[string]]::new()
if ($none) {
    if (Test-Path -Path $none -PathType Leaf) {
        foreach ($sTag in (Get-Content -Path $none)) { $aNotTags.Add($sTag) }
    }
    else { 
        foreach ($sTag in (fTagsFromString($none))) { $aNotTags.Add($sTag) }
    }
}

# Initialize a strongly-typed .NET List for tags where ANY match qualifies (-any)
$aOrTags = [System.Collections.Generic.List[string]]::new()
if ($any) {
    if (Test-Path -Path $any -PathType Leaf) {
        foreach ($sTag in (Get-Content -Path $any)) { $aOrTags.Add($sTag) }
    }
    else { 
        foreach ($sTag in (fTagsFromString($any))) { $aOrTags.Add($sTag) }
    }
}

# Initialize a strongly-typed .NET List for filtering out files based on a strict tag whitelist (-notin)
$aNotinTags = [System.Collections.Generic.List[string]]::new()
if ($notin) {
    if (Test-Path -Path $notin -PathType Leaf) {
        foreach ($sTag in (Get-Content -Path $notin)) { $aNotinTags.Add($sTag) }
    }
    else { 
        foreach ($sTag in (fTagsFromString($notin))) { $aNotinTags.Add($sTag) }
    }
}

$aChildItems = @(Get-ChildItem $filespec -File) 

$aFiles = ForEach ($oChildItem in $aChildItems) {
    $aTempTags = fTagsFromString($oChildItem.Name)
    $bQualifies = $true

    if ($onlyuntagged -and ($aTempTags.Count -gt 0)) { $bQualifies = $false }
    if ($onlytagged -and ($aTempTags.Count -eq 0)) { $bQualifies = $false }
    
    if ($aAndTags.Count -gt 0) { 
        if ($aTempTags.Count -gt 0) {
            foreach ($sTempTag in $aAndTags) { 
                if (-not $aTempTags.Contains($sTempTag)) { $bQualifies = $false }
            }
        } else { $bQualifies = $false }
    }

    if ($aNotTags.Count -gt 0) {
        if ($aTempTags.Count -gt 0) {
            foreach ($sTempTag in $aNotTags) { 
                if ($aTempTags.Contains($sTempTag)) { $bQualifies = $false }
            }
        }
    }

    if ($aOrTags.Count -gt 0) {
        $bWasFound = $false
        if ($aTempTags.Count -gt 0) {
            foreach ($sTempTag in $aOrTags) {
                if ($aTempTags.Contains($sTempTag)) { $bWasFound = $true }
            }
        }
        if (-not $bWasFound) { $bQualifies = $false }
    }
    
    if ($aNotinTags.Count -gt 0) {
        $bQualifies = $false
        $bWasFound = $true
        if ($aTempTags.Count -gt 0) {
            foreach ($sTempTag in $aTempTags) {
                if ($aNotinTags -notcontains $sTempTag) { $bWasFound = $false }
            }
            if (-not $bWasFound) { $bQualifies = $true }
        }
    }

    if ($bQualifies) {
        New-Object -TypeName PSObject -Property @{
            Name = $oChildItem.Name
            Extension = $oChildItem.Extension
            Basename = fGetBaseName($oChildItem.Name)
            Qualified = [System.String]::Concat($oChildItem.Directory, [IO.Path]::DirectorySeparatorChar, $oChildItem.Name)
            Directory = $oChildItem.Directory
            Tags = $aTempTags
        }
    }
}

if ($aFiles.Count -eq 0) {
    if (-not $quiet) { Write-Host "No matching files found" -ForegroundColor Cyan }
    exit
}

#-------------------------------------------------------------------
# Process the -list command
#-------------------------------------------------------------------
if ($list) {
    $bOutputCodeError = $false

    if ($browse) { 
        $sTempFile = $sTempFolder + [IO.Path]::DirectorySeparatorChar + "vt-temp.txt"
        if (-not $quiet) { Write-Host Sending output to $sTempFile file... -ForegroundColor Cyan }
        $quiet=$true
        Write-Output "" | Out-File -FilePath $sTempFile -NoNewline
        $output="q"
    }

    foreach ($oChildItem in $aFiles) {
        $sOutputString = ""

        for ($iCounter=0; $iCounter -lt $output.Length; $iCounter++) {
            $bValid = $false

            switch ($output.Substring($iCounter, 1)) {
                "n" {
                    $sOutputString = [System.String]::Concat($sOutputString, $quote, $oChildItem.Name, $quote)
                    $bValid = $true
                }
                "b" {
                    $sOutputString = [System.String]::Concat($sOutputString, $quote, $oChildItem.Basename, $quote)
                    $bValid = $true
                }
                "q" {
                    $sOutputString = [System.String]::Concat($sOutputString, $quote, $oChildItem.Qualified, $quote)
                    $bValid = $true
                }
                "d" {
                    $sOutputString = [System.String]::Concat($sOutputString, $quote, $oChildItem.Directory, $quote)
                    $bValid = $true
                }
                "e" {
                    $sOutputString = [System.String]::Concat($sOutputString, $quote, $oChildItem.Extension, $quote)
                    $bValid = $true
                }
                "t" {
                    foreach ($sTag in $oChildItem.Tags) {
                        $sOutputString = [System.String]::Concat($sOutputString, $sTag)
                    }
                    $bValid = $true
                }
                default { $bOutputCodeError = $true }
            }

            if (($iCounter -lt ($output.Length - 1)) -and ($bValid -eq $true)) { 
                $sOutputString = [System.String]::Concat($sOutputString, $separator)
            }
        }
         
        if ($browse) {
            Write-Output $sOutputString | Out-File -FilePath $sTempFile -Append
        } else { 
            Write-Output $sOutputString 
        }
    }

    if (($bOutputCodeError) -and (-not $quiet)) { Write-Host "One or more invalid output codes specified in $output" -ForegroundColor Cyan }
    if (-not $quiet) { Write-Host $aFiles.Count files -ForegroundColor Cyan }
    if ($browse) { & "xnv" -filelist $sTempFile }
    exit
}

#-------------------------------------------------------------------
# Process the -toss command
#-------------------------------------------------------------------
if ($toss) {
    $iFilesProcessed = 0
    if ($toss.Substring($toss.Length - 1, 1) -ne [IO.Path]::DirectorySeparatorChar) { $toss += [IO.Path]::DirectorySeparatorChar }

    if (Test-Path -Path $toss -PathType Container) {
        foreach ($oChildItem in $aFiles) {
            $sSourceFile = $oChildItem.Qualified
            $sTargetFile = $toss + $oChildItem.Name

            if (-not (Test-Path -Path $sTargetFile -PathType Leaf)) {
                Write-Output [System.String]::Concat($oChildItem.Name, " -> ", $toss)

                if (-not $nowrite) { 
                    Move-Item -Path $sSourceFile -Destination $sTargetFile
                    $iFilesProcessed++ 
                }
            } else {
                if (-not $quiet) { Write-Host "Not moving $($oChildItem.Name) as it already exists in target" -ForegroundColor Cyan }
            }
        }
    } else {
        if (-not $quiet) { Write-Host ERROR: Folder $toss does not exist -ForegroundColor Red }
        exit
    }
    if (-not $quiet) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }
    exit
}

#-------------------------------------------------------------------
# Process the -replace command
#-------------------------------------------------------------------
if ($replace) {
    $iFilesProcessed = 0
    if ($sReplaceMode -eq "file") { $aSubstitutions = Import-Csv -Path $replace -Header 'String1', 'String2' }

    foreach ($oChildItem in $aFiles) {
        if ($sReplaceMode -eq "string") {
            $sNewShortName = $oChildItem.Name.Replace($replace, $with)

            if ($oChildItem.Name -ne $sNewShortName) {
                $sSourceFile = $oChildItem.Qualified
                $sTargetFile = [System.String]::Concat($oChildItem.Directory, [IO.Path]::DirectorySeparatorChar, $sNewShortName)

                if (-not (Test-Path -Path $sTargetFile -PathType Leaf)) {
                    Write-Output [System.String]::Concat($sSourceFile, " -> ", $sTargetFile)
                    if (-not $nowrite) { 
                        Rename-Item -Path $sSourceFile -NewName $sTargetFile
                        $iFilesProcessed++
                    }
                } else {
                    if (-not $quiet) { Write-Host "WARNING: File $sNewShortName already exists" -ForegroundColor Cyan }
                }
            }
        } else {
            foreach ($aSubstitution in $aSubstitutions) {
                if ($oChildItem.Name.Contains($aSubstitution.String1)) {
                    $sNewShortName = $oChildItem.Name.Replace($aSubstitution.String1, $aSubstitution.String2)
                    $sSourceFile = $oChildItem.Qualified
                    $sTargetFile = [System.String]::Concat($oChildItem.Directory, [IO.Path]::DirectorySeparatorChar, $sNewShortName)

                    if (-not (Test-Path -Path $sTargetFile -PathType Leaf)) {
                        Write-Output [System.String]::Concat($sSourceFile, " -> ", $sTargetFile)
                        if (-not $nowrite) { 
                            Rename-Item -Path $sSourceFile -NewName $sTargetFile
                            $iFilesProcessed++
                        }
                    } else {
                        if (-not $quiet) { Write-Host "WARNING: File $sNewShortName already exists" -ForegroundColor Cyan }
                    }
                }
            }
        }
    }
    if (-not $quiet) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }
    exit
}

#-------------------------------------------------------------------
# Process the -tagcloud command
#-------------------------------------------------------------------
if( $tagcloud ) {
    # Initialize a hash table to keep track of tag frequencies
    $hTagCounts = @{}
    $iTagsProcessed = 0

    # First loop through every file
    foreach( $oChildItem in $aFiles ) {

        # Then loop through each tag in every file
        foreach( $sTempTag in $oChildItem.Tags ) {
            
            if( $hTagCounts.ContainsKey( $sTempTag ) ) {
                $hTagCounts[ $sTempTag ]++
            } else {
                $hTagCounts[ $sTempTag ] = 1
                $iTagsProcessed++
            }

        } #foreach

    } #foreach

    # Sort the hash table by frequency (Value) in descending order
    $aSortedTags = $hTagCounts.GetEnumerator() | Sort-Object -Property Value -Descending

    # Now write them all to view with their counts in round brackets
    foreach( $oTag in $aSortedTags ) { 
        Write-Output "$($oTag.Name) ($($oTag.Value))" 
    }

    # Output the number of unique tags processed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iTagsProcessed unique tags -ForegroundColor Cyan }

    # To avoid shitty conflicting command-lines, just quit now
    exit
} #if

#-------------------------------------------------------------------
# Process the -addtags command
#-------------------------------------------------------------------
#-------------------------------------------------------------------
# Process the -addtags command
#-------------------------------------------------------------------
if( $addtags ) {
    $iFilesProcessed = 0
    # Initialize a strongly-typed .NET List for addition tags
    $aAddTags = [System.Collections.Generic.List[string]]::new()

    # Safely unwrap and coerce individual items into strings using standard loops
    if( Test-Path -Path $addtags -PathType Leaf ) {
        foreach ($sTag in (Get-Content -Path $addtags)) { $aAddTags.Add($sTag) }
    } else { 
        foreach ($sTag in (fTagsFromString($addtags))) { $aAddTags.Add($sTag) }
    }
	
    # Error out if no tags were parsed
    if( $aAddTags.Count -le 0 ) {
        if( -not $quiet ) { 
            Write-Host 'ERROR: Switch -addtags was used but no valid tags were supplied' -ForegroundColor Red
            exit 
        } #if
    }
	
    foreach ($oChildItem in $aFiles) {
        $bTempFlag = $false
	
        foreach ($sTempTag in $aAddTags) {
            if (-not $oChildItem.Tags.Contains($sTempTag)) {
                if ("#1#2#3#4#5".Contains($sTempTag)) {
                    for ($iCounter = 0; $iCounter -le ($oChildItem.Tags.Count - 1); $iCounter++) {
                        if ("#1#2#3#4#5".Contains($oChildItem.Tags[$iCounter])) { 
                            $oChildItem.Tags[$iCounter] = $sTempTag 
                            $bTempFlag = $true
                        }
                    }
                    if (-not $bTempFlag) { 
                        $oChildItem.Tags.Add($sTempTag)
                        $bTempFlag = $true
                    }
                } else {
                    $oChildItem.Tags.Add($sTempTag)
                    $bTempFlag = $true
                }
            }
        }
		
        if ($bTempFlag) {
            $sBaseOnly = fGetBaseName($oChildItem.Name)
            $sTargetFile = [System.String]::Concat($oChildItem.Directory, [IO.Path]::DirectorySeparatorChar, $sBaseOnly)
            
            $oChildItem.Tags.Sort()
            if ($oChildItem.Tags.Count -gt 0) {
                $sTargetFile += " "
                foreach ($sTempTag in $oChildItem.Tags) { $sTargetFile += $sTempTag }
            }
            $sTargetFile = [System.String]::Concat($sTargetFile, $oChildItem.Extension)
            $sSourceFile = $oChildItem.Qualified
			
            if (-not (Test-Path -Path $sTargetFile -PathType Leaf)) {
                if (-not $nowrite) { 
                    Rename-Item -Path $sSourceFile -NewName $sTargetFile
                    $iFilesProcessed++
                }
                Write-Output [System.String]::Concat($sSourceFile, " -> ", $sTargetFile)
            } else {
                if (-not $quiet) { Write-Host "WARNING: File $sTargetFile already exists" -ForegroundColor Cyan }
            }
        }
    }
    if (-not $quiet) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }
    exit
}

#-------------------------------------------------------------------
# Process the -deltags command
#-------------------------------------------------------------------
if( $deltags ) {
    $iFilesProcessed = 0
    # Initialize a strongly-typed .NET List for deletion tags
    $aDelTags = [System.Collections.Generic.List[string]]::new()
	
    # Safely unwrap and coerce individual items into strings using standard loops
    if( Test-Path -Path $deltags -PathType Leaf ) {
        foreach ($sTag in (Get-Content -Path $deltags)) { $aDelTags.Add($sTag) }
    } else { 
        foreach ($sTag in (fTagsFromString($deltags))) { $aDelTags.Add($sTag) }
    }
	
    # Error out if no tags were parsed
    if( $aDelTags.Count -le 0 ) {
        if( -not $quiet ) { 
            Write-Host 'ERROR: Switch -deltags was used but no valid tags were supplied' -ForegroundColor Red
            exit 
        } #if
    } #if
	
    foreach ($oChildItem in $aFiles) {
        $sSourcePath = [System.String]::Concat($oChildItem.Directory, [IO.Path]::DirectorySeparatorChar)
        $sSourceFile = $oChildItem.Name
        $sTargetFile = $oChildItem.Name
        $bTempFlag = $false
	
        foreach ($sTempTag in $aDelTags) {
            if (($oChildItem.Tags.Count -gt 0) -and ($oChildItem.Tags.Contains($sTempTag))) {
                while ($sTargetFile.IndexOf($sTempTag) -ge 0) {
                    $bTempFlag = $true
                    $sTargetFile = $sTargetFile.Remove($sTargetFile.IndexOf($sTempTag), $sTempTag.Length)
                }
            }
        }
		
        if ($bTempFlag) {
            $sSourceFile = $sSourcePath + $sSourceFile
            $sTargetFile = $sSourcePath + $sTargetFile
			
            if (-not (Test-Path -Path $sTargetFile -PathType Leaf)) {
                if (-not $nowrite) { 
                    Rename-Item -Path $sSourceFile -NewName $sTargetFile
                    $iFilesProcessed++
                }
                Write-Output [System.String]::Concat($sSourceFile, " -> ", $sTargetFile)
            } else {
                if (-not $quiet) { Write-Host "WARNING: File $sTargetFile already exists" -ForegroundColor Cyan }
            }
        }
    }
    if (-not $quiet) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }
    exit
}

#-------------------------------------------------------------------
# Process the -rewrite command
#-------------------------------------------------------------------
if ($rewrite) {
    $iFilesProcessed = 0
	
    foreach ($oChildItem in $aFiles) {
        $sSourcePath = [System.String]::Concat($oChildItem.Directory, [IO.Path]::DirectorySeparatorChar)
        $sSourceFile = $oChildItem.Name
        $sTargetFile = fGetBaseName($oChildItem.Name)
	
        if ($oChildItem.Tags.Count -gt 0) {
            $sTargetFile = $sTargetFile + " "
            foreach ($sTempTag in $oChildItem.Tags) {
                $sTargetFile = $sTargetFile + $sTempTag
            }
        }
        $sTargetFile = $sTargetFile + $oChildItem.extension
		
        if ($sSourceFile -ne $sTargetFile) {
            $sSourceFile = $sSourcePath + $sSourceFile
            $sTargetFile = $sSourcePath + $sTargetFile		
			
            if (-not (Test-Path -Path $sTargetFile -PathType Leaf)) {
                if (-not $nowrite) { 
                    Rename-Item -Path $sSourceFile -NewName $sTargetFile
                    $iFilesProcessed++
                }
                Write-Output [System.String]::Concat($sSourceFile, " -> ", $sTargetFile)
            } else {
                if (-not $quiet) { Write-Host "WARNING: File $sTargetFile already exists" -ForegroundColor Cyan }
            }			
        }
    }
    if (-not $quiet) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }
    exit
}

#-------------------------------------------------------------------
# Process the -bulktag command
#-------------------------------------------------------------------
if ($bulktag) {
    if (Test-Path -Path $bulktag -PathType Leaf) {
        $iFilesProcessed = 0
        $aBulkTags = Import-Csv -Path $bulktag -Header 'SearchString', 'Tags'
		
        for ($iCounter = 0; $iCounter -lt $aBulkTags.Count; $iCounter++) { 
            $aBulkTags[$iCounter].SearchString = $aBulkTags[$iCounter].SearchString.ToLower() 
        }
		
        foreach ($oChildItem in $aFiles) {
            $bChangesMade = $false
            $sSourcePath = [System.String]::Concat($oChildItem.Directory, [IO.Path]::DirectorySeparatorChar)
            $sSourceFile = $oChildItem.Name
            $sTargetFile = $oChildItem.BaseName
            $sBaseName = $oChildItem.Name.ToLower()
			
            foreach ($oBulkTag in $aBulkTags) {
                if ($sBaseName.Contains($oBulkTag.SearchString)) {
                    $aTempTags = fTagsFromString($oBulkTag.Tags)
					
                    if ($aTempTags.Count -gt 0) {
                        $sTargetFile += " "
                        foreach ($sTempTag in $aTempTags) {
                            if ($oChildItem.Tags.Count -eq 0) {
                                $bChangesMade = $true
                                $sTargetFile = $sTargetFile + $sTempTag								
                            } else {
                                if (-not $oChildItem.Tags.Contains($sTempTag)) {
                                    if ("#1#2#3#4#5".Contains($sTempTag) -and ($sTargetFile.Contains("#1") -or $sTargetFile.Contains("#2") -or $sTargetFile.Contains("#3") -or $sTargetFile.Contains("#4") -or $sTargetFile.Contains("#5"))) { }
                                    else {
                                        $bChangesMade = $true
                                        $sTargetFile = $sTargetFile + $sTempTag	
                                    }
                                }
                            }
                        }
                    }
                }
            }
			
            if ($bChangesMade) {
                $sSourceFile = $sSourcePath + $sSourceFile
                $sTargetFile = $sSourcePath + $sTargetFile + $oChildItem.Extension			
                Write-Output [System.String]::Concat($sSourceFile, " -> ", $sTargetFile)
				 
                if (-not $nowrite) { 
                    Rename-Item -Path $sSourceFile -NewName $sTargetFile 
                    $iFilesProcessed++	
                }
            }
        }
        if (-not $quiet) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }
    } else { 
        if (-not $quiet) { Write-Host "ERROR: Bulk tag input file $bulktag not found" -ForegroundColor Red }
        exit
    }
    exit	
}

#-------------------------------------------------------------------
# Process the -indexfolder command
#-------------------------------------------------------------------
if ($indexfolder) {
    $iFilesProcessed = 0
    if ($indexfolder.Substring($indexfolder.Length - 1, 1) -ne [IO.Path]::DirectorySeparatorChar) { $indexfolder += [IO.Path]::DirectorySeparatorChar }
    
    if (-not (Test-Path -Path $indexfolder -PathType Container)) {
        Write-Host "ERROR: Index folder $indexfolder does not exist" -ForegroundColor Red
        exit
    }

    foreach ($oChildItem in $aFiles) {
        if ($oChildItem.Name.Contains("-")) {
            $sSourcePath = [System.String]::Concat($oChildItem.Directory, [IO.Path]::DirectorySeparatorChar)
            $sSourceFile = [System.String]::Concat($sSourcePath, $oChildItem.Name)
            $sTargetFile = [System.String]::Concat($sSourcePath, $oChildItem.BaseName)

            $sFileSpec = $indexfolder + $oChildItem.Name.Substring(0, $oChildItem.Name.IndexOf("-")) + " *" + $oChildItem.Extension
            $aFilesinIndex = @(Get-ChildItem $sFileSpec)

            if ($aFilesinIndex.Count -gt 0) {
                $sBaseName = $aFilesinIndex[0].Name.SubString(0, $aFilesinIndex[0].Name.Length - $aFilesinIndex[0].Extension.Length)
                $aTempTags = fTagsFromString($sBaseName)

                if ($aTempTags.Count -gt 0) {
                    foreach ($sTempTag in $aTempTags) { 
                        if ("#1#2#3#4#5".Contains($sTempTag) -and ($sTargetFile.Contains("#1") -or $sTargetFile.Contains("#2") -or $sTargetFile.Contains("#3") -or $sTargetFile.Contains("#4") -or $sTargetFile.Contains("#5"))) { }
                        elseif (-not $sTargetFile.Contains($sTempTag)) { $sTargetFile += $sTempTag }
                    }

                    $sTargetFile += $oChildItem.Extension
                    Write-Output [System.String]::Concat($sSourceFile, " -> ", $sTargetFile)

                    if (-not $nowrite) { 
                        Rename-Item -Path $sSourceFile -NewName $sTargetFile 
                        $iFilesProcessed++	
                    }
                }
            }
        }
    }
    if (-not $quiet) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }
    exit	
}

#-------------------------------------------------------------------
# Process the -tossindex command
#-------------------------------------------------------------------
if ($tossindex) {
    $iFilesProcessed = 0
    if ($tossindex.Substring($tossindex.Length - 1, 1) -ne [IO.Path]::DirectorySeparatorChar) { $tossindex += [IO.Path]::DirectorySeparatorChar }
    
    if (-not (Test-Path -Path $tossindex -PathType Container)) {
        Write-Host "ERROR: Index folder $tossindex does not exist" -ForegroundColor Red
        exit
    }

    foreach ($oChildItem in $aFiles) {
        if ($oChildItem.Name.Contains("-")) {
            $sSourceFile = [System.String]::Concat($oChildItem.Directory, [IO.Path]::DirectorySeparatorChar, $oChildItem.Name)
            $sTargetFile = $tossindex + $oChildItem.Name.Substring(0, $oChildItem.Name.IndexOf("-")) + [IO.Path]::DirectorySeparatorChar

            if (Test-Path -Path $sTargetFile -PathType Container) {
                $sTargetFile += $oChildItem.Name
                Write-Output [System.String]::Concat($sSourceFile, " -> ", $sTargetFile)

                if (-not $nowrite) { 
                    if (-not (Test-Path -Path $sTargetFile -PathType Leaf)) {
                        Move-Item -Path $sSourceFile -Destination $sTargetFile
                        $iFilesProcessed++
                    } else {
                        Write-Host "WARNING: Source already exists in target" -ForegroundColor Red
                    }
                }
            }
        }
    }
    if (-not $quiet) { Write-Host $iFilesProcessed files moved -ForegroundColor Cyan }
    exit	
}

#-------------------------------------------------------------------
# Process the -tagsfromfile command
#-------------------------------------------------------------------
if ($tagsfromfile) {
    $iFilesProcessed = 0
    if (-not (Test-Path -Path $tagsfromfile -PathType Leaf)) {
        Write-Host "ERROR: Source file $tagsfromfile does not exist" -ForegroundColor Red
        exit
    }

    $aSourceTags = fTagsFromString($tagsfromfile)

    foreach ($oChildItem in $aFiles) { 
        $aTargetTags = fTagsFromString($oChildItem.Name)
        $sSourceFile = $oChildItem.Qualified
        $sTargetFile = [System.String]::Concat($oChildItem.Directory, [IO.Path]::DirectorySeparatorChar)
        $sTargetFile += fGetBaseName($oChildItem.Name)
        $bChangesMade = $false

        foreach ($sTempTag in $aSourceTags) {
            if ("#1#2#3#4#5".Contains($sTempTag) -and ($aTargetTags.Contains("#1") -or $aTargetTags.Contains("#2") -or $aTargetTags.Contains("#3") -or $aTargetTags.Contains("#4") -or $aTargetTags.Contains("#5"))) { }
            elseif (-not $aTargetTags.Contains($sTempTag)) { 
                $aTargetTags.Add($sTempTag)
                $bChangesMade = $true
            }
        }

        if ($bChangesMade) {
            $sTargetFile += " "
            $aTargetTags.Sort()

            foreach ($sTempTag in $aTargetTags) { $sTargetFile += $sTempTag }
            $sTargetFile += $oChildItem.Extension
            Write-Output [System.String]::Concat($sSourceFile, " -> ", $sTargetFile)

            if (-not $nowrite) { 
                Move-Item -Path $sSourceFile -Destination $sTargetFile 
                $iFilesProcessed++	
            }
        }
    }
    if (-not $quiet) { Write-Host $iFilesProcessed files moved -ForegroundColor Cyan }
    exit	
}

#-------------------------------------------------------------------
# Process the -tagsfromexif command
#-------------------------------------------------------------------
if ($tagsfromexif) {
    $iFilesProcessed = 0
    $sFileFormat = "image"

    if ($filespec.Contains("mp4")) { $sFileFormat = "video" }
    
    # Leverages env path execution rather than rigid driver path bindings
    if ($sFileFormat -eq "video") {
        & export-mp4-exif $filespec
    } else {
        & export-jpg-exif $filespec
    }

    if (-not (Test-Path -Path 'temp.csv' -PathType Leaf)) {
        Write-Host "ERROR: Temp file temp.csv could not be read" -ForegroundColor Red
        exit
    }

    $aExifTemp = Import-Csv -Delimiter ";" -Path 'temp.csv' -Header 'Filename', 'Rating', 'TagString'

    $aExifData = foreach ($oExifItem in $aExifTemp) {
        if ($sFileFormat -eq "video") {
            switch ($oExifItem.Rating) {
                "25" { $oExifItem.Rating = "2" }
                "50" { $oExifItem.Rating = "3" }
                "75" { $oExifItem.Rating = "4" }
                "99" { $oExifItem.Rating = "5" }
            }
        }

        if ($oExifItem.TagString.Length -gt 0) { $oExifItem.TagString = [System.String]::Concat("#", $oExifItem.TagString) }
        $oExifItem.TagString = $oExifItem.TagString.Replace(" ","#")

        if (($oExifItem.Rating -ne "0") -and ($oExifItem.Rating -ne "")) { 
            if ($oExifItem.TagString.Length -gt 0) { $oExifItem.TagString += [System.String]::Concat(",#", $oExifItem.Rating) }
            else { $oExifItem.TagString += [System.String]::Concat("#", $oExifItem.Rating) }
        }
            
        New-Object -TypeName PSObject -Property @{
            Name = $oExifItem.Filename
            Tags = $oExifItem.TagString.Split(",")
        }
    }

    foreach ($oChildItem in $aFiles) {
        foreach ($oExifItem in $aExifData) {
            if ($oExifItem.Name -eq $oChildItem.Name) { 
                $bChangesMade = $false

                if ($oExifItem.Tags.Count -gt 1) {
                    foreach ($sTag in $oExifItem.Tags) {
                        if (-not $oChildItem.Tags.Contains($sTag)) { 
                            if ("#1#2#3#4#5".Contains($sTag)) {
                                if ($oChildItem.Tags.Contains("#1") -or $oChildItem.Tags.Contains("#2") -or $oChildItem.Tags.Contains("#3") -or $oChildItem.Tags.Contains("#4") -or $oChildItem.Tags.Contains("#5")) { }
                                else {
                                    $oChildItem.Tags.Add($sTag)
                                    $bChangesMade = $true
                                }
                            } else {
                                $oChildItem.Tags.Add($sTag)
                                $bChangesMade = $true
                            }
                        }
                    }
                }

                $oChildItem.Tags.Sort()

                if ($bChangesMade) {
                    $sSourceFile = $oChildItem.Name
                    $sTargetFile = fGetBaseName($oChildItem.Name)
                    $sTargetFile = [System.String]::Concat($sTargetFile, " ")

                    foreach ($sTag in $oChildItem.Tags) { $sTargetFile += $sTag }
                    $sTargetFile = [System.String]::Concat($sTargetFile, $oChildItem.Extension)

                    Write-Output [System.String]::Concat($sSourceFile, " -> ", $sTargetFile)

                    if (-not $nowrite) { 
                        Move-Item -Path $sSourceFile -Destination $sTargetFile 
                        $iFilesProcessed++	
                    }
                }
            }
        }
    }

    Remove-Item -Path 'temp.csv' -ErrorAction SilentlyContinue
    if (-not $quiet) { Write-Host $iFilesProcessed files renamed -ForegroundColor Cyan }

    if ($clearexif -and (-not $nowrite)) {
        if (-not $quiet) { Write-Host Deleting all EXIF data... -ForegroundColor Cyan }
        & exiftool $filespec -all= -overwrite_original_in_place
    }
    exit	
}

# Help banner strings
if (-not $quiet) {
    Write-Host "NAME"
    Write-Host "    vidtools - Read and write meta information in file names using hash tags"
    Write-Host ""
    Write-Host "SYNTAX"
    Write-Host "    vidtools.ps1 filespec COMMANDS OPTIONS"
    Write-Host ""
    Write-Host "FILESPEC"
    Write-Host "    Specifies a list of files to work on.  Defaults to *.mp4"
    Write-Host ''
    Write-Host 'COMMANDS'
    Write-Host '    [-l][-list]                    List all files matching filespec'
    Write-Host '    [-t][-toss] dest               Move all matching files to dest.'
    Write-Host '    [-replace] text1 -with text2   Replace text1 with text2 in all file names'
    Write-Host '    [-replace] textfile.csv        Read from a file containing comma-delimited pairs of strings.  What to search for and what to replace it with.' 
    Write-Host '    [-add][-addtags] "#tag1#tag2"  Add one or more tags to matching files'
    Write-Host '    [-del][-deltags] "#tag1#tag2"  Delete one or more tags from matching files'
    Write-Host '    [-tagcloud]                    Output a list of all unique tags in all matching files'
    Write-Host '    [-rewrite ]                    Rewrite all filenames into a more standardized format'
	Write-Host '    [-bt][-bulktag] textfile.csv   Bulk tag files based on input from textfile.csv'
    Write-Host '    [-i][-indexfolder] foldername  Bulk tag files based on the contents of an index folder'
    Write-Host '    [-tossindex] foldername        Bulk toss files into a set of folders'
    Write-Host '    [-tagsfromfile] file.mp4       For all the files in filespec, add the tags from file.mp4'
    Write-Host '    [-tagsfromexif]                In the current folder, import EXIF data from the filespec into tags'
    Write-Host ''
    Write-Host 'OPTIONS'
    Write-Host '    [-o][-output] nbqdet           Choose file details to output'
    Write-Host '    [-separator] string            Separate output values by the contents of string.  Defaults to comma'
    Write-Host "    [-q][-quiet]                   Suppress all non-essential output"
	Write-Host '    [-nowrite]                     Don''t actually write to disk, just display the intended changes'
    Write-Host "    [-ou][-onlyuntagged]           Process only files with no valid tags"
    Write-Host "    [-ot][-onlytagged]             Process only files with one or more tag"
    Write-Host '    [-all] "#tag1#tag2"            Process files that have all the listed tags'    
    Write-Host '    [-any] "#tag1#tag2"            Process files that have any of the listed tags'
    Write-Host '    [-none] "#tag1#tag2"           Process files that have none of the listed tags'
    Write-Host '    [-notin] "#tag1#tag2"          Process files that have tags not in the supplied list'
    Write-Host '    [-quote] string                Surround fields with the quote character specified.  Default is none'
    Write-Host '    [-clearexif]                   Works with -tagsfromexif.  Purges EXIF data from files after importing'
    Write-Host '    [-browse][-b]                  Works with -list.  Opens the results in XNView'
    Write-Host ''
    Write-Host 'TAGS'
    Write-Host '    Tags are always expressed as an unbroken hash-delimited string'
    Write-Host '    Any command that accepts a list of tags as input will also accept a file as input.  Each line of the file'
    Write-Host '    a single tag (including hash character).  '
    Write-Host ''
    Write-Host 'EXAMPLES'
    Write-Host '    vt.ps1 -l                      List *.mp4'
    Write-Host '    vt.ps1 *.avi -l -ot            List all avi files that have one or more tag'
    Write-Host '    vt.ps1 -q -output nt           List all mp4 files in CSV format, displaying their name and tags'
    Write-Host '    vt.ps1 -all "#short#hawaii"'
    Write-Host '                                   List all mp4 files that have the tags #short and #hawaii in their name'
    Write-Host '    vt.ps1 *.jpg -l -all "#short#hawaii" -none "#karate"'
    Write-Host '                                   List all jpg files that have the tags #short and #hawaii in their name but do not have the tag #karate'
    Write-Host '    vt.ps1 -quiet -separator "" -output pne'
    Write-Host '                                   List all mp4 files in CSV format, showing their path, name, and extension with no separator'
    Write-Host '    vt.ps1 *.jpg -tagcloud > alltags.csv'
    Write-Host '                                   Export a list of all tags used in all jpg files in the current folder'
    Write-Host '    vt.ps1 -l -notin alltags.csv   List all files that contain a tag that isn''t in the alltags.csv list'
}