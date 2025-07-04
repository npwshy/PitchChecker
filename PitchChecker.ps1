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
[float] $StartTime = 1,
[float] $Interval = 0.1,
[float] $EndTime,
[float] $SkipEnd = 1,
[string] $OutFile,
[float] $PitchThrethold = 0.01,
[float] $NoiseRatio = 1.5,
[float] $PeakNoiseRatio = 10,
[string] $LogFilename = "logs\log.txt",
[int] $LogGenerations = 9,
[switch] $Help
)

$ErrorActionPreference = "stop"
Set-StrictMode -Version latest

RunApp [Main] $LogFilename $LogGenerations
return


#
# Peak
#
class Peak {
    $Freq;          # Frequency
    $Mag;           # Magnitude
    $BaseFreq;      # Null or ref to [Peak] of base frequency
    $TotalMag;      # sum of mags of overtones or 0 if [Peak] is overtone
    $NoiseLevel;    # interval-wide information: noise level of the interval
    $MaxMag;        # interval-wide information: max of mag in the interval. may be different from Mag
}

#
# DunpFile structure
#
class FreqDumpFile {
    [FreqDump[]] $FreqDump; # wave dump data for each interval
    [string] $WaveFilename; # Filename
}

class FreqDump {
    [float] $Time;
    [int] $FreqMin;             # frequency of Magnitudes[0]
    [int] $FreqMax;             # frequency of Maginutude[-1]
    [float] $PeakFreq;          # identified peak in the interval
    [float] $PeakMag;           # mag of the peak
    [float] $MaxMag;            # max mag in the interval
    [float] $NoiseLevel;
    [float[]] $Magnitudes;      # array of mags: FreqMin - FreqMax
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
    [float] $AverageMag;
    [Peak[]]$Peaks;
    [Double[]] $Window;

    [float] $Time;
    [float] $CurrentNoiseLevel;

    [bool] $GenerateFreqDump = $false;
    [FreqDumpFile] $FreqDumpFile;
    [string] $OutFile_JSON;
    [string] $OutFile_HTML;

    Run() {
        $this.Init()
        $this.DecodeWave()
        if ($this.GenerateFreqDump) {
            $this.FreqDumpFile |ConvertTo-Json -depth 5 -Compress |%{ $_ -replace '},',"},`n" } |Out-File $this.OutFile_JSON
            log "Frequency data saved: $($this.OutFile_JSON)"
            & pwsh .\NewViewer.ps1 -DataFile $this.OutFile_JSON -OutFile $this.OutFile_HTML
            log "Viewer HTML saved: $($this.OutFile_HTML)"
        }
    }

    DecodeWave() {
        $pitch = [Pitch]::New()
        $resMan = [ResultManager]::New($script:PitchThrethold)

        $lastIndex = $script:EndTime ? $this.DataStartIndexInFile + [int]($script:EndTime * $this.BytesPerSec) : $this.BufferSize -  [int]($script:SkipEnd + $script:Interval) * $this.BytesPerSec
        while (($pos = $this.BuffReader.GetCurrentPosition()) -le $lastIndex) {
            logv "DEBUG> Processing $($this.Time)"
            $this.SetData()

            FFT_Forward $this.FFTData

            $pk = $this.DetectPeak()
            $note = "--- silent ---" # silent
            if ($pk) {
                $pitch.Find($pk.Freq)
                $msg = $resMan.Add($pitch)
                $nl = $pk.NoiseLevel
                $note = "$($pitch.Name) $($pk.Freq) ($('{0:+#;-#;0}' -f $pitch.FreqDiff)) $msg"
                log "$($this.PocToTimeSpan($pos)) $note"
                logv "PMag=$($pk.Mag), MMag=$($pk.MaxMag), NL=$($nl), P/N=$(($pk.Mag/$nl).ToString('0.0')), M/N=$(($pk.MaxMag/$nl).TOString('0.0'))"
            } else {
                logv "No Peak identified"
            }

            if ($this.GenerateFreqDump) {
                $d = [FreqDump]@{
                    Time = $this.Time
                    FreqMin = 100
                    FreqMax = 2000
                    PeakFreq = $pk ? $pk.Freq : 0
                    PeakMag = $pk ? $pk.Mag : 0
                    MaxMag = $pk ? $pk.MaxMag : 0
                    NoiseLevel = $this.CurrentNoiseLevel
                }
                $d.Magnitudes = $this.FFTData[$d.FreqMin .. $d.FreqMax].Magnitude
                $this.FreqDumpFile.FreqDump += ,$d

            }

            $this.Time += $script:Interval
        }

        $resMan.ShowAll()
    }

    [string] PocToTimespan($pos) {
        $f = '{0:h\:mm\:ss\.f}'
        switch ($script:Interval) {
            { $_ -ge 1 } { $f = '{0:h\:mm\:ss}'; break }
            { $_ -ge 0.1 } { $f = '{0:h\:mm\:ss\.f}'; break }
            { $_ -ge 0.01 } { $f = '{0:h\:mm\:ss\.ff}'; break }
        }
        return $f -f [TimeSpan]::FromSeconds(($pos - $this.DataStartIndexInFile) / $this.BytesPerSec)
    }

