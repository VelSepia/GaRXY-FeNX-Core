param(
    [Parameter(Mandatory = $true)]
    [string]$ReportsDirectory,

    [Parameter(Mandatory = $true)]
    [string]$EvidenceDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function ConvertTo-InvariantNumber([string]$Text) {
    $normalized = ($Text -replace '[^\d\.\-]', '')
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return 0.0
    }
    return [double]::Parse(
        $normalized,
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function ConvertFrom-KeyValuePayload([string]$Line, [string]$Marker) {
    $markerIndex = $Line.IndexOf($Marker)
    if ($markerIndex -lt 0) {
        throw "Marker '$Marker' was not found."
    }

    $fields = @{}
    $payload = $Line.Substring($markerIndex + $Marker.Length).Trim()
    foreach ($part in $payload.Split(';')) {
        $separator = $part.IndexOf('=')
        if ($separator -gt 0) {
            $fields[$part.Substring(0, $separator).Trim()] =
                $part.Substring($separator + 1).Trim()
        }
    }
    return $fields
}

function Get-RequiredField([hashtable]$Fields, [string]$Name) {
    if (-not $Fields.ContainsKey($Name)) {
        throw "Required field '$Name' was not found."
    }
    return $Fields[$Name]
}

function Get-HtmlRows([string]$ReportPath) {
    $html = Get-Content -LiteralPath $ReportPath -Raw
    $rows = [System.Collections.Generic.List[object]]::new()

    foreach ($rowMatch in [regex]::Matches(
        $html,
        '(?is)<tr\b[^>]*>(.*?)</tr>'
    )) {
        $cells = [System.Collections.Generic.List[string]]::new()
        foreach ($cellMatch in [regex]::Matches(
            $rowMatch.Groups[1].Value,
            '(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>'
        )) {
            $text = [regex]::Replace(
                $cellMatch.Groups[1].Value,
                '(?is)<[^>]+>',
                ' '
            )
            $text = [System.Net.WebUtility]::HtmlDecode($text)
            $cells.Add(($text -replace '\s+', ' ').Trim())
        }
        if ($cells.Count -gt 0) {
            $rows.Add([pscustomobject]@{
                Cells = @($cells)
            })
        }
    }
    return @($rows)
}

function Get-ConsecutiveCount($Rows, [int]$ValueIndex) {
    foreach ($row in $Rows) {
        $cells = $row.Cells
        # The localized Strategy Tester report places the maximum consecutive
        # win/loss counts in columns 2 and 4. Match the row by its language-
        # independent value shape instead of depending on translated labels.
        if ($cells.Count -ge 5 -and
            $cells[2] -match '^\s*(\d+)\s+\([+-]?\d' -and
            $cells[4] -match '^\s*(\d+)\s+\([+-]?\d') {
            if ($cells[$ValueIndex] -match '^\s*(\d+)') {
                return [int]$Matches[1]
            }
        }
    }
    throw "Consecutive trade count was not found in the report."
}

function Get-DealRows($Rows) {
    $deals = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $Rows) {
        $cells = $row.Cells
        if ($cells.Count -ne 13 -or
            $cells[0] -notmatch '^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}$' -or
            $cells[4] -notin @('in', 'out')) {
            continue
        }

        $time = [DateTime]::ParseExact(
            $cells[0],
            'yyyy.MM.dd HH:mm:ss',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $deals.Add([pscustomobject]@{
            Time = $time
            Entry = $cells[4]
            Commission = ConvertTo-InvariantNumber $cells[8]
            Swap = ConvertTo-InvariantNumber $cells[9]
            Profit = ConvertTo-InvariantNumber $cells[10]
        })
    }
    return @($deals)
}

function Get-PeriodStatistics(
    [string]$Period,
    [string]$Bucket,
    $Deals
) {
    $closed = @($Deals | Where-Object Entry -eq 'out')
    $closedNet = @($closed | ForEach-Object {
        $_.Commission + $_.Swap + $_.Profit
    })
    $grossProfit = ($closedNet | Where-Object { $_ -gt 0.0 } |
        Measure-Object -Sum).Sum
    $grossLoss = -1.0 * (($closedNet | Where-Object { $_ -lt 0.0 } |
        Measure-Object -Sum).Sum)
    if ($null -eq $grossProfit) { $grossProfit = 0.0 }
    if ($null -eq $grossLoss) { $grossLoss = 0.0 }

    $netProfit = ($Deals | ForEach-Object {
        $_.Commission + $_.Swap + $_.Profit
    } | Measure-Object -Sum).Sum
    if ($null -eq $netProfit) { $netProfit = 0.0 }

    return [pscustomobject]@{
        Period = $Period
        Bucket = $Bucket
        Trades = $closed.Count
        Wins = @($closedNet | Where-Object { $_ -gt 0.0 }).Count
        Losses = @($closedNet | Where-Object { $_ -lt 0.0 }).Count
        WinRatePercent = if ($closed.Count -gt 0) {
            [Math]::Round(
                100.0 * @($closedNet | Where-Object { $_ -gt 0.0 }).Count /
                    $closed.Count,
                2
            )
        } else {
            0.0
        }
        GrossProfit = [Math]::Round($grossProfit, 2)
        GrossLoss = [Math]::Round($grossLoss, 2)
        NetProfit = [Math]::Round($netProfit, 2)
        ProfitFactor = if ($grossLoss -gt 0.0) {
            [Math]::Round($grossProfit / $grossLoss, 6)
        } elseif ($grossProfit -gt 0.0) {
            [double]::PositiveInfinity
        } else {
            0.0
        }
    }
}

$definitions = @(
    [pscustomobject]@{ Period = '2021'; Report = 'task009-2021.htm'; Evidence = 'task009-2021-evidence.log' },
    [pscustomobject]@{ Period = '2022'; Report = 'task009-2022.htm'; Evidence = 'task009-2022-evidence.log' },
    [pscustomobject]@{ Period = '2023'; Report = 'task009-2023.htm'; Evidence = 'task009-2023-evidence.log' },
    [pscustomobject]@{ Period = '2024'; Report = 'task009-2024.htm'; Evidence = 'task009-2024-evidence.log' },
    [pscustomobject]@{ Period = '2025'; Report = 'task009-2025.htm'; Evidence = 'task009-2025-evidence.log' },
    [pscustomobject]@{ Period = '2016-2025'; Report = 'task009-2016-2025.htm'; Evidence = 'task009-2016-2025-evidence.log' }
)

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$summary = [System.Collections.Generic.List[object]]::new()
$pipeline = [System.Collections.Generic.List[object]]::new()
$monthly = [System.Collections.Generic.List[object]]::new()
$yearly = [System.Collections.Generic.List[object]]::new()
$checksums = [System.Collections.Generic.List[object]]::new()

foreach ($definition in $definitions) {
    $reportPath = Join-Path $ReportsDirectory $definition.Report
    $evidencePath = Join-Path $EvidenceDirectory $definition.Evidence
    if (-not (Test-Path -LiteralPath $reportPath)) {
        throw "Missing report: $reportPath"
    }
    if (-not (Test-Path -LiteralPath $evidencePath)) {
        throw "Missing evidence: $evidencePath"
    }

    $evidenceLines = @(Get-Content -LiteralPath $evidencePath)
    $metricsLine = @($evidenceLines |
        Where-Object { $_.Contains('[BACKTEST_METRICS]') })[-1]
    $executionLine = @($evidenceLines |
        Where-Object { $_.Contains('[BACKTEST_EXECUTION]') })[-1]
    $metrics = ConvertFrom-KeyValuePayload $metricsLine '[BACKTEST_METRICS]'
    $execution = ConvertFrom-KeyValuePayload $executionLine '[BACKTEST_EXECUTION]'

    $rows = Get-HtmlRows $reportPath
    $deals = Get-DealRows $rows
    $maxConsecutiveWins = Get-ConsecutiveCount $rows 2
    $maxConsecutiveLosses = Get-ConsecutiveCount $rows 4

    $riskStops = @($evidenceLines | Where-Object {
        $_.Contains('State transition:') -and $_.Contains(' -> RISK_STOP.')
    }).Count
    $riskRecoveries = @($evidenceLines | Where-Object {
        $_.Contains('State transition: RISK_STOP -> STANDBY.')
    }).Count

    $summary.Add([pscustomobject]@{
        Period = $definition.Period
        Trades = [int](Get-RequiredField $metrics 'trades')
        Wins = [int](Get-RequiredField $metrics 'wins')
        Losses = [int](Get-RequiredField $metrics 'losses')
        WinRatePercent = [double](Get-RequiredField $metrics 'win_rate')
        ProfitFactor = [double](Get-RequiredField $metrics 'profit_factor')
        NetProfit = [double](Get-RequiredField $metrics 'net_profit')
        BalanceDrawdown = [double](Get-RequiredField $metrics 'balance_drawdown')
        BalanceDrawdownPercent = [double](Get-RequiredField $metrics 'balance_drawdown_percent')
        EquityDrawdown = [double](Get-RequiredField $metrics 'equity_drawdown')
        EquityDrawdownPercent = [double](Get-RequiredField $metrics 'equity_drawdown_percent')
        AverageHoldingSeconds = [double](Get-RequiredField $metrics 'average_holding_seconds')
        MaxConsecutiveWins = $maxConsecutiveWins
        MaxConsecutiveLosses = $maxConsecutiveLosses
        RiskStopActivations = $riskStops
        RiskStopRecoveries = $riskRecoveries
        OrdersRequested = [int](Get-RequiredField $execution 'orders_requested')
        OrdersAccepted = [int](Get-RequiredField $execution 'orders_accepted')
        OrdersRejected = [int](Get-RequiredField $execution 'orders_rejected')
        ClosesRequested = [int](Get-RequiredField $execution 'closes_requested')
        ClosesAccepted = [int](Get-RequiredField $execution 'closes_accepted')
        ClosesRejected = [int](Get-RequiredField $execution 'closes_rejected')
        EntryRetries = [int](Get-RequiredField $execution 'entry_retries')
        CloseRetries = [int](Get-RequiredField $execution 'close_retries')
        PositionOpenEvents = [int](Get-RequiredField $execution 'position_open_events')
        PositionCloseEvents = [int](Get-RequiredField $execution 'position_close_events')
    })

    foreach ($line in $evidenceLines |
        Where-Object { $_.Contains('[BACKTEST_PIPELINE]') }) {
        $fields = ConvertFrom-KeyValuePayload $line '[BACKTEST_PIPELINE]'
        $pipeline.Add([pscustomobject]@{
            Period = $definition.Period
            Stage = Get-RequiredField $fields 'stage'
            BlockedTicks = [long](Get-RequiredField $fields 'blocked_ticks')
            BlockEvents = [long](Get-RequiredField $fields 'block_events')
        })
    }

    foreach ($group in $deals | Group-Object {
        $_.Time.ToString('yyyy-MM')
    } | Sort-Object Name) {
        $monthly.Add((Get-PeriodStatistics `
            $definition.Period `
            $group.Name `
            @($group.Group)))
    }

    if ($definition.Period -eq '2016-2025') {
        foreach ($group in $deals | Group-Object {
            $_.Time.ToString('yyyy')
        } | Sort-Object Name) {
            $yearly.Add((Get-PeriodStatistics `
                $definition.Period `
                $group.Name `
                @($group.Group)))
        }
    }

    foreach ($artifact in @($reportPath, $evidencePath)) {
        $hash = Get-FileHash -LiteralPath $artifact -Algorithm SHA256
        $checksums.Add([pscustomobject]@{
            Period = $definition.Period
            File = Split-Path -Leaf $artifact
            Sha256 = $hash.Hash
        })
    }
}

$summary | Export-Csv -LiteralPath (
    Join-Path $OutputDirectory 'task009-summary.csv'
) -NoTypeInformation -Encoding UTF8
$pipeline | Export-Csv -LiteralPath (
    Join-Path $OutputDirectory 'task009-pipeline.csv'
) -NoTypeInformation -Encoding UTF8
$monthly | Export-Csv -LiteralPath (
    Join-Path $OutputDirectory 'task009-monthly-profit.csv'
) -NoTypeInformation -Encoding UTF8
$yearly | Export-Csv -LiteralPath (
    Join-Path $OutputDirectory 'task009-long-run-yearly-profit.csv'
) -NoTypeInformation -Encoding UTF8
$checksums | Export-Csv -LiteralPath (
    Join-Path $OutputDirectory 'task009-evidence-checksums.csv'
) -NoTypeInformation -Encoding UTF8

$summary | Format-Table -AutoSize
