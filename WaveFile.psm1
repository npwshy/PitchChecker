#
# Wave Format file
#
using module .\ByteBuffer.psm1

class WaveFile {
    [ByteBuffer] $FileBuffer;
    $FmtChunk;
    $DataChunk;

    Load([string]$file) {
        $this.FileBuffer = [ByteBuffer]::New()
        $this.FileBuffer.Load($file)

        $header = [WaveHeader]::New()
        $header.ReadFromBuffer($this.FileBuffer)

        while ($ckId = $this.FileBuffer.GetStringN(4)) {
            switch ($ckId) {
                'bext' {
                    [void][BExtChunk]::New($ckId, $this.FileBuffer)
                    break
                }
                'data' {
                    $this.DataChunk = [DataChunk]::New($ckId, $this.FileBuffer)
                    $this.DataChunk.Show()
                    return;
                }
                'fmt ' {
                    $this.FmtChunk = [FmtChunk]::New($ckId, $this.FileBuffer)
                    $this.FmtChunk.Show()
                    break
                }
                default {
                    [void][JunkChunk]::New($ckId, $this.FileBuffer)
                }
            }
        }
    }
}

class RIFFHeader {
    [string] $FourCC;
    $ChunkSize;

    ReadFromBuffer([ByteBuffer]$b) {
        $this.FourCC = $b.GetStringN(4)
        $this.ChunkSize = $b.GetInt32()

        if ($this.FourCC -ne 'RIFF') {
            throw "File is NOT RIFF format. Bye (FourCC=$($this.FourCC))"
        }
    }
}

class WaveHeader : RIFFHeader {
    ReadFromBuffer([ByteBuffer]$b) {
        ([RIFFHeader]$this).ReadFromBuffer($b)
        $wave = $b.GetStringN(4)
        if ($wave -ne "WAVE") {
            throw "Header Tag WAVE not found: $wave"
        }
    }
}

class Chunk {
    [string] $ChunkID;
    $ChunkSize;

    Chunk([string]$id, [ByteBUffer]$b) {
        $this.ChunkID = $id;
        $this.ChunkSize = $b.GetInt32()
    }

    Show() {
        log "--- $($this.ChunkId) ---"
        $this |Get-Member -MemberType NoteProperty,Property |%{ $_.Name } |
            ? { $_ -ne 'ChunkID' } |% {
            log "$($_): $($this.$_)"
        }
    }
}

class BExtChunk : Chunk {
    $Description;
    $Originator;
    $OriginatorReference;
    $OriginationDate;
    $OriginationTime;
    $TimeReferenceLow;
    $TimeReferenceHigh
    $Version

    BExtChunk($id, [ByteBuffer]$b) : base($id, $b) {
        $nextChunk = $b.GetCurrentPosition() + $this.ChunkSize

        $this.Description = $b.GetStringN(256)
        $this.Originator = $b.GetStringN(32)
        $this.OriginatorReference = $b.GetStringN(32)
        $this.OriginationDate = $b.GetStringN(10)
        $this.OriginationTime = $b.GetStringN(8)

        $b.Seek($nextChunk)
    }
}

class FmtChunk : Chunk {
    $FormatTag;
    $Channels;
    $SamplesPerSec;
    $AvgBytesPerSec;
    $BlockAlign;
    $BitsPerSample;
    $ExtensionSize;
    $ValidBitsPerSample;
    $ChannelMask;
    $SubFormat;

    FmtChunk($id, [ByteBuffer]$b) : base($id, $b) {
        $this.FormatTag = $b.GetUInt16()
        $this.Channels = $b.GetInt16()
        $this.SamplesPerSec = $b.GetUInt32()
        $this.AvgBytesPerSec = $b.GetUInt32()
        $this.BlockAlign = $b.GetInt16()
        $this.BitsPerSample = $b.GetInt16()
        if ($this.ChunkSize -gt 16) {
            $this.ExtensionSize = $b.GetInt16()
            if ($this.ExtensionSize) {
                $this.ValidBitsPerSample = $b.GetInt16()
                $this.ChannelMask = $b.GetInt32()
                $this.SubFormat = $b.GetStringN(16)
            }
        }
    }
}

class JunkChunk : Chunk {
    JunkChunk($id, [ByteBuffer]$b) : base($id, $b) {
        $nextChunk = $b.GetCurrentPosition() + $this.ChunkSize
        $b.Seek($nextChunk)
    }
}

class DataChunk : Chunk {
    $DataStartIndex;

    DataChunk($id, [ByteBuffer]$b) : base($id, $b) {
        $this.DataStartIndex = $b.GetCurrentPosition()
    }
}