param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath,
    [switch]$LastRun,
    [int]$RunStartLine = 0
)

$sourceLines = @(Get-Content -LiteralPath $LogPath)
if ($RunStartLine -gt 0 -and $RunStartLine -le $sourceLines.Count) {
    $startIndex = $RunStartLine - 1
    $endIndex = $sourceLines.Count - 1
    for ($index = $startIndex + 1; $index -lt $sourceLines.Count; $index++) {
        if ($sourceLines[$index].Contains('ExecutionEngine initialized for')) {
            $endIndex = $index - 1
            break
        }
    }
    $sourceLines = @($sourceLines[$startIndex..$endIndex])
} elseif ($LastRun) {
    $lastInitialization = -1
    for ($index = $sourceLines.Count - 1; $index -ge 0; $index--) {
        if ($sourceLines[$index].Contains('ExecutionEngine initialized for')) {
            $lastInitialization = $index
            break
        }
    }
    if ($lastInitialization -ge 0) {
        $sourceLines = @($sourceLines[$lastInitialization..($sourceLines.Count - 1)])
    }
}

$records = foreach ($line in $sourceLines) {
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
    if ($fields.status -notin @('CLOSED', 'OPEN')) {
        continue
    }

    $entryDate = [DateTimeOffset]::FromUnixTimeSeconds([long]$fields.entry_time).UtcDateTime
    $trendScore = [double]::Parse($fields.trend_score, [Globalization.CultureInfo]::InvariantCulture)
    [pscustomobject]@{
        Status                 = $fields.status
        PositionId             = [long]$fields.position_id
        EntryTime              = [long]$fields.entry_time
        Hour                   = [int]$fields.hour
        DayOfWeek              = [int]$fields.day_of_week
        Month                  = $entryDate.Month
        Direction              = $fields.direction
        Profit                 = [double]::Parse($fields.profit, [Globalization.CultureInfo]::InvariantCulture)
        HoldingSeconds         = [long]$fields.holding_seconds
        CloseReason            = $fields.close_reason
        TrendScore             = $trendScore
        TrendBucket            = if ($trendScore -lt -20) { 'A_LT_NEG20' }
                                 elseif ($trendScore -lt -10) { 'B_NEG20_NEG10' }
                                 elseif ($trendScore -lt 0) { 'C_NEG10_ZERO' }
                                 elseif ($trendScore -lt 10) { 'D_ZERO_10' }
                                 elseif ($trendScore -lt 20) { 'E_10_20' }
                                 else { 'F_GE_20' }
        TrendStrength          = [double]::Parse($fields.trend_strength, [Globalization.CultureInfo]::InvariantCulture)
        TrendConfidence        = [double]::Parse($fields.trend_confidence, [Globalization.CultureInfo]::InvariantCulture)
        TrendAdx               = [double]::Parse($fields.trend_adx, [Globalization.CultureInfo]::InvariantCulture)
        RangeScore             = [double]::Parse($fields.range_score, [Globalization.CultureInfo]::InvariantCulture)
        RangeWidthPoints       = [double]::Parse($fields.range_width_points, [Globalization.CultureInfo]::InvariantCulture)
        RangePosition          = [double]::Parse($fields.range_position, [Globalization.CultureInfo]::InvariantCulture)
        AtrPoints              = [double]::Parse($fields.atr_points, [Globalization.CultureInfo]::InvariantCulture)
        VolatilityScore        = [double]::Parse($fields.volatility_score, [Globalization.CultureInfo]::InvariantCulture)
        MarketConfidence       = [double]::Parse($fields.market_confidence, [Globalization.CultureInfo]::InvariantCulture)
        SpreadPoints           = [double]::Parse($fields.spread_points, [Globalization.CultureInfo]::InvariantCulture)
        SpreadToAtrRatio       = [double]::Parse($fields.spread_to_atr_ratio, [Globalization.CultureInfo]::InvariantCulture)
        MarketSelectionScore   = [double]::Parse($fields.market_selection_score, [Globalization.CultureInfo]::InvariantCulture)
        MarketSelectionConfidence = [double]::Parse($fields.market_selection_confidence, [Globalization.CultureInfo]::InvariantCulture)
        TradingStyleScore      = [double]::Parse($fields.trading_style_score, [Globalization.CultureInfo]::InvariantCulture)
        TradingStyleConfidence = [double]::Parse($fields.trading_style_confidence, [Globalization.CultureInfo]::InvariantCulture)
        StrategySelectionScore = [double]::Parse($fields.strategy_selection_score, [Globalization.CultureInfo]::InvariantCulture)
        StrategySelectionConfidence = [double]::Parse($fields.strategy_selection_confidence, [Globalization.CultureInfo]::InvariantCulture)
        BoundaryDistancePoints = [double]::Parse($fields.boundary_distance_points, [Globalization.CultureInfo]::InvariantCulture)
        MidpointDistancePoints = [double]::Parse($fields.midpoint_distance_points, [Globalization.CultureInfo]::InvariantCulture)
    }
}

