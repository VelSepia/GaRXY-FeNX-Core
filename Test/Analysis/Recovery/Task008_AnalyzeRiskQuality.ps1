param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath,
    [int]$RunStartLine = 1
)

$ErrorActionPreference = 'Stop'

function Get-Number([hashtable]$Fields, [string]$Name) {
    return [double]::Parse(
        $Fields[$Name],
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function Get-Correlation($Rows, [string]$X, [string]$Y) {
    if ($Rows.Count -lt 2) { return [double]::NaN }
    $meanX = ($Rows | Measure-Object -Property $X -Average).Average
    $meanY = ($Rows | Measure-Object -Property $Y -Average).Average
    $sumXY = 0.0
    $sumXX = 0.0
    $sumYY = 0.0
    foreach ($row in $Rows) {
        $dx = [double]$row.$X - $meanX
        $dy = [double]$row.$Y - $meanY
        $sumXY += $dx * $dy
        $sumXX += $dx * $dx
        $sumYY += $dy * $dy
    }
    if ($sumXX -le 0.0 -or $sumYY -le 0.0) { return [double]::NaN }
    return $sumXY / [Math]::Sqrt($sumXX * $sumYY)
}

function Get-Stats($Rows) {
    $ordered = @($Rows | Sort-Object EntryTime)
    $wins = @($ordered | Where-Object Profit -gt 0.0).Count
    $losses = @($ordered | Where-Object Profit -lt 0.0).Count
    $grossProfit = ($ordered | Where-Object Profit -gt 0.0 |
        Measure-Object -Property Profit -Sum).Sum
    $grossLoss = -1.0 * (($ordered | Where-Object Profit -lt 0.0 |
        Measure-Object -Property Profit -Sum).Sum)
    if ($null -eq $grossProfit) { $grossProfit = 0.0 }
    if ($null -eq $grossLoss) { $grossLoss = 0.0 }
    $net = ($ordered | Measure-Object -Property Profit -Sum).Sum
    if ($null -eq $net) { $net = 0.0 }
    $profitFactor = if ($grossLoss -gt 0.0) { $grossProfit / $grossLoss } else { 999.0 }
    $balance = 0.0
    $peak = 0.0
    $maxDrawdown = 0.0
    foreach ($row in $ordered) {
        $balance += [double]$row.Profit
        if ($balance -gt $peak) { $peak = $balance }
        $drawdown = $peak - $balance
        if ($drawdown -gt $maxDrawdown) { $maxDrawdown = $drawdown }
    }
    $averageHolding = if ($ordered.Count -gt 0) {
        ($ordered | Measure-Object -Property HoldingSeconds -Average).Average
    } else { 0.0 }
    return [pscustomobject]@{
        Trades = $ordered.Count
        Wins = $wins
        Losses = $losses
        WinRate = if ($ordered.Count -gt 0) { 100.0 * $wins / $ordered.Count } else { 0.0 }
        ProfitFactor = $profitFactor
        Net = $net
        Drawdown = $maxDrawdown
        AverageHolding = $averageHolding
    }
}

function Format-Stats([string]$Label, $Stats) {
    return ('{0,-30} n={1,3} win={2,6:N2}% PF={3,7:N4} net={4,8:N2} DD={5,7:N2} hold={6,9:N0}' -f
        $Label, $Stats.Trades, $Stats.WinRate, $Stats.ProfitFactor,
        $Stats.Net, $Stats.Drawdown, $Stats.AverageHolding)
}

$records = [System.Collections.Generic.List[object]]::new()
$lineNumber = 0
foreach ($line in Get-Content -LiteralPath $LogPath) {
    $lineNumber++
    if ($lineNumber -lt $RunStartLine -or $line -notmatch '\[TRADE_ANALYSIS\] status=CLOSED;') {
        continue
    }
    $payload = $line.Substring($line.IndexOf('[TRADE_ANALYSIS]') + 17)
    $fields = @{}
    foreach ($part in $payload.Split(';')) {
        $separator = $part.IndexOf('=')
        if ($separator -gt 0) {
            $fields[$part.Substring(0, $separator).Trim()] =
                $part.Substring($separator + 1).Trim()
        }
    }
    if ($fields['status'] -ne 'CLOSED') { continue }

    $direction = $fields['direction']
    $trendScore = Get-Number $fields 'trend_score'
    $trendAdx = Get-Number $fields 'trend_adx'
    $trendConfidence = Get-Number $fields 'trend_confidence'
    $rangeScore = Get-Number $fields 'range_score'
    $rangePosition = Get-Number $fields 'range_position'
    $volatilityScore = Get-Number $fields 'volatility_score'
    $marketScore = Get-Number $fields 'market_selection_score'
    $marketConfidence = Get-Number $fields 'market_selection_confidence'
    $tradingConfidence = Get-Number $fields 'trading_style_confidence'
    $strategyConfidence = Get-Number $fields 'strategy_selection_confidence'
    $riskScore = Get-Number $fields 'risk_score'
    $riskConfidence = Get-Number $fields 'risk_confidence'
    $spreadPoints = Get-Number $fields 'spread_points'
    $spreadAtr = Get-Number $fields 'spread_to_atr_ratio'

    $contrarianTrend = [Math]::Max(0.0, [Math]::Min(
        100.0, 50.0 + 0.5 * $(if ($direction -eq 'BUY') { -$trendScore } else { $trendScore })
    ))
    $edge = [Math]::Max(0.0, [Math]::Min(
        100.0, 100.0 * $(if ($direction -eq 'BUY') { 1.0 - $rangePosition } else { $rangePosition })
    ))
    $trendCalm = [Math]::Max(0.0, [Math]::Min(100.0, 100.0 - 2.0 * $trendAdx))
    $spreadPointQuality = [Math]::Max(0.0, [Math]::Min(100.0, 100.0 * (1.0 - $spreadPoints / 30.0)))
    $spreadAtrQuality = [Math]::Max(0.0, [Math]::Min(100.0, 100.0 * (1.0 - $spreadAtr / 0.30)))
    $spreadQuality = 0.5 * $spreadPointQuality + 0.5 * $spreadAtrQuality
    $confidenceConsensus = ($marketConfidence + $tradingConfidence + $strategyConfidence) / 3.0
    $confidenceValues = @($marketConfidence, $tradingConfidence, $strategyConfidence, $riskConfidence)
    $confidenceFloor = ($confidenceValues | Measure-Object -Minimum).Minimum
    $confidenceCeiling = ($confidenceValues | Measure-Object -Maximum).Maximum
    $confidenceAgreement = [Math]::Max(0.0, 100.0 - 2.0 * ($confidenceCeiling - $confidenceFloor))
    $riskQuality = [Math]::Max(0.0, [Math]::Min(100.0, 100.0 - $riskScore))

    $trendShare = $trendConfidence / 100.0
    $adaptive =
        (0.10 + 0.10 * $trendShare) * $contrarianTrend +
        (0.10 + 0.05 * $trendShare) * $trendCalm +
        0.10 * $edge +
        0.10 * $rangeScore +
        0.10 * $volatilityScore +
        (0.20 - 0.05 * $trendShare) * $marketScore +
        (0.15 - 0.05 * $trendShare) * $spreadQuality +
        (0.15 - 0.05 * $trendShare) * $confidenceConsensus

    # Candidate final scores use only already-published facts. They leave the
    # Task #006 and #007 gates intact and test alternative final allocations.
    $riskBlend = 0.70 * $adaptive + 0.20 * $riskQuality + 0.10 * $confidenceFloor
    $riskConsensus = 0.60 * $adaptive + 0.20 * $riskQuality +
        0.10 * $confidenceFloor + 0.10 * $spreadQuality
    $balancedQuality = 0.50 * $adaptive + 0.20 * $riskQuality +
        0.15 * $confidenceFloor + 0.10 * $spreadQuality +
        0.05 * $confidenceAgreement

    $entryTime = [DateTimeOffset]::FromUnixTimeSeconds(
        [long](Get-Number $fields 'entry_time')
    ).UtcDateTime
    $profit = Get-Number $fields 'profit'
    $records.Add([pscustomobject]@{
        EntryTime = $entryTime
        Month = $entryTime.Month
        Direction = $direction
        Profit = $profit
        IsWin = if ($profit -gt 0.0) { 1.0 } else { 0.0 }
        HoldingSeconds = Get-Number $fields 'holding_seconds'
        Adaptive = $adaptive
        RiskBlend = $riskBlend
        RiskConsensus = $riskConsensus
        BalancedQuality = $balancedQuality
        RiskScore = $riskScore
        RiskQuality = $riskQuality
        RiskConfidence = $riskConfidence
        SystemRiskScore = Get-Number $fields 'system_risk_score'
        SystemRiskConfidence = Get-Number $fields 'system_risk_confidence'
        Allocation = Get-Number $fields 'allocation_multiplier'
        ConfidenceConsensus = $confidenceConsensus
        ConfidenceFloor = $confidenceFloor
        ConfidenceAgreement = $confidenceAgreement
        TrendScore = $trendScore
        TrendConfidence = $trendConfidence
        RangeScore = $rangeScore
        VolatilityScore = $volatilityScore
        SpreadPoints = $spreadPoints
        SpreadAtr = $spreadAtr
        SpreadQuality = $spreadQuality
        MarketScore = $marketScore
    })
}

if ($records.Count -eq 0) {
    throw 'No closed TRADE_ANALYSIS records were found.'
}

$all = @($records)
$q1 = @($all | Where-Object Month -le 3)
$baselineAnnual = Get-Stats $all
$baselineQ1 = Get-Stats $q1

Write-Output (Format-Stats 'Baseline annual (closed)' $baselineAnnual)
Write-Output (Format-Stats 'Baseline Q1 (closed)' $baselineQ1)
Write-Output ''
Write-Output 'Feature correlations (annual accepted entries):'
foreach ($feature in @(
    'Adaptive', 'RiskScore', 'RiskQuality', 'RiskConfidence',
    'ConfidenceConsensus', 'ConfidenceFloor', 'ConfidenceAgreement',
    'SpreadPoints', 'SpreadAtr', 'SpreadQuality', 'TrendScore',
    'TrendConfidence', 'RangeScore', 'VolatilityScore', 'MarketScore',
    'Allocation'
)) {
    $profitCorrelation = Get-Correlation $all $feature 'Profit'
    $winCorrelation = Get-Correlation $all $feature 'IsWin'
    Write-Output ('  {0,-22} profit={1,9:N5} win={2,9:N5}' -f
        $feature, $profitCorrelation, $winCorrelation)
}

Write-Output ''
Write-Output 'Risk/allocation groups:'
foreach ($group in $all | Group-Object Allocation | Sort-Object Name) {
    Write-Output (Format-Stats ("Allocation=" + $group.Name) (Get-Stats @($group.Group)))
}
foreach ($direction in @('BUY', 'SELL')) {
    Write-Output (Format-Stats $direction (Get-Stats @($all | Where-Object Direction -eq $direction)))
    $directionRows = @($all | Where-Object Direction -eq $direction)
    foreach ($scoreName in @('RiskBlend', 'RiskConsensus', 'BalancedQuality')) {
        $values = @($directionRows | Sort-Object $scoreName |
            Select-Object -ExpandProperty $scoreName)
        $minimumValue = $values[0]
        $p10Value = $values[[Math]::Floor(0.10 * ($values.Count - 1))]
        $medianValue = $values[[Math]::Floor(0.50 * ($values.Count - 1))]
        $maximumValue = $values[$values.Count - 1]
        Write-Output ('  {0,-4} {1,-16} min={2,7:N3} p10={3,7:N3} p50={4,7:N3} max={5,7:N3}' -f
            $direction, $scoreName, $minimumValue, $p10Value, $medianValue, $maximumValue)
    }
}

Write-Output ''
Write-Output 'Worst losses:'
$all | Sort-Object Profit | Select-Object -First 15 |
    Format-Table EntryTime,Direction,Profit,Adaptive,RiskScore,RiskConfidence,
        ConfidenceFloor,SpreadAtr,TrendScore,TrendConfidence,Allocation -AutoSize

Write-Output ''
Write-Output 'Top offline candidate filters (annual closed >= 132; sorted by annual PF):'
$candidateResults = [System.Collections.Generic.List[object]]::new()
foreach ($scoreName in @('RiskBlend', 'RiskConsensus', 'BalancedQuality')) {
    $minimum = [Math]::Floor(($all | Measure-Object -Property $scoreName -Minimum).Minimum * 4.0) / 4.0
    $maximum = [Math]::Ceiling(($all | Measure-Object -Property $scoreName -Maximum).Maximum * 4.0) / 4.0
    for ($threshold = $minimum; $threshold -le $maximum; $threshold += 0.25) {
        foreach ($mode in @('ALL', 'SELL')) {
            $selected = if ($mode -eq 'ALL') {
                @($all | Where-Object { [double]$_.$scoreName -ge $threshold })
            } else {
                @($all | Where-Object {
                    $_.Direction -eq 'BUY' -or [double]$_.$scoreName -ge $threshold
                })
            }
            if ($selected.Count -lt 132) { continue }
            $selectedQ1 = @($selected | Where-Object Month -le 3)
            $annualStats = Get-Stats $selected
            $q1Stats = Get-Stats $selectedQ1
            if ($annualStats.ProfitFactor -le $baselineAnnual.ProfitFactor -or
                $annualStats.Net -le $baselineAnnual.Net) {
                continue
            }
            $candidateResults.Add([pscustomobject]@{
                Score = $scoreName
                Mode = $mode
                Threshold = $threshold
                AnnualTrades = $annualStats.Trades
                AnnualPF = $annualStats.ProfitFactor
                AnnualNet = $annualStats.Net
                AnnualDD = $annualStats.Drawdown
                Q1Trades = $q1Stats.Trades
                Q1PF = $q1Stats.ProfitFactor
                Q1Net = $q1Stats.Net
                Q1DD = $q1Stats.Drawdown
            })
        }
    }
}
$candidateResults |
    Sort-Object @{ Expression = 'AnnualPF'; Descending = $true },
        @{ Expression = 'AnnualNet'; Descending = $true } |
    Select-Object -First 30 |
    Format-Table -AutoSize

Write-Output ''
Write-Output 'Simple SELL risk ceiling search:'
$riskResults = [System.Collections.Generic.List[object]]::new()
for ($ceiling = 10.0; $ceiling -le 30.0; $ceiling += 0.25) {
    $selected = @($all | Where-Object {
        $_.Direction -eq 'BUY' -or $_.RiskScore -le $ceiling
    })
    if ($selected.Count -lt 132) { continue }
    $annualStats = Get-Stats $selected
    $q1Stats = Get-Stats @($selected | Where-Object Month -le 3)
    if ($annualStats.ProfitFactor -gt $baselineAnnual.ProfitFactor -and
        $annualStats.Net -gt $baselineAnnual.Net) {
        $riskResults.Add([pscustomobject]@{
            RiskCeiling = $ceiling
            AnnualTrades = $annualStats.Trades
            AnnualPF = $annualStats.ProfitFactor
            AnnualNet = $annualStats.Net
            AnnualDD = $annualStats.Drawdown
            Q1Trades = $q1Stats.Trades
            Q1PF = $q1Stats.ProfitFactor
            Q1Net = $q1Stats.Net
            Q1DD = $q1Stats.Drawdown
        })
    }
}
$riskResults |
    Sort-Object @{ Expression = 'AnnualPF'; Descending = $true } |
    Select-Object -First 20 |
    Format-Table -AutoSize
