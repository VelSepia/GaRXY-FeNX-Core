param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath,
    [Parameter(Mandatory = $true)]
    [int]$RunStartLine
)

$culture = [Globalization.CultureInfo]::InvariantCulture
$sourceLines = @(Get-Content -LiteralPath $LogPath)
$startIndex = $RunStartLine - 1
$endIndex = $sourceLines.Count - 1
for ($index = $startIndex + 1; $index -lt $sourceLines.Count; $index++) {
    if ($sourceLines[$index].Contains('ExecutionEngine initialized for')) {
        $endIndex = $index - 1
        break
    }
}
$runLines = @($sourceLines[$startIndex..$endIndex])

$records = foreach ($line in $runLines) {
    $marker = $line.IndexOf('[TRADE_ANALYSIS] ')
    if ($marker -lt 0) {
        continue
    }
    $fields = @{}
    $payload = $line.Substring($marker + '[TRADE_ANALYSIS] '.Length)
    foreach ($part in $payload.Split(';')) {
        $separator = $part.IndexOf('=')
        if ($separator -gt 0) {
            $fields[$part.Substring(0, $separator)] = $part.Substring($separator + 1)
        }
    }
    if ($fields.status -ne 'CLOSED') {
        continue
    }

    $direction = $fields.direction
    $trendScore = [double]::Parse($fields.trend_score, $culture)
    $trendAdx = [double]::Parse($fields.trend_adx, $culture)
    $trendConfidence = [double]::Parse($fields.trend_confidence, $culture)
    $rangeScore = [double]::Parse($fields.range_score, $culture)
    $rangePosition = [double]::Parse($fields.range_position, $culture)
    $volatilityScore = [double]::Parse($fields.volatility_score, $culture)
    $marketScore = [double]::Parse($fields.market_selection_score, $culture)
    $marketSelectionConfidence =
        [double]::Parse($fields.market_selection_confidence, $culture)
    $tradingStyleConfidence =
        [double]::Parse($fields.trading_style_confidence, $culture)
    $strategySelectionConfidence =
        [double]::Parse($fields.strategy_selection_confidence, $culture)
    $spreadPoints = [double]::Parse($fields.spread_points, $culture)
    $spreadToAtr = [double]::Parse($fields.spread_to_atr_ratio, $culture)
    $contrarianTrend = if ($direction -eq 'BUY') {
        50.0 - (0.5 * $trendScore)
    } else {
        50.0 + (0.5 * $trendScore)
    }
    $contrarianTrend = [Math]::Max(0.0, [Math]::Min(100.0, $contrarianTrend))
    $edgeQuality = if ($direction -eq 'BUY') {
        100.0 * (1.0 - $rangePosition)
    } else {
        100.0 * $rangePosition
    }
    $edgeQuality = [Math]::Max(0.0, [Math]::Min(100.0, $edgeQuality))
    $trendCalm = [Math]::Max(0.0, 100.0 - [Math]::Min(100.0, 2.0 * $trendAdx))
    $confidenceConsensus = (
        $marketSelectionConfidence +
        $tradingStyleConfidence +
        $strategySelectionConfidence
    ) / 3.0
    $spreadPointQuality =
        [Math]::Max(0.0, [Math]::Min(100.0, 100.0 * (1.0 - $spreadPoints / 30.0)))
    $spreadAtrQuality =
        [Math]::Max(0.0, [Math]::Min(100.0, 100.0 * (1.0 - $spreadToAtr / 0.30)))
    $spreadQuality = 0.50 * $spreadPointQuality + 0.50 * $spreadAtrQuality

    $entryDate = [DateTimeOffset]::FromUnixTimeSeconds(
        [long]$fields.entry_time
    ).UtcDateTime
    [pscustomobject]@{
        PositionId = [long]$fields.position_id
        Month = $entryDate.Month
        Quarter = [int][Math]::Floor(($entryDate.Month - 1) / 3) + 1
        Direction = $direction
        Profit = [double]::Parse($fields.profit, $culture)
        HoldingSeconds = [long]$fields.holding_seconds
        ContrarianTrend = $contrarianTrend
        TrendCalm = $trendCalm
        TrendConfidence = $trendConfidence
        EdgeQuality = $edgeQuality
        RangeScore = $rangeScore
        VolatilityScore = $volatilityScore
        MarketScore = $marketScore
        MarketConfidence = $marketSelectionConfidence
        ConfidenceConsensus = $confidenceConsensus
        SpreadQuality = $spreadQuality
    }
}