foreach ($record in $records) {
    $contrarianTrend = if ($record.Direction -eq 'BUY') {
        50.0 - (0.5 * $record.TrendScore)
    } else {
        50.0 + (0.5 * $record.TrendScore)
    }
    $contrarianTrend = [Math]::Max(0.0, [Math]::Min(100.0, $contrarianTrend))
    $edgeQuality = if ($record.Direction -eq 'BUY') {
        100.0 * (1.0 - $record.RangePosition)
    } else {
        100.0 * $record.RangePosition
    }
    $edgeQuality = [Math]::Max(0.0, [Math]::Min(100.0, $edgeQuality))
    $confidenceConsensus = (
        $record.MarketSelectionConfidence +
        $record.TradingStyleConfidence +
        $record.StrategySelectionConfidence
    ) / 3.0
    $trendCalm = [Math]::Max(0.0, 100.0 - [Math]::Min(100.0, 2.0 * $record.TrendAdx))
    $compositeScore = (
        0.25 * $contrarianTrend +
        0.20 * $edgeQuality +
        0.20 * $record.RangeScore +
        0.15 * $record.MarketSelectionScore +
        0.10 * $record.VolatilityScore +
        0.10 * $confidenceConsensus
    )
    $compositeCalmScore = (
        0.20 * $contrarianTrend +
        0.15 * $edgeQuality +
        0.15 * $record.RangeScore +
        0.15 * $record.MarketSelectionScore +
        0.10 * $record.VolatilityScore +
        0.10 * $confidenceConsensus +
        0.15 * $trendCalm
    )
    $record | Add-Member -NotePropertyName ContrarianTrendQuality -NotePropertyValue $contrarianTrend
    $record | Add-Member -NotePropertyName EdgeQuality -NotePropertyValue $edgeQuality
    $record | Add-Member -NotePropertyName ConfidenceConsensus -NotePropertyValue $confidenceConsensus
    $record | Add-Member -NotePropertyName TrendCalmQuality -NotePropertyValue $trendCalm
    $record | Add-Member -NotePropertyName CompositeScore -NotePropertyValue $compositeScore
    $record | Add-Member -NotePropertyName CompositeCalmScore -NotePropertyValue $compositeCalmScore
    $record | Add-Member -NotePropertyName CompositeBucket -NotePropertyValue ([Math]::Floor($compositeScore / 5.0) * 5.0)
    $record | Add-Member -NotePropertyName CompositeCalmBucket -NotePropertyValue ([Math]::Floor($compositeCalmScore / 5.0) * 5.0)
}

$closed = @($records | Where-Object Status -eq 'CLOSED')

function Get-GroupStatistics {
    param([object[]]$Rows)
    $wins = @($Rows | Where-Object Profit -gt 0)
    $losses = @($Rows | Where-Object Profit -lt 0)
    $grossProfit = ($wins | Measure-Object Profit -Sum).Sum
    $grossLoss = [Math]::Abs(($losses | Measure-Object Profit -Sum).Sum)
    [pscustomobject]@{
        Trades = $Rows.Count
        Wins = $wins.Count
        Losses = $losses.Count
        WinRate = if ($Rows.Count) { 100.0 * $wins.Count / $Rows.Count } else { 0.0 }
        ProfitFactor = if ($grossLoss -gt 0) { $grossProfit / $grossLoss } elseif ($grossProfit -gt 0) { [double]::PositiveInfinity } else { 0.0 }
        NetProfit = ($Rows | Measure-Object Profit -Sum).Sum
        AverageHolding = ($Rows | Measure-Object HoldingSeconds -Average).Average
    }
}

