#
# Pitch Checker
#
using module .\lib.pwsh\stdps.psm1
using module .\WaveFile.psm1
using module .\BufferReader.psm1
using module .\FFTHelper.psm1
using module .\Pitch.psm1
using module .\Results.psm1

param(
[string] $File,
[Alias('Start','Skip')]
[float] $StartTime = 0,
[float] $Interval = 0.2,
[string] $ExportTo,
[float] $PitchThrethold = 0.01,
[float] $PeakThrethold = 0.05,
[switch] $ShowAll,
[switch] $ShowPeak,
[string] $LogFilename = "logs\log.txt",
[int] $LogGenerations = 9,
[switch] $Help
)

$ErrorActionPreference = "stop"
Set-StrictMode -Version latest

RunApp [Main] $LogFilename $LogGenerations
return

class Peak {
    $Freq;
    $Mag;
}

class Main {
    #
    # WaveFile related
    #
    $BuffReader;
    [int]$BufferSize;
    [int]$SamplingRate;
    [int]$BlockSize;
    [int]$BytesPerSec;
    [int]$DataStartIndexInFile;
    #
    # FFT related
    #
    $FFTData;
    $FFTDataBlank;
    [int]$SampleCount;
    [int]$WaveDataCount;
    $FreqResolution;
    [int]$FFTDataStartIndex;
    [float]$SignalScaleFactor;
    $MinFreq;
    $MaxFreq;
    [Peak[]]$Peaks;
    [float]$PeakIgnoreThrethold;

    Run() {
        $this.Init()
        if (!$script:ExportTo) {
            $this.DecodeWave()
        } else {
            $this.ExportToCsv($script:ExportTo)
        }
    }

    DecodeWave() {
        $pitch = [Pitch]::New()
        $resMan = [ResultManager]::New($script:PitchThrethold)

        $lastIndex = $this.BufferSize - $script:Interval * $this.BytesPerSec
        $preNote = ""
        while (($pos = $this.BuffReader.GetCurrentPosition()) -le $lastIndex) {
            $this.SetData()
            FFT_Forward $this.FFTData

            $this.DetectPeak()
            if ($script:ShowPeak) {
                log "DEBUG>> $pos $($this.Peaks |%{'[{0}hz,{1}]' -f $_.Freq,$_.Mag})"
            }

            $pk = ($this.Peaks |Sort Freq)[0]
            if ($pk.Freq -le $this.MinFreq) { continue }
            if ($pk.Mag -lt $this.PeakIgnoreThrethold) { continue }

            $pitch.Find($pk.Freq)
            $msg = $resMan.Add($pitch)
            if ($script:ShowAll -or $preNote -ne $pitch.Name) {
                log "$($this.PocToTimeSpan($pos)) $($pitch.Name) $($pk.Freq) ($('{0:+#;-#;0}' -f $pitch.FreqDiff)) $msg"
            }
            $preNote = $pitch.Name
        }

        $resMan.ShowAll()
    }

    [string] PocToTimespan($pos) {
        return '{0:h\:mm\:ss\.f}' -f [TimeSpan]::FromSeconds(($pos - $this.DataStartIndexInFile) / $this.BytesPerSec)
    }

    #
    # detect peaks
    #
    DetectPeak() {
        $nPeaks = 3
        $this.Peaks = @(, [Peak]@{Freq = 9999; Mag = 0})
        $cutline = 0.3
        $preMag = -1
        $rising = $false
        $sIndex = $this.MinFreq / $this.FreqResolution - 1
        $eIndex = $this.MaxFreq / $this.FreqResolution + 1
        foreach ($i in $sIndex .. $eIndex) {
            $freq = $i * $this.FreqResolution

            $mag = $this.FFTData[$i].Magnitude
            if ($mag -le $cutline) { continue }
            if ($mag -le $preMag) {
                if ($rising) {
                    $this.Peaks += ,[Peak]@{Freq = $freq - $this.FreqResolution; Mag = $preMag }
                }
                $rising = $false
            }
            else {
                $rising = $true
            }
            $preMag = $mag
        }
        $this.Peaks = $this.Peaks | Sort Mag | Select -last $nPeaks
    }

    #
    #--- Export FFT data to CSV
    #
    ExportToCsv($file) {
        $index = $this.DataStartIndexInFile + [int]($script:StartTime * $this.BytesPerSec)
        $this.BuffReader.Seek($index)
        $this.SetData()
        FFT_Forward $this.FFTData
        $this.FFTData |Export-Csv $file
        log "FFT Data exported: $file"

        $this.DetectPeak()
        log "Peaks detected"
        $this.Peaks |%{ log "Peak $($_.Freq) Hz, $($_.Mag)" }
    }

    #
    # setup FFT Data
    #
    SetData() {
        $this.FFTData = $this.FFTDataBlank.Clone()
        $this.BuffReader.CopyData($this.FFTData, $this.FFTDataStartIndex, $this.WaveDataCount)
    }

    Init() {
        if (!$script:File) {
            throw "-File が指定されていません"
        }
        $this.LoadWaveFile($script:File)
        $this.BufferSize = $this.BuffReader.Bytes.Length
        $this.InitFFT()
    }

    LoadWaveFile([string]$filename) {
        $wave = [WaveFile]::New()
        $wave.Load($filename)

        $this.SamplingRate = $wave.FmtChunk.SamplesPerSec
        $this.BlockSize = $wave.FmtChunk.BlockAlign
        $this.DataStartIndexInFile = $wave.DataChunk.DataStartIndex
        $this.BytesPerSec = $this.SamplingRate * $this.BlockSize
        switch ($wave.FmtChunk.BitsPerSample) {
            32 {
                if ($wave.FmtChunk.FormatTag -eq 3) {
                    $this.BuffReader = [Float32]::New($wave.FileBuffer, $wave.FmtChunk.BlockAlign)
                    $this.SignalScaleFactor = 10000
                    $this.PeakIgnoreThrethold = 0.1
                }
                break
            }
            16 {
                if ($wave.FmtChunk.FormatTag -eq 1) {
                    $this.BuffReader = [PCM16]::New($wave.FileBuffer, $wave.FmtChunk.BlockAlign)
                    $this.SignalScaleFactor = 100
                    $this.PeakIgnoreThrethold = 0.0001 #??
                }
            }
        }
        if (!$this.BuffReader) {
            throw "Wave fileformat not supported BitsPerSample=$($wave.FmtChunk.BitsPerSample), FormatTag=$($wave.FmtChunk.FormatTag)"
        }
    }

    InitFFT() {
        $this.SampleCount = $this.SamplingRate
        $this.WaveDataCount = [int]($script:Interval * $this.SamplingRate)
        $this.FFTDataStartIndex = [int](($this.SampleCount - $this.WaveDataCount) / 2)
        $this.FreqResolution = $this.SamplingRate / $this.SampleCount
        $this.MinFreq = 170
        $this.MaxFreq = 2000
        SetComplexArray $this 'FFTDataBlank' $this.SampleCount
    }
}