function Get-Stats {
    param([object[]]$Rows)
    $wins = @($Rows | Where-Object Profit -gt 0)
    $losses = @($Rows | Where-Object Profit -lt 0)
    $grossProfit = ($wins | Measure-Object Profit -Sum).Sum
    $grossLoss = [Math]::Abs(($losses | Measure-Object Profit -Sum).Sum)
    [pscustomobject]@{
        Trades = $Rows.Count
        ProfitFactor = if ($grossLoss -gt 0) {
            $grossProfit / $grossLoss
        } elseif ($grossProfit -gt 0) {
            [double]::PositiveInfinity
        } else {
            0.0
        }
        NetProfit = ($Rows | Measure-Object Profit -Sum).Sum
        WinRate = if ($Rows.Count) {
            100.0 * $wins.Count / $Rows.Count
        } else {
            0.0
        }
    }
}

foreach ($row in $records) {
    $task006 = (
        0.20 * $row.ContrarianTrend +
        0.15 * $row.EdgeQuality +
        0.15 * $row.RangeScore +
        0.15 * $row.MarketScore +
        0.10 * $row.VolatilityScore +
        0.10 * $row.ConfidenceConsensus +
        0.15 * $row.TrendCalm
    )

    $explicitSpread = (
        0.18 * $row.ContrarianTrend +
        0.12 * $row.EdgeQuality +
        0.15 * $row.RangeScore +
        0.15 * $row.MarketScore +
        0.10 * $row.VolatilityScore +
        0.08 * $row.ConfidenceConsensus +
        0.12 * $row.TrendCalm +
        0.10 * $row.SpreadQuality
    )

    # Confidence scales the influence of its source. The score is normalized
    # so low confidence transfers influence to the other available evidence
    # instead of becoming an independent hard rejection.
    $trendReliability = 0.50 + 0.50 * ($row.TrendConfidence / 100.0)
    $rangeReliability = 0.50 + 0.50 * ($row.RangeScore / 100.0)
    $marketReliability = 0.50 + 0.50 * ($row.MarketConfidence / 100.0)
    $weights = @(
        (0.20 * $trendReliability),
        (0.15 * $trendReliability),
        (0.15 * $rangeReliability),
        (0.15 * $rangeReliability),
        0.10,
        (0.10 * $marketReliability),
        (0.10 * $marketReliability),
        0.05
    )
    $values = @(
        $row.ContrarianTrend,
        $row.TrendCalm,
        $row.EdgeQuality,
        $row.RangeScore,
        $row.VolatilityScore,
        $row.MarketScore,
        $row.SpreadQuality,
        $row.ConfidenceConsensus
    )
    $weightTotal = ($weights | Measure-Object -Sum).Sum
    $adaptiveReliability = 0.0
    for ($weightIndex = 0; $weightIndex -lt $weights.Count; $weightIndex++) {
        $adaptiveReliability += $weights[$weightIndex] * $values[$weightIndex]
    }
    $adaptiveReliability /= $weightTotal

    # A high-confidence directional signal receives more Trend evidence;
    # neutral/noisy Trend output shifts the same weight toward Range evidence.
    $trendShare = $row.TrendConfidence / 100.0
    $adaptiveRegime = (
        (0.10 + 0.15 * $trendShare) * $row.ContrarianTrend +
        (0.10 + 0.10 * $trendShare) * $row.TrendCalm +
        (0.20 - 0.05 * $trendShare) * $row.EdgeQuality +
        (0.20 - 0.10 * $trendShare) * $row.RangeScore +
        0.10 * $row.VolatilityScore +
        0.10 * $row.MarketScore +
        0.05 * $row.SpreadQuality +
        0.05 * $row.ConfidenceConsensus
    )

    # When Trend has weak confidence, execution-quality evidence (Market,
    # Spread, and cross-engine Confidence) receives the released weight.
    # Confident Trend output gradually earns that weight back.
    $adaptiveMarket = (
        (0.10 + 0.10 * $trendShare) * $row.ContrarianTrend +
        (0.10 + 0.05 * $trendShare) * $row.TrendCalm +
        0.10 * $row.EdgeQuality +
        0.10 * $row.RangeScore +
        0.10 * $row.VolatilityScore +
        (0.20 - 0.05 * $trendShare) * $row.MarketScore +
        (0.15 - 0.05 * $trendShare) * $row.SpreadQuality +
        (0.15 - 0.05 * $trendShare) * $row.ConfidenceConsensus
    )

    # Confidence is also scored as evidence, not only used as a weight switch.
    # This prevents a temporarily improved Spread from fully masking an
    # unconfirmed directional snapshot.
    $adaptiveConfidence = (
        (0.10 + 0.10 * $trendShare) * $row.ContrarianTrend +
        (0.10 + 0.05 * $trendShare) * $row.TrendCalm +
        0.10 * $row.EdgeQuality +
        0.10 * $row.RangeScore +
        0.10 * $row.VolatilityScore +
        (0.15 - 0.05 * $trendShare) * $row.MarketScore +
        (0.15 - 0.05 * $trendShare) * $row.SpreadQuality +
        (0.10 - 0.05 * $trendShare) * $row.ConfidenceConsensus +
        (0.10 * $row.TrendConfidence)
    )

    $row | Add-Member Task006Score $task006
    $row | Add-Member ExplicitSpreadScore $explicitSpread
    $row | Add-Member AdaptiveReliabilityScore $adaptiveReliability
    $row | Add-Member AdaptiveRegimeScore $adaptiveRegime
    $row | Add-Member AdaptiveMarketScore $adaptiveMarket
    $row | Add-Member AdaptiveConfidenceScore $adaptiveConfidence
}