function Write-GroupedStatistics {
    param([string]$Name, [string]$Property)
    Write-Output "=== $Name ==="
    $closed | Group-Object -Property $Property | Sort-Object {
        if ($_.Name -match '^-?\d+(\.\d+)?$') { [double]$_.Name } else { $_.Name }
    } | ForEach-Object {
        $stats = Get-GroupStatistics @($_.Group)
        '{0}={1};trades={2};wins={3};losses={4};win_rate={5:N2};profit_factor={6:N6};net={7:N2};avg_holding={8:N2}' -f
            $Property, $_.Name, $stats.Trades, $stats.Wins, $stats.Losses,
            $stats.WinRate, $stats.ProfitFactor, $stats.NetProfit, $stats.AverageHolding
    }
}

function Get-Pearson {
    param([object[]]$Rows, [string]$XProperty, [scriptblock]$YSelector)
    if ($Rows.Count -lt 2) { return 0.0 }
    $xMean = ($Rows | Measure-Object -Property $XProperty -Average).Average
    $yValues = @($Rows | ForEach-Object { & $YSelector $_ })
    $yMean = ($yValues | Measure-Object -Average).Average
    $sumXY = 0.0
    $sumXX = 0.0
    $sumYY = 0.0
    for ($index = 0; $index -lt $Rows.Count; $index++) {
        $xDelta = [double]$Rows[$index].$XProperty - $xMean
        $yDelta = [double]$yValues[$index] - $yMean
        $sumXY += $xDelta * $yDelta
        $sumXX += $xDelta * $xDelta
        $sumYY += $yDelta * $yDelta
    }
    if ($sumXX -le 0 -or $sumYY -le 0) { return 0.0 }
    return $sumXY / [Math]::Sqrt($sumXX * $sumYY)
}

function Write-FeatureStatistics {
    param([string]$Property)
    $wins = @($closed | Where-Object Profit -gt 0)
    $losses = @($closed | Where-Object Profit -lt 0)
    $allAverage = ($closed | Measure-Object -Property $Property -Average).Average
    $winAverage = ($wins | Measure-Object -Property $Property -Average).Average
    $lossAverage = ($losses | Measure-Object -Property $Property -Average).Average
    $profitCorrelation = Get-Pearson $closed $Property { param($row) $row.Profit }
    $winCorrelation = Get-Pearson $closed $Property { param($row) if ($row.Profit -gt 0) { 1.0 } else { 0.0 } }
    '{0};all_avg={1:N6};win_avg={2:N6};loss_avg={3:N6};corr_profit={4:N6};corr_win={5:N6}' -f
        $Property, $allAverage, $winAverage, $lossAverage, $profitCorrelation, $winCorrelation
}

Write-Output '=== OVERALL ==='
$overall = Get-GroupStatistics $closed
'records={0};closed={1};open={2};trades={3};wins={4};losses={5};win_rate={6:N2};profit_factor={7:N6};net={8:N2};avg_holding={9:N2}' -f
    $records.Count, $closed.Count, @($records | Where-Object Status -eq 'OPEN').Count,
    $overall.Trades, $overall.Wins, $overall.Losses, $overall.WinRate,
    $overall.ProfitFactor, $overall.NetProfit, $overall.AverageHolding

Write-GroupedStatistics 'BY_DIRECTION' 'Direction'
Write-GroupedStatistics 'BY_HOUR' 'Hour'
Write-GroupedStatistics 'BY_DAY_OF_WEEK' 'DayOfWeek'
Write-GroupedStatistics 'BY_MONTH' 'Month'
Write-GroupedStatistics 'BY_CLOSE_REASON' 'CloseReason'
Write-GroupedStatistics 'BY_TREND_BUCKET' 'TrendBucket'
Write-GroupedStatistics 'BY_COMPOSITE_BUCKET' 'CompositeBucket'
Write-GroupedStatistics 'BY_COMPOSITE_CALM_BUCKET' 'CompositeCalmBucket'

