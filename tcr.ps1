
# SETUP
#The Solution to Build
$toBuild = "TCR.sln"
#The commit message on tests passing
$commitMsg = "tcr success"
# Code Folder to exclude resetting test files
$srcLoc = "src"

# TO USE
# Run the script from the location of the git repo you're working in. The location of the script doesn't matter.
#   eg: E:\src\github\fyzxs\TCR> ..\tcr.ps1
# The script lives in the parent folder, but is executed from the folder with the .git.


# Checks if the build failed. We don't want to trash everything if we're not compiling yet.
Function Build-Failed{
    Write-Host "### Building the solution" -ForegroundColor Blue
    Invoke-Command "dotnet build $toBuild"
    return $LASTEXITCODE -eq 1
}

# This runs the tests and returns the output for analysis in other methods
function Tests-Run{
    Write-Host "### Running tests" -ForegroundColor Blue
    Invoke-Expression -Command: "dotnet test $toBuild" | Tee-Object -Variable output | Write-Host
    return $output
}

# Checks if the test output indicates success
Function Tests-Pass($testOutput){
    return $testOutput -Match "Test Run Successful"
}

# Checks if there's a single NotImplementedException which we should not reset on.
Function Single-NotImplementedException($testOutput){
    $count = ([regex]::Matches($testOutput, "System.NotImplementedException: The method or operation is not implemented." )).count
    return $count -eq 1
}

# Commits our code, rebases, pushes to the server
Function Commit{
    Invoke-Command "git add --all"
    Invoke-Command "git commit -m '$commitMsg'"
    Invoke-Command "git pull --rebase"
    Invoke-Command "git push"
}

# Reset our code folder
Function Revert{
    Invoke-Command "git checkout HEAD -- $srcLoc"
    if($LASTEXITCODE -ne 0){
        Write-Host "Unable to revert. Git's broke somewhere. [LASTEXITCODE=$LASTEXITCODE]" -ForegroundColor Red
    }
}

# Helper function to minimize clutter in other methods
Function Invoke-Command($command){
    Write-Host "Executing [$command]" -ForegroundColor Yellow
    Invoke-Expression -Command: $command | Write-Host
}

# Enables debouncing repeated triggers
$global:debounceTime = (Get-Date)

# Eliminates multiple builds off a single save.
Function global:Debounce($time){
    if($global:debounceTime -ge $time){
        #Write-Host "### Debounce [$global:debounceTime] -eq [$time]"  -ForegroundColor Blue
        return $true
    }
    #Write-Host "### Running [$global:debounceTime] -eq [$time]"  -ForegroundColor Blue
    $global:debounceTime = $time
    return $false
}

# Gotta set the time at the end of a build.
Function global:EndRunSet($time){
    $global:debounceTime = $time
}

# The Core Workload
Function global:TCR($event){
    if(Debounce($event.TimeGenerated)){#Guard Clause to not run on multiple events
        return
    }

    try{
        Write-Host "### Starting TCR" -ForegroundColor Blue

        if(Build-Failed){ # Guard clause if the build fails
            Write-Host "### Build failed. No change." -ForegroundColor Magenta
            return
        }

        Write-Host "### Build Passed"  -ForegroundColor Blue

        $testOutput = Tests-Run # Run the tests
        if(Single-NotImplementedException $testOutput){ # A single NotImplementedException guard clause
            Write-Host "### A single NotImplementedException is allowed. No Change." -ForegroundColor Magenta
            return
        }
        
        if(Tests-Pass $testOutput){ # Tests pass, commit the change
            Write-Host "### Tests Passed. Commiting Changes."  -ForegroundColor Green
            Commit
            return
        } 

        #Default behavior is to revert.
        Write-Host "### Tests Failed. Reverting..." -ForegroundColor Red
        Revert

    }
    finally{
        Write-Host "### Ending TCR" -ForegroundColor Blue
        EndRunSet(Get-Date)
    }
}


# Builds our Watcher
Function Register-Watcher {
    $folder = "$(Get-Location)\$srcLoc"
    Write-Host "Watching $folder"
    $filter = "*.cs"
    $watcher = New-Object IO.FileSystemWatcher $folder, $filter -Property @{ 
        IncludeSubdirectories = $true
        EnableRaisingEvents = $true
    }

    return $watcher
}

# I don't like bits just handing out and getting executed.
Function Do-The-Work{
    $FileSystemWatcher = Register-Watcher
    $Action = {TCR $event}
    # add event handlers
    $handlers = . {
        Register-ObjectEvent -InputObject $FileSystemWatcher -EventName "Changed" -Action $Action -SourceIdentifier FSChange
        Register-ObjectEvent -InputObject $FileSystemWatcher -EventName "Created" -Action $Action -SourceIdentifier FSCreate
        Register-ObjectEvent -InputObject $FileSystemWatcher -EventName "Deleted" -Action $Action -SourceIdentifier FSDelete
        Register-ObjectEvent -InputObject $FileSystemWatcher -EventName "Renamed" -Action $Action -SourceIdentifier FSRename
    }

    try
    {
        do
        {
            Wait-Event -Timeout 1
            Write-Host "." -NoNewline
            
        } while ($true)
    }
    finally
    {
        Write-Host "Exiting..."
        # this gets executed when user presses CTRL+C
        # remove the event handlers
        Unregister-Event -SourceIdentifier FSChange
        Unregister-Event -SourceIdentifier FSCreate
        Unregister-Event -SourceIdentifier FSDelete
        Unregister-Event -SourceIdentifier FSRename
        # remove background jobs
        $handlers | Remove-Job
        # remove filesystemwatcher
        $FileSystemWatcher.EnableRaisingEvents = $false
        $FileSystemWatcher.Dispose()
        "Event Handler disabled."
    }
}

# Does the Work
Do-The-Work