    #
    # detect peaks
    #
    [Peak] DetectPeak() {
        $this.Peaks = @()
        $preMag = -1
        $rising = $false
        $sIndex = $this.MinFreq / $this.FreqResolution - 1
        $eIndex = $this.MaxFreq / $this.FreqResolution + 1
        $ignoreThrethold = ($this.CurrentNoiseLevel = $this.GetNoiseLevel()) * $script:NoiseRatio
        logv "IgnoreThrethold set: $ignoreThrethold"
        $magMax = 0
        foreach ($i in $sIndex .. $eIndex) {
            $freq = $i * $this.FreqResolution

            $mag = $this.FFTData[$i].Magnitude
            if ($mag -gt $ignoreThrethold) {
                if ($mag -le $preMag) {
                    if ($rising) {
                        $this.Peaks += ,[Peak]@{Freq = $freq - $this.FreqResolution; Mag = $preMag }
                        logv "Peak identified $($this.Peaks[-1].Freq),$premag"
                        if ($premag -gt $magMax) {
                            $magMax = $premag
                        }
                    }
                    $rising = $false
                }
                else {
                    $rising = $true
                }
            }
            $preMag = $mag
        }
        logv "DetectPeak: magmax = $magMax (CNL=$($this.CurrentNoiseLevel)) $($this.Peaks.Freq)"
        if ($magMax -lt $this.CurrentNoiseLevel * $script:PeakNoiseRatio) {
            return $null
        }
        return $this.SelectPeak()
    }

    [Peak] SelectPeak() {
        if (!$this.Peaks) {
            logv "SelectPeak: no peak"
            return $null;
        }

        logv "SelectPeak: Peaks#=$($this.Peaks.Count) $($this.Peaks.Freq)"

        $p = [Peak]@{Freq=0}

        $this.Peaks = $this.Peaks |Sort Mag -Descending
        $OVtest = $this.Peaks |Sort Freq
        $allowance = 5
        foreach ($e in $this.Peaks) {
            if ($e.BaseFreq) { continue }
            foreach ($ov in $OVtest) {
                if ($ov.Freq -ge $e.Freq) { break }
                $ratio = $e.Freq / $ov.Freq
                $fract = ($ratio - [Math]::Floor($ratio)) * 100
                if ($fract -le $allowance -or $fract -ge (100 - $allowance)) {
                    logv "IsOveftone: F=$($e.Freq) OT=$($ov.Freq) fract=$fract"
                    $e.BaseFreq = $ov
                    $ov.TotalMag += $e.Mag + $e.TotalMag
                    break
                }
            }
        }
        logv "SelectPeak ---"
        $this.Peaks |%{ logv "Peak: f=$($_.Freq) m=$($_.Mag) tm=$($_.TotalMag)" }
        logv "--- SelectPeak"
        $p = $this.Peaks |? { $_.TotalMag -gt 0 } |Sort TotalMag |Select -Last 1
        if (!$p) {
            $p = $this.Peaks[0]
        }
        $p.MaxMag = $this.Peaks[0].Mag
        $p.NoiseLevel = $this.CurrentNoiseLevel
        return $p
    }

    [double] GetNoiseLevel() {
        $m = $this.FFTData[200..2000].Magnitude | Measure-Object -Average -Maximum
        logv "GetNoiseLevel: $($m.Average) $($m.Maximum)"
        return $m.Average
    }

    #
    # setup FFT Data
    #
    SetData() {
        $this.FFTData = $this.FFTDataBlank.Clone()
        $this.BuffReader.CopyData($this.FFTData, $this.FFTDataStartIndex, $this.WaveDataCount, $this.Window)
    }

    Init() {
        if (!$script:File) {
            throw "-File が指定されていません"
        }

        $this.LoadWaveFile($script:File)
        $this.BufferSize = $this.BuffReader.Bytes.Length
        $this.InitFFT()


        $index = $this.DataStartIndexInFile + [int]($script:StartTime * $this.BytesPerSec)
        $this.BuffReader.Seek($index)
        $this.Time = $script:StartTime

        if ($script:OutFile) {
            $this.GenerateFreqDump = $true
            $this.FreqDumpFile = [FreqDumpFile]@{
                FreqDump = @()
                WAVeFilename = $script:File
            }
            $ext = [IO.Path]::GetExtension($script:OutFile)
            $this.OutFile_HTML = $script:OutFile -replace "$ext$",'.html'
            $this.OutFile_JSON = $script:OutFile -replace "$ext$", '.json'
        }
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
                }
                break
            }
            16 {
                if ($wave.FmtChunk.FormatTag -eq 1) {
                    $this.BuffReader = [PCM16]::New($wave.FileBuffer, $wave.FmtChunk.BlockAlign)
                    $this.SignalScaleFactor = 100
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
        $this.Window = GetWindow $this.WaveDataCount
    }
}