Write-Output '=== BY_DIRECTION_AND_TREND_BUCKET ==='
$closed | Group-Object -Property Direction, TrendBucket | Sort-Object Name | ForEach-Object {
    $stats = Get-GroupStatistics @($_.Group)
    'group={0};trades={1};wins={2};losses={3};win_rate={4:N2};profit_factor={5:N6};net={6:N2};avg_holding={7:N2}' -f
        $_.Name, $stats.Trades, $stats.Wins, $stats.Losses, $stats.WinRate,
        $stats.ProfitFactor, $stats.NetProfit, $stats.AverageHolding
}

Write-Output '=== BY_DIRECTION_AND_HOUR ==='
$closed | Group-Object -Property Direction, Hour | Sort-Object Name | ForEach-Object {
    $stats = Get-GroupStatistics @($_.Group)
    'group={0};trades={1};wins={2};losses={3};win_rate={4:N2};profit_factor={5:N6};net={6:N2};avg_holding={7:N2}' -f
        $_.Name, $stats.Trades, $stats.Wins, $stats.Losses, $stats.WinRate,
        $stats.ProfitFactor, $stats.NetProfit, $stats.AverageHolding
}

Write-Output '=== BY_DIRECTION_AND_DAY_OF_WEEK ==='
$closed | Group-Object -Property Direction, DayOfWeek | Sort-Object Name | ForEach-Object {
    $stats = Get-GroupStatistics @($_.Group)
    'group={0};trades={1};wins={2};losses={3};win_rate={4:N2};profit_factor={5:N6};net={6:N2};avg_holding={7:N2}' -f
        $_.Name, $stats.Trades, $stats.Wins, $stats.Losses, $stats.WinRate,
        $stats.ProfitFactor, $stats.NetProfit, $stats.AverageHolding
}

Write-Output '=== BY_MONTH_AND_DAY_OF_WEEK ==='
$closed | Group-Object -Property Month, DayOfWeek | Sort-Object Name | ForEach-Object {
    $stats = Get-GroupStatistics @($_.Group)
    'group={0};trades={1};wins={2};losses={3};win_rate={4:N2};profit_factor={5:N6};net={6:N2};avg_holding={7:N2}' -f
        $_.Name, $stats.Trades, $stats.Wins, $stats.Losses, $stats.WinRate,
        $stats.ProfitFactor, $stats.NetProfit, $stats.AverageHolding
}

Write-Output '=== FEATURE_AVERAGES_AND_CORRELATIONS ==='
@(
    'TrendScore',
    'TrendStrength',
    'TrendConfidence',
    'TrendAdx',
    'RangeScore',
    'RangeWidthPoints',
    'RangePosition',
    'AtrPoints',
    'VolatilityScore',
    'MarketConfidence',
    'SpreadPoints',
    'SpreadToAtrRatio',
    'MarketSelectionScore',
    'MarketSelectionConfidence',
    'TradingStyleScore',
    'TradingStyleConfidence',
    'StrategySelectionScore',
    'StrategySelectionConfidence',
    'ContrarianTrendQuality',
    'EdgeQuality',
    'ConfidenceConsensus',
    'TrendCalmQuality',
    'CompositeScore',
    'CompositeCalmScore',
    'BoundaryDistancePoints',
    'MidpointDistancePoints',
    'HoldingSeconds'
) | ForEach-Object { Write-FeatureStatistics $_ }

Write-Output '=== COMPOSITE_THRESHOLD_SEARCH ==='
for ($threshold = 60.0; $threshold -le 76.0; $threshold += 0.5) {
    $retained = @($closed | Where-Object CompositeCalmScore -ge $threshold)
    $removed = @($closed | Where-Object CompositeCalmScore -lt $threshold)
    if ($retained.Count -lt 140 -or $removed.Count -lt 5) {
        continue
    }
    $retainedStats = Get-GroupStatistics $retained
    $removedStats = Get-GroupStatistics $removed
    'threshold={0:N1};retained={1};retained_pf={2:N6};retained_net={3:N2};removed={4};removed_pf={5:N6};removed_net={6:N2}' -f
        $threshold, $retainedStats.Trades, $retainedStats.ProfitFactor,
        $retainedStats.NetProfit, $removedStats.Trades,
        $removedStats.ProfitFactor, $removedStats.NetProfit
}

