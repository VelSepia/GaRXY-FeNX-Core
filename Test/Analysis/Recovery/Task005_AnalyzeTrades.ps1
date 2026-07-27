param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath,
    [switch]$LastRun
)

$sourceLines = @(Get-Content -LiteralPath $LogPath)
if ($LastRun) {
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
        RangeScore             = [double]::Parse($fields.range_score, [Globalization.CultureInfo]::InvariantCulture)
        RangeWidthPoints       = [double]::Parse($fields.range_width_points, [Globalization.CultureInfo]::InvariantCulture)
        AtrPoints              = [double]::Parse($fields.atr_points, [Globalization.CultureInfo]::InvariantCulture)
        VolatilityScore        = [double]::Parse($fields.volatility_score, [Globalization.CultureInfo]::InvariantCulture)
        MarketConfidence       = [double]::Parse($fields.market_confidence, [Globalization.CultureInfo]::InvariantCulture)
        SpreadPoints           = [double]::Parse($fields.spread_points, [Globalization.CultureInfo]::InvariantCulture)
        BoundaryDistancePoints = [double]::Parse($fields.boundary_distance_points, [Globalization.CultureInfo]::InvariantCulture)
        MidpointDistancePoints = [double]::Parse($fields.midpoint_distance_points, [Globalization.CultureInfo]::InvariantCulture)
    }
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
    'RangeScore',
    'RangeWidthPoints',
    'AtrPoints',
    'VolatilityScore',
    'MarketConfidence',
    'SpreadPoints',
    'BoundaryDistancePoints',
    'MidpointDistancePoints',
    'HoldingSeconds'
) | ForEach-Object { Write-FeatureStatistics $_ }