$baseline = Get-Stats @($records)
'baseline;trades={0};pf={1:N6};net={2:N2};win_rate={3:N2}' -f `
    $baseline.Trades, $baseline.ProfitFactor, $baseline.NetProfit, $baseline.WinRate

$scoreNames = @(
    'Task006Score',
    'ExplicitSpreadScore',
    'AdaptiveReliabilityScore',
    'AdaptiveRegimeScore',
    'AdaptiveMarketScore',
    'AdaptiveConfidenceScore'
)
foreach ($scoreName in $scoreNames) {
    "=== $scoreName ==="
    $candidates = @()
    for ($threshold = 60.0; $threshold -le 85.0; $threshold += 0.25) {
        foreach ($sellOnly in @($false, $true)) {
            $kept = @($records | Where-Object {
                if ($sellOnly -and $_.Direction -ne 'SELL') {
                    $true
                } else {
                    $_.$scoreName -ge $threshold
                }
            })
            $removed = @($records | Where-Object {
                if ($sellOnly -and $_.Direction -ne 'SELL') {
                    $false
                } else {
                    $_.$scoreName -lt $threshold
                }
            })
            $q1 = @($kept | Where-Object Quarter -eq 1)
            if ($kept.Count -lt 135 -or $removed.Count -lt 4 -or $q1.Count -lt 38) {
                continue
            }
            $keptStats = Get-Stats $kept
            $removedStats = Get-Stats $removed
            $q1Stats = Get-Stats $q1
            $quarterNets = @()
            for ($quarter = 1; $quarter -le 4; $quarter++) {
                $quarterRows = @($kept | Where-Object Quarter -eq $quarter)
                $quarterNets += (Get-Stats $quarterRows).NetProfit
            }
            $robustness = ($quarterNets | Measure-Object -Minimum).Minimum
            $objective = (
                25.0 * $keptStats.ProfitFactor +
                $keptStats.NetProfit +
                10.0 * $q1Stats.ProfitFactor +
                0.25 * $q1Stats.NetProfit +
                0.15 * $robustness
            )
            $candidates += [pscustomobject]@{
                Score = $scoreName
                Scope = if ($sellOnly) { 'SELL' } else { 'ALL' }
                Threshold = $threshold
                Trades = $keptStats.Trades
                PF = $keptStats.ProfitFactor
                Net = $keptStats.NetProfit
                Removed = $removedStats.Trades
                RemovedPF = $removedStats.ProfitFactor
                RemovedNet = $removedStats.NetProfit
                Q1Trades = $q1Stats.Trades
                Q1PF = $q1Stats.ProfitFactor
                Q1Net = $q1Stats.NetProfit
                MinQuarterNet = $robustness
                QuarterNets = ($quarterNets | ForEach-Object { '{0:N2}' -f $_ }) -join ','
                Objective = $objective
            }
        }
    }
    $candidates |
        Where-Object {
            $_.PF -gt $baseline.ProfitFactor -and
            $_.Net -gt $baseline.NetProfit -and
            $_.RemovedNet -lt 0.0
        } |
        Sort-Object Objective -Descending |
        Select-Object -First 12 |
        ForEach-Object {
            'scope={0};threshold={1:N2};trades={2};pf={3:N6};net={4:N2};removed={5};removed_pf={6:N6};removed_net={7:N2};q1_trades={8};q1_pf={9:N6};q1_net={10:N2};min_quarter_net={11:N2};quarter_nets={12}' -f `
                $_.Scope, $_.Threshold, $_.Trades, $_.PF, $_.Net, $_.Removed,
                $_.RemovedPF, $_.RemovedNet, $_.Q1Trades, $_.Q1PF, $_.Q1Net,
                $_.MinQuarterNet, $_.QuarterNets
        }
}

