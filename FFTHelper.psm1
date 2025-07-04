#
# FFT helper functions
#
Add-Type -AssemblyName "$env:MathNet\lib\net6.0\MathNet.Numerics.dll"

#
# Create Complex32
#
function NewComplex($r) { [MathNet.Numerics.Complex32]::New([double]$r, 0.0) }

#
# Create complex32[]
#
function SetComplexArray($o, $prop, $n) {
    $o.$prop = [MathNet.Numerics.Complex32[]]::New($n)
}

#
# Window
#
function GetWindow($n) {
    [MathNet.Numerics.Window]::Hann($n)
}

#
# Perform FFT
#
function FFT_Forward($cmp) { [MathNet.Numerics.IntegralTransforms.Fourier]::Forward($cmp) }
