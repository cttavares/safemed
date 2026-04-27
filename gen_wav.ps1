function Write-Wav {
    param($path, $freq, $duration, $volume)
    $sampleRate = 44100
    $channels = 1
    $bitDepth = 16
    $numSamples = [int]($sampleRate * $duration)
    $byteRate = $sampleRate * $channels * $bitDepth / 8
    $blockAlign = $channels * $bitDepth / 8
    
    $fs = New-Object System.IO.FileStream($path, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter($fs)
    
    $bw.Write([char[]]"RIFF")
    $bw.Write([int](36 + $numSamples * $blockAlign))
    $bw.Write([char[]]"WAVE")
    $bw.Write([char[]]"fmt ")
    $bw.Write([int]16)
    $bw.Write([short]1)
    $bw.Write([short]$channels)
    $bw.Write([int]$sampleRate)
    $bw.Write([int]$byteRate)
    $bw.Write([short]$blockAlign)
    $bw.Write([short]$bitDepth)
    $bw.Write([char[]]"data")
    $bw.Write([int]($numSamples * $blockAlign))
    
    for ($i = 0; $i -lt $numSamples; $i++) {
        $t = $i / $sampleRate
        $sample = [short]($volume * 32767 * [Math]::Sin(2 * [Math]::PI * $freq * $t))
        $bw.Write($sample)
    }
    
    $bw.Dispose()
    $fs.Dispose()
}
Write-Wav "assets\sounds\medication_soft.wav" 523.25 0.35 0.25
Write-Wav "assets\sounds\medication_loud.wav" 880 0.6 0.6
