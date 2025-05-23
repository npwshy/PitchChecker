#
# ByteBuffer
#
class ByteBuffer {
    [byte[]] $Bytes;
    $Index;

    Load([string]$file) {
        $this.Bytes = [IO.File]::ReadAllBytes($file)
        $this.Index = 0
        log "$($this.GetType().Name).Load: File loaded: $($file) Size=$($this.Bytes.Length)"
    }

    [byte[]] GetBytes($len) {
        $ret = [byte[]]::New($len)
        $s = $this.Index
        $this.Index += $len
        [Buffer]::BlockCopy($this.Bytes, $s, $ret, 0, $len)
        return $ret
    }

    [string] GetStringN($len) {
        $s = $this.Index
        $this.Index += $len
        return ($s .. ($this.Index - 1) |%{ [char]$this.Bytes[$_] } |? { $_ }) -join('')
    }

    [string] GetString() {
        $chars = @()
        while ($c = [char]$this.Bytes[$this.Index++]) {
            $chars += ,$c
        }
        return $chars -join('')
    }

    [int16] GetInt16() {
        $s = $this.Index
        $this.Index += 2;
        return [BitConverter]::ToInt16($this.Bytes, $s)
    }

    [uint16] GetUInt16() {
        $s = $this.Index
        $this.Index += 2;
        return [BitConverter]::ToUInt16($this.Bytes, $s)
    }

    [int32] GetInt32() {
        $s = $this.Index
        $this.Index += 4;
        return [BitConverter]::ToInt32($this.Bytes, $s)
    }
    [uint32] GetUInt32() {
        $s = $this.Index
        $this.Index += 4;
        return [BitConverter]::ToUInt32($this.Bytes, $s)
    }
    [single] GetSingle() {
        $s = $this.Index
        $this.Index += 4;
        return [BitConverter]::ToSingle($this.Bytes, $s)
    }

    Seek($idx) {
        $this.Index = $idx
    }
    SeekBy($delta) {
        $this.Index += $delta
    }

    [int] GetCurrentPosition() { return $this.Index }

    Dispose() {
        $this.Bytes = $null
        $this.Index = 0
    }
}