Write-Output '=== SELL_COMPOSITE_THRESHOLD_SEARCH ==='
for ($threshold = 60.0; $threshold -le 76.0; $threshold += 0.5) {
    $retained = @($closed | Where-Object {
        $_.Direction -eq 'BUY' -or $_.CompositeCalmScore -ge $threshold
    })
    $removed = @($closed | Where-Object {
        $_.Direction -eq 'SELL' -and $_.CompositeCalmScore -lt $threshold
    })
    if ($retained.Count -lt 140 -or $removed.Count -lt 5) {
        continue
    }
    $retainedStats = Get-GroupStatistics $retained
    $removedStats = Get-GroupStatistics $removed
    'threshold={0:N1};retained={1};retained_pf={2:N6};retained_net={3:N2};removed={4};removed_pf={5:N6};removed_net={6:N2}' -f
        $threshold, $retainedStats.Trades, $retainedStats.ProfitFactor,
        $retainedStats.NetProfit, $removedStats.Trades,
        $removedStats.ProfitFactor, $removedStats.NetProfit
}

Write-Output '=== SHORTLIST_RULES ==='
$shortlist = @(
    [pscustomobject]@{
        Name = 'ALL_GE_61_5'
        Keep = { param($row) $row.CompositeCalmScore -ge 61.5 }
    },
    [pscustomobject]@{
        Name = 'ALL_GE_66_5'
        Keep = { param($row) $row.CompositeCalmScore -ge 66.5 }
    },
    [pscustomobject]@{
        Name = 'ALL_GE_65_5'
        Keep = { param($row) $row.CompositeCalmScore -ge 65.5 }
    },
    [pscustomobject]@{
        Name = 'SELL_GE_69_5'
        Keep = {
            param($row)
            $row.Direction -eq 'BUY' -or $row.CompositeCalmScore -ge 69.5
        }
    }
)
foreach ($rule in $shortlist) {
    $retained = @($closed | Where-Object { & $rule.Keep $_ })
    $removed = @($closed | Where-Object { -not (& $rule.Keep $_) })
    $retainedStats = Get-GroupStatistics $retained
    $removedStats = Get-GroupStatistics $removed
    $q1Retained = @($retained | Where-Object Month -le 3)
    $q1Removed = @($removed | Where-Object Month -le 3)
    $q1RetainedStats = Get-GroupStatistics $q1Retained
    $q1RemovedStats = Get-GroupStatistics $q1Removed
    'rule={0};annual_retained={1};annual_pf={2:N6};annual_net={3:N2};annual_removed={4};removed_pf={5:N6};removed_net={6:N2};q1_retained={7};q1_pf={8:N6};q1_net={9:N2};q1_removed={10};q1_removed_net={11:N2}' -f
        $rule.Name, $retainedStats.Trades, $retainedStats.ProfitFactor,
        $retainedStats.NetProfit, $removedStats.Trades,
        $removedStats.ProfitFactor, $removedStats.NetProfit,
        $q1RetainedStats.Trades, $q1RetainedStats.ProfitFactor,
        $q1RetainedStats.NetProfit, $q1RemovedStats.Trades,
        $q1RemovedStats.NetProfit

    $removed | Group-Object Month | Sort-Object { [int]$_.Name } | ForEach-Object {
        $monthStats = Get-GroupStatistics @($_.Group)
        'rule={0};removed_month={1};trades={2};pf={3:N6};net={4:N2}' -f
            $rule.Name, $_.Name, $monthStats.Trades,
            $monthStats.ProfitFactor, $monthStats.NetProfit
    }
}

Write-Output '=== LOW_SCORE_ROWS ==='
$closed | Where-Object CompositeCalmScore -lt 67.0 |
    Sort-Object CompositeCalmScore | ForEach-Object {
        'position={0};month={1};hour={2};direction={3};score={4:N6};profit={5:N2};holding={6}' -f
            $_.PositionId, $_.Month, $_.Hour, $_.Direction,
            $_.CompositeCalmScore, $_.Profit, $_.HoldingSeconds
    }
