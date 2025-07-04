using module .\Pitch.psm1


class Result {
    [string]$Pitch;
    $GoodCount;
    $LowCount;
    $LowDiff;
    $HiCount;
    $HiDiff;
}

class ResultManager {
    $Threthold;
    $Records;
    $TotalGood = 0;
    $TotalLow = 0;
    $TotalHi = 0;
    $TotalCount = 0;


    ResultManager($t) {
        $this.Records = @{}
        $this.Threthold = $t
    }

    [string] Add([Pitch]$pitch) {
        $n = $pitch.Name
        if (!$this.Records.Contains($n)) {
            $this.Records.$n = [Result]@{ Pitch = $n }
        }
        [Result]$rec = $this.Records.$n
        if ($pitch.FreqDiffAbs -gt $pitch.RightFreq * $this.Threthold) {
            $msg = "Miss!"
            if ($pitch.FreqDiff -gt 0) {
                $rec.HiCount++
                $this.TotalHi++
                if ($pitch.FreqDiff -gt $rec.HiDiff) {
                    $rec.HiDiff = $pitch.FreqDiff
                }
            }
            else {
                $rec.LowCount++
                $this.TotalLow++
                if ($pitch.FreqDiff -lt $rec.LowDiff) {
                    $rec.LowDiff = $pitch.FreqDiff
                }
            }
        }
        else {
            $msg = "Good!"
            $rec.GoodCount++
            $this.TotalGood++
        }
        $this.TotalCount++
        $msg += ' {0:0.0}%' -f ($this.TotalGood * 100 / $this.TotalCount)
        return $msg
    }

    ShowAll() {
        if (!$this.TotalCount) {
            log "!!! NO DATA !!!"
            return
        }
        $overall = @()
        $overall += , [PSCustomObject]@{ Description = "Total Notes"; Count = $this.TotalCount; Ratio = ""; }
        $overall += , [PSCustomObject]@{ Description = "Good"; Count = $this.TotalGood; Ratio = $this.TotalGood / $this.TotalCount * 100 }
        $overall += , [PSCustomObject]@{ Description = "Too Low"; Count = $this.TotalLow; Ratio = $this.TotalLow / $this.TotalCount * 100 }
        $overall += , [PSCustomObject]@{ Description = "Too Hi"; Count = $this.TotalHi; Ratio = $this.TotalHi / $this.TotalCount * 100 }

        log ($overall | Format-Table -AutoSize | Out-String)

        $notes = @()
        foreach ($name in $this.Records.Keys) {
            $r = $this.Records.$name
            $ttl = $r.GoodCount + $r.HiCount + $r.LowCount
            $notes += ,[PSCustomObject]@{
                Name = $name;
                'Good Count' = $r.GoodCount;
                'Good%' = $r.GoodCount / $ttl *100;
                'Too Hi' = $r.HiCount;
                'Too Hi%' = $r.HiCount / $ttl * 100;
                'Max Hi Diff' = $r.HiDiff;
                'Too Low' = $r.LowCount;
                'Too Low%' = $r.LowCount / $ttl * 100;
                'Max Low Diff' = $r.LowDiff
            }
        }
        log ($notes |Sort @{Expression={$_.Name -replace '[^\d]+(\d+).*',"`$1"}},@{Expression={$_.Name -replace '\d',''}}|Format-Table -AutoSize|Out-String)
    }

}

