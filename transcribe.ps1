# PowerShell script to transcribe MP4 files using OpenAI Whisper if no corresponding SRT exists

# Set Whisper command (ensure `whisper` is installed via pip)
$whisperCommand = "whisper"

# Get all MP4 files in the current directory
$mp4Files = Get-ChildItem -Path . -Filter "*.mp4"

foreach ($mp4 in $mp4Files) {
    $srtFile = [System.IO.Path]::ChangeExtension($mp4.FullName, ".srt")

    if (Test-Path $srtFile) {
        Write-Host "Subtitle file already exists for: $($mp4.Name), skipping..."
    } else {
        Write-Host "Transcribing: $($mp4.Name)..."
        & $whisperCommand $mp4.FullName --model medium --output_format srt
    }
}

Write-Host "Processing complete."
