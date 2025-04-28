
# PowerShell script to transcribe MP4 files using faster-whisper if available, else fall back to whisper

# Detect whether faster-whisper or whisper is installed
$fasterWhisperAvailable = $false
$whisperAvailable = $false

try {
    python -c "import faster_whisper" > $null 2>&1
    if ( $LASTEXITCODE -eq 0 ) {
        $fasterWhisperAvailable = $true
    }
} catch { }

try {
    python -c "import whisper" > $null 2>&1
    if ( $LASTEXITCODE -eq 0 ) {
        $whisperAvailable = $true
    }
} catch { }

if ( -not ($fasterWhisperAvailable -or $whisperAvailable) ) {
    Write-Host "Neither faster-whisper nor whisper is installed. Please install one via pip." -ForegroundColor Red
    exit 1
}

# Get all MP4 files in the current directory
$mp4Files = Get-ChildItem -Path . -Filter "*.mp4"

foreach ($mp4 in $mp4Files) {
    $srtFile = [System.IO.Path]::ChangeExtension($mp4.FullName, ".srt")

    if (Test-Path $srtFile) {
        Write-Host "Subtitle file already exists for: $($mp4.Name), skipping..."
    } else {
        Write-Host "Transcribing: $($mp4.Name)..."

        if ( $fasterWhisperAvailable ) {
            # Use faster-whisper
            python -c "
from faster_whisper import WhisperModel
import os

model = WhisperModel('medium')
segments, info = model.transcribe(r'''$($mp4.FullName)''')

srt_path = r'''$($srtFile)'''
with open(srt_path, 'w', encoding='utf-8') as srt_file:
    for i, (segment, _) in enumerate(segments):
        start = segment.start
        end = segment.end
        text = segment.text.replace('-->', '->')  # SRT format escape

        srt_file.write(f'{i+1}\n')
        srt_file.write('{0:02d}:{1:02d}:{2:02d},{3:03d} --> {4:02d}:{5:02d}:{6:02d},{7:03d}\n'.format(
            int(start // 3600), int((start % 3600) // 60), int(start % 60), int((start * 1000) % 1000),
            int(end // 3600), int((end % 3600) // 60), int(end % 60), int((end * 1000) % 1000)
        ))
        srt_file.write(text.strip() + '\n\n')
"
        } elseif ( $whisperAvailable ) {
            # Use original whisper CLI
            whisper $mp4.FullName --model medium --output_format srt
        }
    }
}

Write-Host "Processing complete."
