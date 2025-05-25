class Pitch {
    $Name;
    $Freq;
    $FreqDiff;
    $FreqDiffAbs;
    $RightFreq;

    $Notes = @(
        @{ Name = "!!Too Low!!"; Freq = 100; },
        @{ Name = "G3 ソ"; Freq = 197; },
        @{ Name = "G#3 ソ#"; Freq = 208; },
        @{ Name = "A3 ラ"; Freq = 221; },
        @{ Name = "A#3 ラ#"; Freq = 234; },
        @{ Name = "B3 シ"; Freq = 248; },
        @{ Name = "C4 ド"; Freq = 264; },
        @{ Name = "C#4 ド#"; Freq = 279; },
        @{ Name = "D4 レ"; Freq = 297; },
        @{ Name = "D#4 レ#"; Freq = 313; },
        @{ Name = "E4 ミ"; Freq = 332; },
        @{ Name = "F4 ファ"; Freq = 351; },
        @{ Name = "F#4 ファ#"; Freq = 372; },
        @{ Name = "G4 ソ"; Freq = 395; },
        @{ Name = "G#4 ソ#"; Freq = 418; },
        @{ Name = "A4 ラ"; Freq = 442; },
        @{ Name = "A#4 ラ#"; Freq = 468; },
        @{ Name = "B4 シ"; Freq = 497; },
        @{ Name = "C5 ド"; Freq = 527; },
        @{ Name = "C#5 ド#"; Freq = 558; },
        @{ Name = "D5 レ"; Freq = 592; },
        @{ Name = "D#5 レ#"; Freq = 627; },
        @{ Name = "E5 ミ"; Freq = 664; },
        @{ Name = "F5 ファ"; Freq = 703; },
        @{ Name = "F#5 ファ#"; Freq = 744; },
        @{ Name = "G5 ソ"; Freq = 790; },
        @{ Name = "G#5 ソ#"; Freq = 836; },
        @{ Name = "A5 ラ"; Freq = 884; },
        @{ Name = "A#5 ラ#"; Freq = 936; },
        @{ Name = "B5 シ"; Freq = 995; },
        @{ Name = "C6 ド"; Freq = 1054; },
        @{ Name = "C#6 ド#"; Freq = 1116; },
        @{ Name = "D6 レ"; Freq = 1184; },
        @{ Name = "D#6 レ#"; Freq = 1255; },
        @{ Name = "E6 ミ"; Freq = 1328; },
        @{ Name = "F6 ファ"; Freq = 1407; },
        @{ Name = "F#6 ファ#"; Freq = 1488; },
        @{ Name = "G6 ソ"; Freq = 1580; },
        @{ Name = "G#6 ソ#"; Freq = 1674; },
        @{ Name = "A6 ラ"; Freq = 1768; },
        @{ Name = "A#6 ラ#"; Freq = 1872; },
        @{ Name = "B6 シ"; Freq = 1990; },
        @{ Name = "!!Too High!!"; Freq = 2000; }
    )

    Find($f) {
        $this.Freq = $f
        foreach ($i in 2 .. $($this.Notes.Count - 1)) {
            if ($f -gt $this.Notes[$i].Freq) { continue }
            $lo = $this.Notes[$i - 1]
            $hi = $this.Notes[$i]
            $dlo = $f - $lo.Freq
            $dloa = [Math]::Abs($dlo)
            $dhi = $f - $hi.Freq
            $dhia = [Math]::Abs($dhi)
            if ($dloa -lt $dhia) {
                $this.Name = $lo.Name
                $this.RightFreq = $lo.Freq
                $this.FreqDiff = $dlo
                $this.FreqDiffAbs = $dloa
            }
            else {
                $this.Name = $hi.Name
                $this.RightFreq = $hi.Freq
                $this.FreqDiff = $dhi
                $this.FreqDiffAbs = $dhia
            }
            return
        }
    }
}