'=== ADAPTIVE_REGIME_BELOW_61 ==='
$records |
    Where-Object AdaptiveRegimeScore -lt 61.0 |
    Sort-Object AdaptiveRegimeScore |
    ForEach-Object {
        'position={0};month={1};quarter={2};direction={3};score={4:N6};profit={5:N2};trend_confidence={6:N2};trend={7:N2};calm={8:N2};edge={9:N2};range={10:N2};volatility={11:N2};market={12:N2};spread={13:N2};confidence={14:N2}' -f `
            $_.PositionId, $_.Month, $_.Quarter, $_.Direction,
            $_.AdaptiveRegimeScore, $_.Profit, $_.TrendConfidence,
            $_.ContrarianTrend, $_.TrendCalm, $_.EdgeQuality, $_.RangeScore,
            $_.VolatilityScore, $_.MarketScore, $_.SpreadQuality,
            $_.ConfidenceConsensus
    }

'=== LOWEST_ADAPTIVE_MARKET ==='
$records |
    Sort-Object AdaptiveMarketScore |
    Select-Object -First 12 |
    ForEach-Object {
        'position={0};month={1};quarter={2};direction={3};score={4:N6};profit={5:N2};trend_confidence={6:N2};market={7:N2};spread={8:N2};volatility={9:N2}' -f `
            $_.PositionId, $_.Month, $_.Quarter, $_.Direction,
            $_.AdaptiveMarketScore, $_.Profit, $_.TrendConfidence,
            $_.MarketScore, $_.SpreadQuality, $_.VolatilityScore
    }

'=== LOWEST_ADAPTIVE_CONFIDENCE ==='
$records |
    Sort-Object AdaptiveConfidenceScore |
    Select-Object -First 15 |
    ForEach-Object {
        'position={0};month={1};quarter={2};direction={3};score={4:N6};profit={5:N2};trend_confidence={6:N2};market={7:N2};spread={8:N2};volatility={9:N2}' -f `
            $_.PositionId, $_.Month, $_.Quarter, $_.Direction,
            $_.AdaptiveConfidenceScore, $_.Profit, $_.TrendConfidence,
            $_.MarketScore, $_.SpreadQuality, $_.VolatilityScore
    }
