# This should run once all the jobs are done
function Complete-ToolkitJobs {
    param (
        $JobList
        )

    foreach ($job in $JobList) {
        try {
            # Collect result
            $result = $job.PowerShell.EndInvoke($job.Handle)

            if ($result) {
                # Dispose the runspace first (Crucial for GUI stability)
                # In a RunspacePool, the runspace is managed by the pool,
                # but if you assigned it directly , you must call dispose here.
                # if ($job.PowerShell.Runspace) {
                #     $job.PowerShell.Runspace.Dispose()
                # }

                # Cleanup individual PowerShell insance
                $job.PowerShell.Dispose()
            }
        } catch {}
    }
    foreach ($job in $JobList) {        
        # Dispose of the shared Pool (The "Big" Cleanup)
        # Only do this when the entire batch is finished
        if ($job.Pool) {
            $job.Pool.Close()
            $job.Pool.Dispose()
        }
    }
    
    $JobList.Clear()
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()
}

# Create the Pool using manifest values
function Get-RunspacePool {
    param (
        $minThreads = 1, 
        $maxThreads = $Config.Runtime.maxThreads
    )

    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

    # Explicitly add the variable so that the module can see it upon import
    $iss.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList "Config", $Config, "Global variable for module"))

    $pool                = [runspacefactory]::CreateRunspacePool($iss)
    $pool.ApartmentState = "MTA"
    # Doesn't exist $pool.SetMinRunspaces($minThreads) 
    try {
        $null = $pool.SetMaxRunspaces($maxThreads)
    } catch {
        Write-Error $_.Exception.Message
    }
    $pool.Open()

    return $pool
}

function New-Runspace {
    param ([psobject]$StatusLabel)
    
    # Example: Running multiple tasks based on manifest limits
    $Script:jobs    = New-Object System.Collections.Generic.List[object]
    $Timer          = New-Object System.Windows.Threading.DispatcherTimer
    $Timer.Interval = [TimeSpan]::FromSeconds(5)

    $Timer.Add_Tick({
        param ($s, $e)
        
        # Check if all jobs in the list are done
        $stillRunning = $Script:jobs | Where-Object { $_.PowerShell.InvocationStateInfo.State -notin @('Completed', 'Failed', 'Stopped') }

        if (-not $stillRunning) {
            $s.Stop()

            # Collect results and cleanup
            Complete-ToolkitJobs -JobList $Script:jobs

            $StatusLabel.Content = "Status: Completed" 
        } 
    })

    [PSCustomObject]@{
        Jobs    = $Script:jobs
        Timer   = $Timer
    }
}

function Start-EngineRunspace {
    param (
        [scriptblock]$script, 
        [object[]]$Arguments
    )

    $ps                 = [powershell]::Create()
    $ps.RunspacePool    = Get-RunspacePool
    $ps.AddScript($script)
    
    if ($Arguments) {
        foreach ($arg in $Arguments) {
            $ps.AddArgument($arg)
        }
    }

    # return everything so you can clean up later
    [PSCustomObject]@{
        PowerShell  = $ps
        Pool        = $ps.RunspacePool
        Handle      = $ps.BeginInvoke()
        State       = $ps.InvocationStateInfo.State
    }
}

Export-ModuleMember -Function Complete-ToolkitJobs, Get-RunspacePool, New-Runspace, Start-EngineRunspace