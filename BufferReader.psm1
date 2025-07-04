#
# Buffer Reader - purpose specific reader from bytebuffer
#
using module .\ByteBuffer.psm1
using module .\FFTHelper.psm1

class BufferReader : ByteBuffer {
    $BlockSize;
    $SkipSize;

    BufferReader([ByteBuffer]$b, $bs) {
        $this.Bytes = $b.Bytes
        $this.Index = $b.Index
        $this.BlockSize = $bs
    }
}

class PCM16 : BufferReader {
    PCM16($b, $bs) : base($b, $bs) {
        $this.SkipSize = $bs - 2
    }

    [int] GetData() {
        $v = $this.GetInt16()
        $this.Index += $this.SkipSize
        return $v
    }

    CopyData($buff, $bIndex, $count, [double[]]$window) {
        0 .. ($count - 1)| % {
            $v = [BitConverter]::ToInt16($this.Bytes, $this.Index)
            $buff[$bIndex++] = NewComplex ($v * $window[$_])
            $this.Index += $this.BlockSize
        }
    }

}

class Float32 : BufferReader {
    Float32([ByteBuffer]$b, $bs) : base($b, $bs) {
        $this.SkipSize = $bs - 4
    }

    [single] GetData() {
        $v = $this.GetSingle()
        $this.Index += $this.SkipSize
        return $v
    }

    CopyData($buff, $bIndex, $count, [double[]]$window) {
        0 .. ($count - 1) |%{
            $v = [BitConverter]::ToSingle($this.Bytes, $this.Index)
            $buff[$bIndex++] = NewComplex ($v * $window[$_])
            $this.Index += $this.BlockSize
        }
    }
}
