#-------------------------------------------------------------------
#  Vidtools
#  Manage hashtags inside filenames
#-------------------------------------------------------------------


# Declare my allowable command-line arguments.  Most have a long version and a short version
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
$cCurrentpath = ( Resolve-Path ".\" ).Path + "\"
$cTagDelimiter = "#"
$cAllowedHashChars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Include functions and parse environment variables
$sTempFolder = ( Get-ChildItem -Path Env:\TEMP ).Value

#-------------------------------------------------------------------
# Accept a string that is a filename and return only the portion before the tags begin, trimmed of spaces
#-------------------------------------------------------------------
function fGetBaseName( $sI ) {
    # If the string has any "\" in it, trim all until the last one
    if( $sI.Contains( "\" ) ) { $sI = $sI.SubString( $sI.LastIndexOf( "\" ) + 1, $sI.Length - $sI.LastIndexOf( "\" ) - 2 ) }
    
    # If the string has a . in it, strip everything after the last dot, including the dot.
    if( $sI.Contains( "." ) ) { $sI = $sI.SubString( 0, $sI.LastIndexOf( "." ) ) }

    # If the string contains any # characters strip at the first one
    if( $sI.Contains( $cTagDelimiter ) ) { $sI = $sI.SubString( 0, $sI.IndexOf( $cTagDelimiter ) ) }

    return $sI.TrimEnd( " " )
} #function 

#-------------------------------------------------------------------
# Accept a string and return a parsed array of Tags.  Duplicates are ignored and the returned array is sorted.
#-------------------------------------------------------------------
function fTagsFromString( $sI ) {
    $aTags = @()
    # If the string has any "\" in it, trim all until the last one
    if( $sI.Contains( "\" ) ) { $sI = $sI.SubString( $sI.LastIndexOf( "\" ) + 1, $sI.Length - $sI.LastIndexOf( "\" ) - 2 ) }
    
    # If the string has a . in it, strip everything after the last dot, including the dot.
    if( $sI.Contains( "." ) ) { $sI = $sI.SubString( 0, $sI.LastIndexOf( "." ) ) }

    # If the parameter contains no hashtags, then quit altogether, otherwise trim the string until the first Tag Delimiter
    if( $sI.IndexOf( $cTagDelimiter ) -eq -1 ) { return $aTags } else { $sI = $sI.Substring( $sI.IndexOf( $cTagDelimiter ), $sI.Length - $sI.IndexOf( $cTagDelimiter ) ) } 
                                                                                                                                                                                
    # Use the split method to break on the tag delimiter, then walk through each item and cleanup lint
    $aTempTags = $sI.Split( $cTagDelimiter )
    foreach( $sTempTag in $aTempTags ) {
        # Properly format it as a tag before checking it for validity
        $sTempTag = $cTagDelimiter + $sTempTag.Trim( " " )

        # Add this to the array of tags:
        # IF it's got a non-zero length
        # AND it starts with an alphanumeric character
        # AND it's not a duplicate
        # DEBUG - This algorithm allows non-alphanumeric characters in a tag as long as they're not the first character or a space
        if( ( $sTempTag.Length -gt 1 ) -and
            ( $cAllowedHashChars.Contains( $sTempTag.SubString( 1, 1 ) ) ) -and
            ( -not $aTags.Contains( $sTempTag ) ) ) { 
                $aTags += $sTempTag 
            
        }
    } #foreach

    [array]::sort( $aTags )

    return $aTags
}

#-------------------------------------------------------------------
# Main executable body begin
#-------------------------------------------------------------------

# Before going any further, do some work to simplify command-line switches that have two names
if( $ot ) { $onlytagged = $ot }
if( $ou ) { $onlyuntagged = $ou }
if( $q ) { $quiet = $q }
if( $l ) { $list = $l }
if( $f -ne "*" ) { $filespec = $f }
if( $o -ne "n" ) { $output = $o }
if( $t -ne "" ) { $toss = $t }
if( $add -ne "" ) { $addtags = $add }
if( $del -ne "" ) { $deltags = $del }
if( $bt -ne "" ) { $bulktag = $bt }
if( $b ) { $browse = $b }
if( $i -ne "" ) { $indexfolder = $i }

# Display a banner
if( -not $quiet ) {
    Write-Host ------------------------------------------
    Write-Host " "VIDTOOLS - Work with video metadata
    Write-Host ------------------------------------------
} #if

# Error check some mutually exclusive command-line switches
if( $onlytagged -and $onlyuntagged ) {
    if( -not $quiet ) { Write-Host "ERROR: Command-line switches -onlyuntagged and -onlytagged are mutually exclusive" -ForegroundColor Red }
    exit
} #if
if( ( $onlytagged -or $onlyuntagged ) -and $all ) {
    if( -not $quiet ) { Write-Host "ERROR: Command-line switches -onlyuntagged or -onlytagged cannot be used in conjunction with -all" -ForegroundColor Red }
    exit
} #if
if( ( $onlytagged -or $onlyuntagged ) -and $none ) {
    if( -not $quiet ) { Write-Host "ERROR: Command-line switches -onlyuntagged or -onlytagged cannot be used in conjunction with -none" -ForegroundColor Red }
    exit
} #if
if( ( $onlytagged -or $onlyuntagged ) -and $any ) {
    if( -not $quiet ) { Write-Host "ERROR: Command-line switches -onlyuntagged or -onlytagged cannot be used in conjunction with -any" -ForegroundColor Red }
    exit
} #if
if( ( $onlytagged -or $onlyuntagged ) -and $notin ) {
    if( -not $quiet ) { Write-Host "ERROR: Command-line switches -onlyuntagged or -onlytagged cannot be used in conjunction with -notin" -ForegroundColor Red }
    exit
} #if

# Check if -replace is being used, and if so, whether it's paired with -with or points to a file
if( $replace ) {
    if( Test-Path -Path $replace -PathType Leaf ) {
        $sReplaceMode = "file"
        if( $with -and ( -not $quiet ) ) { 
            Write-Host "ERROR: Cannot use the switch -with if -replace points to an input file" -ForegroundColor Red 
            exit
        } #if
    } #if
    else {
        $sReplaceMode = "string"
        # The parameter passed to -replace wasn't a valid file, so make sure they paired it with -with
        if( -not $with ) {
            if( -not $quiet ) { 
                Write-Host "ERROR: The command -replace must be paired with the switch -with" -ForegroundColor Red }
                exit
        } #if
    } #else
} #if

# Start by parsing any tags from -all if any
if( $all ) {
    if( Test-Path -Path $all -PathType Leaf ) {
        # User specified a valid file, read $aAndTags from a CSV
        $aAndTags = Get-Content -Path $all
    } #if
    else { $aAndTags = @( fTagsFromString( $all ) ) }
} #if
# Followed by any tags from -none if any
if( $none ) {
    if( Test-Path -Path $none -PathType Leaf ) {
        # User specified a valid file, read $aNotTags from a CSV
        $aNotTags = Get-Content -Path $none
    } #if
    else { $aNotTags = @( fTagsFromString( $none ) ) }
} #if
# Followed by any tags from -any if any
if( $any ) {
    if( Test-Path -Path $any -PathType Leaf ) {
        # User specified a valid file, read $aOrTags from a CSV
        $aOrTags = Get-Content -Path $any
    } #if
    else { $aOrTags = @( fTagsFromString( $any ) ) }
} #if
# Followed by any tags from -notin if any
if( $notin ) {
    if( Test-Path -Path $notin -PathType Leaf ) {
        # User specified a valid file, read $aOrTags from a CSV
        $aNotinTags = Get-Content -Path $notin
    } #if
    else { $aNotinTags = @( fTagsFromString( $notin ) ) }
} #if

# Start by creating an array of files that match the filespec
# This will be done regardless of whether the user has specified an action or not

# Populate the array of Files
$aChildItems = @(Get-ChildItem $filespec -File ) 

# Create an array of objects that match the filespec
$aFiles = ForEach( $oChildItem in $aChildItems ) {
    # Parse out any tags from this filename.  Only pass the function the filename up to but not including extension
    $aTempTags = @( fTagsFromString( $oChildItem.Name ) )

    #-------------------------------------------------------------------
    # Evaluate a bunch of criteria based on comand-line switches
    # ------------------------------------------------------------------
    # Barring criteria matches, include every file in filespec in the list of objects
    $bQualifies = $true

    # Set a flag if this object passes criteria
    # User specified -onlyuntagged and there are tags
    if( $onlyuntagged -and ( $aTempTags.Count -gt 0 ) ) { $bQualifies = $false } #if

    # User specified -onlytagged but there are no tags
    if( $onlytagged -and ( $aTempTags.Count -eq 0 ) ) { $bQualifies = $false } #if
    
    # User specified -all
    if( $aAndTags.Count -gt 0 ) { 
        # Loop through every tag in $aAndTags and see if it's contained in $aTempTags.  If yes, this one qualifies

        # Only search for matching tags if there's any tags at all
        if( $aTempTags.Count -gt 0 ) {
            foreach( $sTempTag in $aAndTags ) { 
                # If at any iteration in this loop we find the -all tag isn't found, the entire record doesn't match
                if( -not $aTempTags.Contains( $sTempTag ) ) { $bQualifies = $false }
            } #foreach
                
        } #if
        else { $bQualifies = $false } # If user specified -withtags and this file has no tags, then obviously it fails criteria

    } #if

    # User specified -none
    if( $aNotTags.Count -gt 0 ) {
        # Loop through every tag in $aNotTags and see if it's contained in $aTempTags.  If yes, this one is excluded
        
        # Only search for matching tags if there's any tags at all
        if( $aTempTags.Count -gt 0 ) {
            foreach( $sTempTag in $aNotTags ) { 
                # If at any iteration in this loop we find the -none tag is found, the entire record doesn't match
                if( $aTempTags.Contains( $sTempTag ) ) { $bQualifies = $false }
            } #foreach
        } #if

    } #if

    # User specified -any
    if( $aOrTags.Count -gt 0 ) {
        # Loop through every tag in $aOrTags and see if it's contained in $aTempTags.  If there's a match in any iteration, this one qualifies
        $bWasFound = $false

        # Only search for matching tags if there's any tags at all
        if( $aTempTags.Count -gt 0 ) {
            foreach( $sTempTag in $aOrTags ) {
                if( $aTempTags.Contains( $sTempTag ) ) { $bWasFound = $true }
            } #foreach
        } #if
        if( -not $bWasFound ) { 
            $bQualifies = $false 
        } #if
    } #if
    
    # User specified -notin
    if( $aNotinTags.Count -gt 0 ) {
        $bQualifies = $false
        $bWasFound = $true

        # Only search for matching tags if there's any tags at all
        if( $aTempTags.Count -gt 0 ) {
                # Loop through every tag this file has.  If they all are in $aNotInTags this doesn't qualify
                foreach( $sTempTag in $aTempTags ) {
                    if( -not $aNotinTags.Contains( $sTempTag ) ) { $bWasFound = $false }
                } #foreach
                if( -not $bWasFound ) { 
                    $bQualifies = $true
                } #if
        } #if

    } #if

    # Instantiate a new object for this file if it qualifies
    if( $bQualifies ) {
        New-Object -TypeName PSObject -Property @{
            Name = $oChildItem.Name
            Extension = $oChildItem.Extension
            Basename = $oChildItem.Name.Remove( $oChildItem.Name.IndexOf( $oChildItem.Extension ), $oChildItem.Extension.Length )
            Qualified = [System.String]::Concat( $oChildItem.Directory, "\", $oChildItem.Name )
            Directory = $oChildItem.Directory
            Tags = $aTempTags
        } #New-Object
    } #if

} #ForEach

# If nothing matches there is nothing to do.  Just exit with a warning
if( $aFiles.Count -eq 0 ) {
    if( -not $quiet ) { Write-Host "No matching files found" -ForegroundColor Cyan }
    exit
} #if

#-------------------------------------------------------------------
# Process the -list command
#-------------------------------------------------------------------
if ( $list ) {
    $bOutputCodeError = $false

    # Check if the -browse switch was specified
    if( $browse ) { 
        $sTempFile = $sTempFolder + "\vt-temp.txt"
        if( -not $quiet ) { Write-Host Sending output to $sTempFile file... -ForegroundColor Cyan }
        $quiet=$true

        Write-Output "" | Out-File -FilePath $sTempFile -NoNewline

        # Force output in fully-qualified format
        $output="q"
    } #if

    foreach( $oChildItem in $aFiles ) {

        # Loop through the $output string and based on what it is, output that element
        for( $iCounter=0; $iCounter -lt $output.Length; $iCounter++ ) {
            $bValid = $false
            $sOutputString = ""

            switch ( $output.Substring( $iCounter, 1 ) ) {
               
                "n" {
                    $sOutputString = [System.String]::Concat( $sOutputString, $quote, $oChildItem.Name, $quote )
                    $bValid = $true
                    
                }
                "b" {
                    $sOutputString = [System.String]::Concat( $sOutputString, $quote, $oChildItem.Basename, $quote )
                    $bValid = $true
                }
                "q" {
                    $sOutputString = [System.String]::Concat( $sOutputString, $quote, $oChildItem.Qualified, $quote )
                    $bValid = $true
                }
                "d" {
                    $sOutputString = [System.String]::Concat( $sOutputString, $quote, $oChildItem.Directory, $quote )
                    $bValid = $true
                }
                "e" {
                    $sOutputString = [System.String]::Concat( $sOutputString, $quote, $oChildItem.Extension, $quote )
                    $bValid = $true
                }
                "t" {
                    foreach( $sTag in $oChildItem.Tags ) {
                        $sOutputString = [System.String]::Concat( $sOutputString, $sTag )
                    } #foreach
                    $bValid = $true
                }
                default {
                    # This is not a valid code to use with -output
                    $bOutputCodeError = $true
                }

            } #switch

            # Only output a comma if we've just processed a valid output format code, and we're not the last element
            if( ( $iCounter -lt ( $output.Length - 1 ) ) -and ( $bValid -eq $true ) ) { Write-Host $separator -Separator "" -NoNewline }

        } #for
         
        if( $browse ) {
            Write-Output $sOutputString | Out-File -FilePath $sTempFile -Append
        } #if
        else { Write-Output $sOutputString }

    } #ForEach

    # Generate a warning if any invalid output codes were encountered
    if( ( $bOutputCodeError ) -and ( -not $quiet ) ) { Write-Host "One or more invalid output codes specified in $output" -ForegroundColor Cyan }
 
    # Output the number of matching records if it's in verbose mode
    if( -not $quiet ) { Write-Host $aFiles.Count files -ForegroundColor Cyan }

    # Launch XNView if -browse is specified
    if( $browse ) { & "C:\Program Files\XnViewMP\xnviewmp.exe" -filelist $sTempFile }

    # To avoid shitty conflicting command-lines, just quit now
    exit
} #if

#-------------------------------------------------------------------
# Process the -toss command
#-------------------------------------------------------------------
if( $toss ) {
    $iFilesProcessed = 0

    # Add a backslash to $toss if there isn't already one
    if( $toss.Substring( $toss.Length - 1, 1 ) -ne "\" ) { $toss += "\" }

    # Check that the target folder exists
    if( Test-Path -Path $toss -PathType Container ) {

        # Loop through each item and try to move it into target folder
        foreach( $oChildItem in $aFiles ) {
            $sSourceFile = $oChildItem.Qualified
            $sTargetFile = $toss + $oChildItem.Name

            # Check if the target filename exists
            if( -not ( Test-Path -Path $sTargetFile -PathType Leaf ) ) {

                $sOutputString = [System.String]::Concat( $oChildItem.Name, " -> ", $toss  )
                Write-Output $sOutputString

                if( -not $nowrite ) { 
                    Move-Item -Path $sSourceFile -Destination $sTargetFile
                    $iFilesProcessed++ 
                } #if

            } #if
            else {
                
                if( -not $quiet) { Write-Host "Not moving $oChildItem.Name as it already exists in target" -ForegroundColor Cyan }

            } #else
             
        } #foreach

    } #if
    else {
        # Target folder didn't exist, quitting
        if( -not $quiet ) { Write-Host ERROR: Folder $toss does not exist -ForegroundColor Red }
        exit
    } #else

    # Output the number of files processed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }

    # To avoid shitty conflicting command-lines, just quit now
    exit
} #if

#-------------------------------------------------------------------
# Process the -replace command
#-------------------------------------------------------------------
if( $replace ) {
      $iFilesProcessed = 0

    # If we're doing a file-based substitution, import the specified CSV file
    if( $sReplaceMode -eq "file" ) { $aSubstitutions = Import-Csv -Path $replace -Header 'String1', 'String2' }

    # Loop through every file that has passed criteria and act on it
    foreach( $oChildItem in $aFiles ) {
        if( $sReplaceMode -eq "string" ) {
            $sOriginalShortName = $oChildItem.Name
            $sNewShortName = $oChildItem.Name.Replace( $replace, $with )

            # Do a straight text substitution in the file name
            if( $oChildItem.Name -ne $sNewShortName ) {
                # The replace string was found

                $sSourceFile = $oChildItem.Qualified
                $sTargetFile = [System.String]::Concat( $oChildItem.Directory, "\", $sNewShortName )

                # Check if the target filename exists
                if( -not ( Test-Path -Path $sTargetFile -PathType Leaf ) ) {

                    $sOutputString = [System.String]::Concat( $sSourceFile, " -> ", $sTargetFile  )
                    Write-Output $sOutputString

                    if( -not $nowrite ) { 
                        Rename-Item -Path $sSourceFile -NewName $sTargetFile
                        $iFilesProcessed++
                    } #if

                } #if
                else {
                    
                    if( -not $quiet) { Write-Host WARNING: File $sNewShortName already exists -ForegroundColor Cyan }

                } #else

            } #if
                
        } #if
        else {

            # We're in file-based replace mode
            foreach( $aSubstitution in $aSubstitutions ) {
                if( $oChildItem.Name.Contains( $aSubstitution.String1 ) ) {
                    # We've found a hit
                    $sOriginalShortName = $oChildItem.Name
                    $sNewShortName = $oChildItem.Name.Replace( $aSubstitution.String1, $aSubstitution.String2 )

                    $sSourceFile = $oChildItem.Qualified
                    $sTargetFile = [System.String]::Concat( $oChildItem.Directory, "\", $sNewShortName )

                     # Check if the target filename exists
                    if( -not ( Test-Path -Path $sTargetFile -PathType Leaf ) ) {

                        $sOutputString = [System.String]::Concat( $sSourceFile, " -> ", $sTargetFile  )
                        Write-Output $sOutputString

                        if( -not $nowrite ) { 
                            Rename-Item -Path $sSourceFile -NewName $sTargetFile
                            $iFilesProcessed++
                        } #if

                    } #if
                    else {
                    
                        if( -not $quiet) { Write-Host WARNING: File $sNewShortName already exists -ForegroundColor Cyan } # FIXIE!!!

                    } #else

                } #if
            } # foreach

        } #if
    } #foreach

    # Output the number of files processed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }

    # To avoid shitty conflicting command-lines, just quit now
    exit
} #if

#-------------------------------------------------------------------
# Process the -tagcloud command
#-------------------------------------------------------------------
if( $tagcloud ) {
    $aTags = @()
    $iTagsProcessed = 0

    # First loop through every file
    foreach( $oChildItem in $aFiles ) {

        # Then loop through each tag in every file
        foreach( $sTempTag in $oChildItem.Tags ) {

            if( -not $aTags.Contains( $sTempTag ) ) {
                $aTags += $sTempTag
                $iTagsProcessed++
            } #if

        } #foreach

    } #foreach

    [array]::sort( $aTags )

    # Now write them all to view
    foreach( $sTempTag in $aTags ) { Write-Output $sTempTag }

    # Output the number of tags processed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iTagsProcessed tags -ForegroundColor Cyan }

    # To avoid shitty conflicting command-lines, just quit now
    exit
} #if

#-------------------------------------------------------------------
# Process the -addtags command
#-------------------------------------------------------------------
if( $addtags ) {
	$iFilesProcessed = 0

	# Start by parsing $addtags into an array
	if( Test-Path -Path $addtags -PathType Leaf ) {
		# User specified a valid file, read $aAddTags from a CSV
		$aAddTags = Get-Content -Path $addtags
		} #if
    else { $aAddTags = @( fTagsFromString( $addtags ) ) }
	
	# Error out if no tags were parsed
	if( $aAddTags.Count -le 0 ) {
		if( -not $quiet ) { 
			Write-Host 'ERROR: Switch -addtags was used but no valid tags were supplied' -ForegroundColor Red
			exit 
		} #if
	}
	
	# Loop through every file in the files lis
	foreach( $oChildItem in $aFiles ) {
		$bTempFlag = $false
	
		# Now loop through each tag we need to add
		foreach( $sTempTag in $aAddTags ) {
			# See if this tag is not part of the existing tags attached to this file
			if( -not $oChildItem.Tags.Contains( $sTempTag ) ) {
				
                # Wait.  First check if this is a rating. If it is and this file already has a rating, just replace it in place and set the change flag
                if( "#1#2#3#4#5".Contains( $sTempTag ) ) {
                    
                    # Loop through every tag in $oChildItem, and if it's a rating do a simple replace and set the change flag
                    for( $iCounter = 0; $iCounter -le ( $oChildItem.Tags.Count - 1 ); $iCounter++ ) {
                    
                        if( "#1#2#3#4#5".Contains( $oChildItem.Tags[ $iCounter ] ) ) { 
                            $oChildItem.Tags[ $iCounter ] = $sTempTag 
                            $bTempFlag = $true
                        } #if

                    } #for
                    
                    # We're adding a rating but no rating was found in the source file, so add it now
                    if( -not $bTempFlag ) { 
                        $oChildItem.Tags += $sTempTag
                        $bTempFlag = $true
                    } #if
                    
                } #if
                else {
                    # Tag doesn't exist, add it in
				    $oChildItem.Tags += $sTempTag
				    $bTempFlag = $true
                } #else
			} #if
			
		} #foreach
		
		if( $bTempFlag ) {
			# If any changes were made we need to write them now
            $sTargetFile = fGetBaseName( $oChildItem.Name )
			$sSourceFile = [System.String]::Concat( $oChildItem.Directory, "\", $oChildItem.Name )
			$sTargetFile = [System.String]::Concat( $oChildItem.Directory, "\", $sTargetFile, " " )

            # Sort the tags then append them to the target filename, followed by an extension
            [array]::sort( $oChildItem.Tags )
            foreach( $sTempTag in $oChildItem.Tags ) { $sTargetFile += $sTempTag }
            $sTargetFile = [System.String]::Concat( $sTargetFile, $oChildItem.Extension )
			
			# Don't write the destination file if it already exists
			if( -not ( Test-Path -Path $sTargetFile -PathType Leaf ) ) {

				if( -not $nowrite ) { 
                    Rename-Item -Path $sSourceFile -NewName $sTargetFile
				    $iFilesProcessed++
                } #if
                
                $sOutputString = [System.String]::Concat( $sSourceFile, " -> ", $sTargetFile  )
                Write-Output $sOutputString

                # 
			} #if
			else {
				if( -not $quiet) { Write-Host WARNING: File $sTargetFile already exists -ForegroundColor Cyan }
			} #else
			
		} #if
		
	} #foreach

    # Output the number of files processed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }

    # To avoid shitty conflicting command-lines, just quit now
    exit
} #if

#-------------------------------------------------------------------
# Process the -deltags command
#-------------------------------------------------------------------
if( $deltags ) {
	$iFilesProcessed = 0
	
	# Start by parsing $deltags
	if( Test-Path -Path $deltags -PathType Leaf ) {
		# User specified a valid file, read $aDelTags from a CSV
		$aDelTags = Get-Content -Path $deltags
		} #if
    else { $aDelTags = @( fTagsFromString( $deltags ) ) }
	
	# Error out if no tags were parsed
	if( $aDelTags.Count -le 0 ) {
		if( -not $quiet ) { 
			Write-Host 'ERROR: Switch -deltags was used but no valid tags were supplied' -ForegroundColor Red
			exit 
		} #if
	} #if
	
	# Loop through all the files, delete a tag if it exists
	foreach( $oChildItem in $aFiles ) {
		$sSourcePath = [System.String]::Concat( $oChildItem.Directory, "\" )
		$sSourceFile = $oChildItem.Name
		$sTargetFile = $oChildItem.Name
		$bTempFlag = $false
	
		# Now loop through each tag we need to delete
		foreach( $sTempTag in $aDelTags ) {
			if( ( $oChildItem.Tags.Count -gt 0 ) -and ( $oChildItem.Tags.Contains( $sTempTag ) ) ) {
				# We've found a matching tag
				
				# Loop as many times as it takes to delete all instances of the tag fromt he text string.
				while( $sTargetFile.IndexOf( $sTempTag ) -ge 0 ) {
					$bTempFlag = $true
					# We're not making any changes to the array of tags, only to the filenam string.  This is so that we're the least destructive to the filename as possible.
					$sTargetFile = $sTargetFile.Remove( $sTargetFile.IndexOf( $sTempTag ), $sTempTag.Length )
				}
				
			} #if
		} #foreach
		
		if( $bTempFlag ) {
			# If any changes were made we need to write them now
			$sSourceFile = $sSourcePath + $sSourceFile
			$sTargetFile = $sSourcePath + $sTargetFile
			
			# Don't write the destination file if it already exists
			if( -not ( Test-Path -Path $sTargetFile -PathType Leaf ) ) {
                
                if( -not $nowrite ) { 
				    Rename-Item -Path $sSourceFile -NewName $sTargetFile
				    $iFilesProcessed++
                } #if

                $sOutputString = [System.String]::Concat( $sSourceFile, " -> ", $sTargetFile  )
                Write-Output $sOutputString

			} #if
			else {
				if( -not $quiet) { Write-Host WARNING: File $sTargetFile already exists -ForegroundColor Cyan }
			} #else
			
		} #if
		
	} #foreach
	
    # Output the number of files processed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }

    # To avoid shitty conflicting command-lines, just quit now
    exit
} #if

#-------------------------------------------------------------------
# Process the -rewrite command
#-------------------------------------------------------------------
if( $rewrite ) {
	$iFilesProcessed = 0
	
	# Loop through every file in the list
	foreach( $oChildItem in $aFiles ) {
		$sSourcePath = [System.String]::Concat( $oChildItem.Directory, "\" )
		$sSourceFile = $oChildItem.Name
		$sTargetFile = fGetBaseName( $oChildItem.Name )
	
		# Only append tags if this file has them
		if( $oChildItem.Tags.Count -gt 0 ) {
			# Add a single space
			$sTargetFile = $sTargetFile + " "
			
			foreach( $sTempTag in $oChildItem.Tags ) {
				$sTargetFile = $sTargetFile + $sTempTag
			} #foreach
			
			
		} #if

        $sTargetFile = $sTargetFile + $oChildItem.extension
		
		# If the file name has been changed we need to write it
		if( $sSourceFile -ne $sTargetFile ) {
			$sSourceFile = $sSourcePath + $sSourceFile
			$sTargetFile = $sSourcePath + $sTargetFile		
			
			# Don't write the destination file if it already exists
			if( -not ( Test-Path -Path $sTargetFile -PathType Leaf ) ) {

                if( -not $nowrite ) { 
				    Rename-Item -Path $sSourceFile -NewName $sTargetFile
				    $iFilesProcessed++
                } #if

                $sOutputString = [System.String]::Concat( $sSourceFile, " -> ", $sTargetFile  )
                Write-Output $sOutputString

			} #if
			else {
				if( -not $quiet) { Write-Host WARNING: File $sTargetFile already exists -ForegroundColor Cyan }
			} #else			
			
		} #if
		
	} #foreach
	
	# Output the number of files renamed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }

    # To avoid shitty conflicting command-lines, just quit now
    exit
} #if

#-------------------------------------------------------------------
# Process the -bulktag command
#-------------------------------------------------------------------
if( $bulktag ) {
	# First confirm the bulk tag file exists
	if( Test-Path -Path $bulktag -PathType Leaf ) {
        $iFilesProcessed = 0

		# Read the contents into an array named $aBulkTags
		$aBulkTags = Import-Csv -Path $bulktag -Header 'SearchString', 'Tags'
		
		# Let's make things case insensitive.  Step 1 is to convert all search strings to lowercase.  Then we convert all filenames to lowercase.
		for( $iCounter = 0; $iCounter -lt $aBulkTags.Count; $iCounter++ ) { $aBulkTags[ $iCounter ].SearchString = $aBulkTags[ $iCounter ].SearchString.ToLower() } #for
		
		# Loop through every file and make any substitutions necessary
		foreach( $oChildItem in $aFiles ) {
			
			$bChangesMade = $false
			$sSourcePath = [System.String]::Concat( $oChildItem.Directory, "\" )
			$sSourceFile = $oChildItem.Name
			$sTargetFile = $oChildItem.BaseName
			
			# We only want to work with the base filename, stripped of tags and extension.  Otherwise those elements will trigger false hits
			$sBaseName = $oChildItem.Name
			$sBaseName = $sBaseName.ToLower()
			
			# Now loop through every search string and see if it's in $sBaseName
			foreach( $oBulkTag in $aBulkTags ) {

				if( $sBaseName.Contains( $oBulkTag.SearchString ) ) {
					# We have a search string hit, that doesn't yet mean we're renaming a file
					
					# Parse the tags in $oBulkTag.  This doesn't seem efficient to do once for every hit
					$aTempTags = @( fTagsFromString( $oBulkTag.Tags ) )
					
					# Only proceed if the CSV file actually contained some valid tags
					if( $aTempTags.Count -gt 0 ) {
                        $sTargetFile += " "
						# Loop through all the tags in $aTempTags to see if they need to be inserted
						foreach( $sTempTag in $aTempTags ) {
							
							if( $oChildItem.Tags.Count -eq 0 ) {
                                # A match was made, and the file has no tags at all.  Time to add it.
								$bChangesMade = $true
								$sTargetFile = $sTargetFile + $sTempTag								
							} #if
                            else {
                                if(-not $oChildItem.Tags.Contains( $sTempTag ) ) {
                                    # A match was made, and the file doesn't already have this tag.  Time to add it.

                                    # Do nothing if the tag is a rating and $sTargetFile already contains a rating
                                    if( "#1#2#3#4#5".Contains( $sTempTag ) -and ( $sTargetFile.Contains( "#1" ) -or $sTargetFile.Contains( "#2" ) -or $sTargetFile.Contains( "#3" ) -or $sTargetFile.Contains( "#4" ) -or $sTargetFile.Contains( "#5" ) ) ) {  }
								    else {
                                        $bChangesMade = $true
								        $sTargetFile = $sTargetFile + $sTempTag	
                                    } #else

                                } #if
                            } #else
							
						} #foreach
					} #if
					
				} #if
			} #foreach
			
			# We've gone through this entire file, time to see if changes need to be written
			if( $bChangesMade ) {
				$sSourceFile = $sSourcePath + $sSourceFile
				$sTargetFile = $sSourcePath + $sTargetFile + $oChildItem.Extension			
		
                $sOutputString = [System.String]::Concat( $sSourceFile, " -> ", $sTargetFile  )
                Write-Output $sOutputString
				 
				if( -not $nowrite ) { 
                    Rename-Item -Path $sSourceFile -NewName $sTargetFile 
                    $iFilesProcessed++	
                } #if
				
			} #if
			
		} #foreach
		
		# Output the number of files renamed if it's in verbose mode
		if( -not $quiet ) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }
		
	} #if
	else { 
		if( -not $quiet ) { Write-Host "ERROR: Bulk tag input file $bulktag not found" -ForegroundColor Red }
		exit
	} #else

    # To avoid shitty conflicting command-lines, just quit now
    exit	
	
} #if

#-------------------------------------------------------------------
# Process the -indexfolder command
#-------------------------------------------------------------------
if( $indexfolder ) {
    $iFilesProcessed = 0

    # Validate the index folder
    if ( $indexfolder.Substring( $indexfolder.Length - 1, 1 ) -ne "\" ) { $indexfolder += "\" }
    # Take a shit if the index folder doesn't exist
    if ( -not ( Test-Path -Path $indexfolder -PathType Container ) ) {
        Write-Host "ERROR: Index file $indexfolder does not exist" -ForegroundColor Red
        exit
    } #if

    # Loop through every file in the filespec
    foreach( $oChildItem in $aFiles ) {
        
        # Don't do anything at all if the file has no "-" in it
        if( $oChildItem.Name.Contains( "-" ) ) {
            $sSourcePath = [System.String]::Concat( $oChildItem.Directory, "\" )
            $sSourceFile = [System.String]::Concat( $sSourcePath, $oChildItem.Name )
            $sTargetFile = [System.String]::Concat( $sSourcePath, $oChildItem.BaseName )

            $sFileSpec = $indexfolder + $oChildItem.Name.Substring( 0, $oChildItem.Name.IndexOf( "-" ) ) + " *" + $oChildItem.Extension
            $aFilesinIndex = @( Get-ChildItem $sFileSpec )

            if( $aFilesinIndex.Count -gt 0 ) {
                # A file matched the filespec in index folder

                # Parse out an array of tags from the file we found.  These are the existing tags.
                $sBaseName = $aFilesinIndex[ 0 ].Name.SubString( 0, $aFilesinIndex[ 0 ].Name.Length - $aFilesinIndex[ 0 ].Extension.Length )
                $aTempTags = @( fTagsFromString( $sBaseName ) )

                # Only do something if the matching file in index files has tags of its own
                if( $aTempTags.Count -gt 0 ) {

                    # Loop through all tags and append them to the destination filename
                    foreach( $sTempTag in $aTempTags ) { 
                        
                        # Do nothing if the tag is a rating and $sTargetFile already contains a rating
                        if( "#1#2#3#4#5".Contains( $sTempTag ) -and ( $sTargetFile.Contains( "#1" ) -or $sTargetFile.Contains( "#2" ) -or $sTargetFile.Contains( "#3" ) -or $sTargetFile.Contains( "#4" ) -or $sTargetFile.Contains( "#5" ) ) ) { }
                        # Only append the tag if it doesn't already exist
                        elseif( -not $sTargetFile.Contains( $sTempTag ) ) { $sTargetFile += $sTempTag }

                    } #foreach

                    $sTargetFile += $oChildItem.Extension

                    $sOutputString = [System.String]::Concat( $sSourceFile, " -> ", $sTargetFile  )
                    Write-Output $sOutputString

                    # Now save that shit
				    if( -not $nowrite ) { 
                        Rename-Item -Path $sSourceFile -NewName $sTargetFile 
                        $iFilesProcessed++	
                    } #if

                } #if

            } #if
            else { if( -not $quiet ) { Write-Host 'No matching file in index folder found for' $oChildItem.Name -ForegroundColor Cyan } } # DEBUG delete this
        } #if 

    } #foreach

  	# Output the number of files renamed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iFilesProcessed files changed -ForegroundColor Cyan }

    # To avoid shitty conflicting command-lines, just quit now
    exit	
} #if

#-------------------------------------------------------------------
# Process the -tossindex command
#-------------------------------------------------------------------
if( $tossindex ) {
    $iFilesProcessed = 0

    # Validate the index folder
    if ( $tossindex.Substring( $tossindex.Length - 1, 1 ) -ne "\" ) { $tossindex += "\" }
    # Take a shit if the index folder doesn't exist
    if ( -not ( Test-Path -Path $tossindex -PathType Container ) ) {
        Write-Host "ERROR: Index file $tossindex does not exist" -ForegroundColor Red
        exit
    } #if

    # Loop through every file in the filespec
    foreach( $oChildItem in $aFiles ) {

        # Don't do anything at all if the file has no "-" in it
        if( $oChildItem.Name.Contains( "-" ) ) {
            $sSourceFile = [System.String]::Concat( $oChildItem.Directory, "\", $oChildItem.Name )
            $sTargetFile = $tossindex + $oChildItem.Name.Substring( 0, $oChildItem.Name.IndexOf( "-" ) ) + "\"

            # Don't try to move the file unless the target folder exists
            if( Test-Path -Path $sTargetFile -PathType Container ) {
                $sTargetFile += $oChildItem.Name

                $sOutputString = [System.String]::Concat( $sSourceFile, " -> ", $sTargetFile  )
                Write-Output $sOutputString

                # Now move that shit
				if( -not $nowrite ) { 
                    
                    # Last check.  Don't move it if it exists
                    if( -not ( Test-Path -Path $sTargetFile -PathType Leaf ) ) {
                        Move-Item -Path $sSourceFile -Destination $sTargetFile
                        $iFilesProcessed++
                    } else {
                        Write-Host "WARNING: Source already exists in target" -ForegroundColor Red
                    } # END if( -not ( Test-Path -Path $sTargetFile -PathType Leaf ) )

                } #if

            } #if

        } #if

    } #foreach

  	# Output the number of files renamed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iFilesProcessed files moved -ForegroundColor Cyan }

    # To avoid shitty conflicting command-lines, just quit now
    exit	
} #if

#-------------------------------------------------------------------
# Process the -tagsfromfile command
#-------------------------------------------------------------------
if( $tagsfromfile ) {
    $iFilesProcessed = 0

    # Make sure the source file exists
    if ( -not ( Test-Path -Path $tagsfromfile -PathType Leaf ) ) {
        Write-Host "ERROR: Source file $tagsfromfile does not exist" -ForegroundColor Red
        exit
    } #if

    $aSourceTags = @( fTagsFromString( $tagsfromfile ) )

    # Loop through all the files in filespec
    foreach( $oChildItem in $aFiles ) { 
        $aTargetTags = @( fTagsFromString( $oChildItem.Name ))
        $sSourceFile = $oChildItem.Qualified
        $sTargetFile = [System.String]::Concat( $oChildItem.Directory, "\" )
        $sTargetFile += fGetBaseName( $oChildItem.Name )
        $bChangesMade = $false

        # Loop through every tag in $aSourceTags and insert them into $aTargetTags
        foreach( $sTempTag in $aSourceTags ) {
            
            # If this tag is a rating and $aTargetTags already contains a rating, do nothing
            if( "#1#2#3#4#5".Contains( $sTempTag ) -and ( $aTargetTags.Contains( "#1" ) -or $aTargetTags.Contains( "#2" ) -or $aTargetTags.Contains( "#3" ) -or $aTargetTags.Contains( "#4" ) -or $aTargetTags.Contains( "#5" ) ) ) { }
            elseif( -not $aTargetTags.Contains( $sTempTag ) ) { 
                $aTargetTags += $sTempTag
                $bChangesMade = $true
            } #elseif

        } #foreach

        # If any changes were made we need to write them
        if( $bChangesMade ) {
            
            # Add a space after the basename and sort the tags
            $sTargetFile += " "
            [array]::sort( $aTargetTags )

            # Append all the tags to basename
            foreach( $sTempTag in $aTargetTags ) { $sTargetFile += $sTempTag }
            $sTargetFile += $oChildItem.Extension
            
            $sOutputString = [System.String]::Concat( $sSourceFile, " -> ", $sTargetFile  )
            Write-Output $sOutputString

            # Now rename the file
			if( -not $nowrite ) { 
                Move-Item -Path $sSourceFile -Destination $sTargetFile 
                $iFilesProcessed++	
            } #if

        } #if
            
    } #foreach

  	# Output the number of files renamed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iFilesProcessed files moved -ForegroundColor Cyan }

    # To avoid shitty conflicting command-lines, just quit now
    exit	
} #if

#-------------------------------------------------------------------
# Process the -tagsfromexif command
#-------------------------------------------------------------------
if( $tagsfromexif ) {
    $iFilesProcessed = 0
    $sFileFormat = "image"

    if( $filespec.Contains( "mp4" ) ) { $sFileFormat = "video" }
    
    # Create the input file
    # $sCommand = 'g:\tools\exiftool.exe *.jpg -p $filename;$rating;$keywords -Rating -Keywords -s2 -m > temp.csv'
    if( $sFileFormat -eq "video" ) {
        &G:\tools\export-mp4-exif.cmd $filespec
    } #if
    else {
        &G:\tools\export-jpg-exif.cmd $filespec
    } #else

    # Verify the filename passed is valid
    if ( -not ( Test-Path -Path 'temp.csv' -PathType Leaf ) ) {
        Write-Host "ERROR: Temp file temp.csv could not be read" -ForegroundColor Red
        exit
    } #if

    # Load in the contents of the file into a dummy array.  We still need to parse all the tags
    $aExifTemp = Import-Csv -Delimiter ";" -Path 'temp.csv' -Header 'Filename', 'Rating', 'TagString'

    $aExifData = foreach( $oExifItem in $aExifTemp ) {
        # Parse Rating if this is a video
        if( $sFileFormat = "video" ) {
            switch( $oExifItem.Rating ) {
                "25" { $oExifItem.Rating = "2" }
                "50" { $oExifItem.Rating = "3" }
                "75" { $oExifItem.Rating = "4" }
                "99" { $oExifItem.Rating = "5" }
            }
        }

        # Remove any spaces from the TagString and add hashes
        if( $oExifItem.TagString.Length -gt 0 ) { $oExifItem.TagString = [System.String]::Concat( "#", $oExifItem.TagString ) }
        $oExifItem.TagString = $oExifItem.TagString.Replace( " ","#" )

        # if Rating is non-zero, add it as a tag
        if( ( $oExifItem.Rating -ne "0" ) -and ( $oExifItem.Rating -ne "" ) ) { 
            if( $oExifItem.TagString.Length -gt 0 ) { $oExifItem.TagString += [System.String]::Concat( ",#", $oExifItem.Rating ) }
            else { $oExifItem.TagString += [System.String]::Concat( "#", $oExifItem.Rating ) } #else
        } #if
            
        New-Object -TypeName PSObject -Property @{
            Name = $oExifItem.Filename
            Tags = $oExifItem.TagString.Split( "," )
        } #New-Object

    } #foreach

    # Loop through all files in the input list and compare them to the imported EXIF list
    foreach( $oChildItem in $aFiles ) {

        # Loop through every file in $aExifData to see if they're a match
        foreach( $oExifItem in $aExifData ) {
            if( $oExifItem.Name -eq $oChildItem.Name ) { 

                # We have a match
                $bChangesMade = $false

                # For some reason the tag count is one higher than it should be, so don't proceed unless the count is at least 2, which means at least one
                if( $oExifItem.Tags.Count -gt 1 ) {
                    # Loop through all the tags in the EXIF list and add them to $oChildItem.Tags
                    foreach( $sTag in $oExifItem.Tags ) {

                        if( -not $oChildItem.Tags.Contains( $sTag ) ) { 
                            if( "#1#2#3#4#5".Contains( $sTag ) ) {
                                # This is a rating
                                # If there is already a rating do nothing, if there isn't then add this one
                                if( $oChildItem.Tags.Contains( "#1" ) -or $oChildItem.Tags.Contains( "#2" ) -or $oChildItem.Tags.Contains( "#3" ) -or $oChildItem.Tags.Contains( "#4" ) -or $oChildItem.Tags.Contains( "#5" ) ) { }
                                else {
                                    $oChildItem.Tags += $sTag
                                    $bChangesMade = $true
                                } #else
                            } #if
                            else {
                                $oChildItem.Tags += $sTag
                                $bChangesMade = $true
                            }
                        } #if
                    
                    } #foreach
                } #if

                # We're done with this file
                [array]::sort( $oChildItem.Tags )

                # If any changes were made, rename the output file
                if( $bChangesMade ) {
                    $sSourceFile = $oChildItem.Name
                    $sTargetFile = fGetBaseName( $oChildItem.Name )
                    $sTargetFile = [System.String]::Concat( $sTargetFile, " " )

                    # Add all the tags to the target file name, then the extension
                    foreach( $sTag in $oChildItem.Tags ) { 
                        $sTargetFile += $sTag 
                    } #foreach

                    $sTargetFile = [System.String]::Concat( $sTargetFile, $oChildItem.Extension )

                    $sOutputString = [System.String]::Concat( $sSourceFile, " -> ", $sTargetFile  )
                    Write-Output $sOutputString

                    # Now rename the file
			        if( -not $nowrite ) { 
                        Move-Item -Path $sSourceFile -Destination $sTargetFile 
                        $iFilesProcessed++	
                    } #if

                } #if

            } #if

        } #foreach
    
    } #foreach

    # Delete the temp file
    Remove-Item -Path 'temp.csv'

    # Output the number of files renamed if it's in verbose mode
    if( -not $quiet ) { Write-Host $iFilesProcessed files renamed -ForegroundColor Cyan }

    # Clear all EXIF data if requested
    if ( $clearexif -and ( -not $nowrite ) ) {
        if( -not $quiet ) { Write-Host Deleting all EXIF data... -ForegroundColor Cyan }
        &G:\tools\exiftool.exe $filespec -all= -overwrite_original_in_place
    } #if

    # To avoid shitty conflicting command-lines, just quit now
    exit	

} #if

# If we're here it means no valid commands were found.  Just display command help
if( -not $quiet ) {
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
} #if

#-------------------------------------------------------------------
# Main executable end
# ------------------------------------------------------------------