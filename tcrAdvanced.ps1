# Accept a folder path as a parameter
param (
    [string]$folder
)

$debugLog = $true

$global:debounceTime = (Get-Date)
$global:debounceInterval = 3 # Debounce interval in seconds
$global:tcrRunning = $false

# Eliminates multiple builds off a single save.
Function global:Debounce($time){
    $timeDifference = ($time - $global:debounceTime).TotalSeconds
    if ($timeDifference -lt $global:debounceInterval) {
        Invoke-DebugLog "### Debounced: Only $timeDifference seconds since last event" -ForegroundColor Blue
        return $true
    }
    Invoke-DebugLog "### Running: $timeDifference seconds since last event" -ForegroundColor Blue
    $global:debounceTime = $time
    return $false
}

function Invoke-DebugLog{
    param (
        [string]$msg
    )

    if(-not $debugLog){ return }
    
    Write-Host "`r$($msg)" -ForegroundColor Gray
}

# The Core Workload
function global:TCR{
    param (
        [object]$eventInfo
    )
    try{
        if(Debounce($eventInfo.TimeGenerated)){#Guard Clause to not run on multiple events
            return
        }
        if($global:tcrRunning){
            Write-Host "### Already running TCR. Skipping this event." -ForegroundColor Yellow
            return
        }
        $tcrRunning = $true

        Write-Host ""
        $name = $eventInfo.SourceEventArgs.Name
        $changeType = $eventInfo.SourceEventArgs.ChangeType
        $timeStamp = $eventInfo.TimeGenerated
        
        $path = $eventInfo.SourceEventArgs.FullPath
        Invoke-DebugLog "The file $name at $path was $changeType at $timeStamp"

        $testResults = RunTests $path

        Invoke-DebugLog "### Tests Run - checking results"
        #Write-Host "### Tests Run results [$testResults]"

        if(-not $testResults) {
            Write-Host "### No test results. Cannot determine outcome." -ForegroundColor Yellow
            return
        }

       Invoke-DebugLog "### Has Test Results"

        if(NoTestsFound $testResults) { # Guard clause if no tests are found
            Write-Host "### No tests found. Cannot determine outcome." -ForegroundColor Yellow
            return
        }

        Invoke-DebugLog "### Has Tests Found"
        
        if(OnlySingleNotImplementedException $testResults) {
            Write-Host "### A single NotImplementedException is allowed. No Change." -ForegroundColor Cyan
            [System.Console]::Beep(800, 200)
            return
        }

        Invoke-DebugLog "### Non-single NIE"

        if(TestsPassed $testResults) {
            Write-Host "### Tests Passes. Committing." -ForegroundColor Green
            [System.Console]::Beep(1200, 200)
            [System.Console]::Beep(1400, 500)
            Commit
            return
        }

        Invoke-DebugLog "### tests did not pass"

        if(TestsFailed $testResults) { 
            Write-Host "### Tests failed. Reverting." -ForegroundColor Red
            [System.Console]::Beep(500, 200)
            [System.Console]::Beep(300, 500)
            Revert
            return
        }

        Invoke-DebugLog "### tests did not fail"


        if(BuildFailed $testResults) { # Guard clause if the build fails
            # qgil - 2025-03-18: Not sure why I had this before... leaving it in... for now.
            Write-Host "### Build failed. Reverting." -ForegroundColor Magenta
            [System.Console]::Beep(400, 200)
            [System.Console]::Beep(300, 200)
            Revert
            return
        }

        Write-Host "### Apparently it went so wrong there's no result. [$testResults]" -ForegroundColor Red
    }catch{
        Write-Host "### Something went wrong. [$($_.Exception.Message)]" -ForegroundColor Red
    }finally{
        $tcrRunning = $false
    }
}

Add-Type -AssemblyName System.Windows.Forms
function Get-CommitMessage {
    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Arlo Commit Notation Message"
    $form.Size = New-Object System.Drawing.Size(440, 380)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog # Prevent resizing
    $form.MaximizeBox = $false # Disable maximize button
    $form.MinimizeBox = $false # Disable minimize button

    # # Create a label
    # $label = New-Object System.Windows.Forms.Label
    # $label.Text = "Enter your commit message:"
    # $label.AutoSize = $true
    # $label.Location = New-Object System.Drawing.Point(10, 10)
    # $form.Controls.Add($label)

    # Create a text box
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Size = New-Object System.Drawing.Size(400, 20)
    $textBox.Location = New-Object System.Drawing.Point(10, 10)
    $textBox.Font = New-Object System.Drawing.Font("Courier New", 18) # Set monospace font
    $form.Controls.Add($textBox)

    # Handle the KeyDown event for the text box
    $textBox.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        }
    })

    # Create a wide label between the text box and buttons
    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Text = "
| RISK LEVEL        | CORE INTENTIONS       |
|-------------------|-----------------------|
| Proven Safe : '.' | F|f : Feature         |
| Validated   : '^' | B|b : Bug Fix         |
| Risky       : '!' | R|r : Refactoring     |
| Broken      : '@' | D|d : Documentation   |
|                   | E|e : Environment     |
|                   | t   : Tests Only      |
|-------------------|-----------------------|
Examples
  . r rename variable
  ! B fixed spelling on lable
  ^ R manually extracted cohesive class
"
    $infoLabel.AutoSize = $true
    $infoLabel.Location = New-Object System.Drawing.Point(10, 50)
    $infoLabel.Size = New-Object System.Drawing.Size(360, 20)
    $infoLabel.Font = New-Object System.Drawing.Font("Courier New", 10) # Set monospace font
    $form.Controls.Add($infoLabel)
    
    $renameButton = New-Object System.Windows.Forms.Button
    $renameButton.Text = "Rename"
    $renameButton.Location = New-Object System.Drawing.Point(10, 270)
    $renameButton.Add_Click({
        $textBox.Text = ". r Rename"
    })
    $form.Controls.Add($renameButton)

    $inlineButton = New-Object System.Windows.Forms.Button
    $inlineButton.Text = "Create Class"
    $inlineButton.Location = New-Object System.Drawing.Point(90, 270)
    $inlineButton.Add_Click({
        $textBox.Text = ". r create class"
    })
    $form.Controls.Add($inlineButton)

    $extractMethodButton = New-Object System.Windows.Forms.Button
    $extractMethodButton.Text = "Extract Method"
    $extractMethodButton.Location = New-Object System.Drawing.Point(170, 270)
    $extractMethodButton.Add_Click({
        $textBox.Text = ". r Extract Method"
    })
    $form.Controls.Add($extractMethodButton)

    $extractVariableMethod = New-Object System.Windows.Forms.Button
    $extractVariableMethod.Text = "Extract Variable"
    $extractVariableMethod.Location = New-Object System.Drawing.Point(250, 270)
    $extractVariableMethod.Add_Click({
        $textBox.Text = ". r Extract Variable"
    })
    $form.Controls.Add($extractVariableMethod)

    $deleteClutterButton = New-Object System.Windows.Forms.Button
    $deleteClutterButton.Text = "Formatting"
    $deleteClutterButton.Location = New-Object System.Drawing.Point(330, 270)
    $deleteClutterButton.Add_Click({
        $textBox.Text = ". a formatting"
    })
    $form.Controls.Add($deleteClutterButton)

    # Create an OK button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(250, 300)
    $okButton.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($okButton)

    # Create a Cancel button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Location = New-Object System.Drawing.Point(330, 300)
    $cancelButton.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })
    $form.Controls.Add($cancelButton)

    # Show the form
    $dialogResult = $form.ShowDialog()

    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        return $textBox.Text
    } else {
        return $null
    }
}

function GitChanges{
    # Run git status and capture the output to determine changed files
    $gitStatusOutput = git status --porcelain *.cs
    Invoke-DebugLog "### Found changes in the repository [$gitStatusOutput]" -ForegroundColor Blue
    return $gitStatusOutput
}

# Commits our code, rebases, pushes to the server
function Commit{
    if(-not $(GitChanges)){
        Write-Host "No changes to commit." -ForegroundColor Yellow
        return
    }

    $commitMsg = Get-CommitMessage
    if (-not $commitMsg) {
        Write-Host "Commit canceled by user." -ForegroundColor Yellow
        return
    }
    Write-Host "### Committing changes with message: $commitMsg" -ForegroundColor Green
    Invoke-Command "git add *.cs *.csproj *.sln"
    Invoke-Command "git commit -m '$commitMsg'"
    Invoke-Command "git pull --rebase"
    Invoke-Command "git push"
}

# Reset our code folder
function Revert{
    # Nuke directories
    Invoke-Command "git clean -df -e **.Tests"
    # Restore files
    Invoke-Command "git checkout HEAD -- *.cs *.sln :!**Tests.cs"
    if($LASTEXITCODE -ne 0){
        Write-Host "Unable to revert. Git's broke somewhere. [LASTEXITCODE=$LASTEXITCODE]" -ForegroundColor Red
    }
}

# Helper function to minimize clutter in other methods
function Invoke-Command{
    param (
        [string]$command
    )
    #Write-Host "Executing [$command]" -ForegroundColor Yellow
    Invoke-Expression -Command: $command | Write-Host
}


function OnlySingleNotImplementedException {
    param (
        [string]$testOutput
    )
    $nie = SingleNotImplementedException -testOutput $testOutput
    $nmf = NotMultipleFailedTests -testOutput $testOutput
    return $nie -and $nmf
}

function SingleNotImplementedException {
    param (
        [string]$testOutput
    )
    $count = ([regex]::Matches($testOutput, "System.NotImplementedException: The method or operation is not implemented.")).count
    return $count -eq 1
}

function NotMultipleFailedTests {
    param (
        [string]$testOutput
    )
    $match = [regex]::Match($testOutput, "Failed:\s*(\d+)")
    if ($match.Success) {
        $failedCount = [int]$match.Groups[1].Value
        return $failedCount -le 1 # Return true if failed count is 0 or 1
    }
    return $false # Default to false if no match is found
}

function ProbableProjectCreation {
    param (
        [string]$testOutput
    )
    return $testOutput -Match "Project file does not exist."
}

function NoTestsFound {
    param (
        [string]$testOutput
    )
    return $testOutput -Match "No test matches the given testcase"
}

function TestsPassed {
    param (
        [string]$testOutput
    )
    return $testOutput -Match "Test Run Successful."
}

function TestsFailed {
    param (
        [string]$testOutput
    )
    return TestRunStarted $testOutput -and BuildFailed $testOutput
}

function BuildFailed {
    param (
        [string]$testOutput
    )
    return $testOutput -Match "Build FAILED."
}

function TestRunStarted {
    param (
        [string]$testOutput
    )
    return $testOutput -Match "Starting test execution, please wait..."
}

function RunTests {
    param (
        [string]$path
    )
    $results = RetrievePaths -path $path

    if ($results.success -eq $false) {
        Write-Host "No csproj file found. Cannot run tests."
        return
    }

    $isTestProject = $results.csprojName -Match "\.Tests$"

    Invoke-DebugLog "Running tests for project: $($results.csprojName) located at $($results.csprojPath) and $($results.changedFqn) and $($isTestProject)"
    if ($isTestProject) {
        $testProjectPath = "$($results.csprojPath)\$($results.csprojName)\$($results.csprojName).csproj"
        $testClassFilter = "$($results.changedFqn).$($results.changedName)"
    } else {
        $testProjectPath = "$($results.csprojPath)\$($results.csprojName).Tests\$($results.csprojName).Tests.csproj"
        $testClassFilter = "$($results.csprojName).Tests$($results.changedFqn -replace $results.csprojName).$($results.changedName)Tests"
    }

    #Write-Host "dotnet test $testProjectPath --no-restore --configuration DEBUG --filter `"FullyQualifiedName~$testClassFilter`" -v n"
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $job = Start-Job -ScriptBlock {
            param ($testProjectPath, $testClassFilter)
            dotnet test $testProjectPath --no-restore --configuration DEBUG --filter "FullyQualifiedName~$testClassFilter" -v n
        } -ArgumentList $testProjectPath, $testClassFilter

        while ($job.State -eq 'Running') {
            TestRunElapsed -stopwatch $stopwatch
            Start-Sleep -Milliseconds 100
        }

        $output = Receive-Job -Job $job
        Remove-Job -Job $job

        $stopwatch.Stop()

        TestRunElapsed -stopwatch $stopwatch

        $output | ForEach-Object { Invoke-DebugLog $_ }

        Write-Host ""
        return $output
    } catch {
        Write-Host "Error running tests: $_" -ForegroundColor Red
    }
}


function TestRunElapsed {
    param (
        [System.Diagnostics.Stopwatch]$stopwatch
    )
    $elapsedTime = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff")
    Write-Host -NoNewline "`rTest Run Time: (" -ForegroundColor White
    Write-Host -NoNewline $elapsedTime -ForegroundColor Green
    Write-Host -NoNewline ")" -ForegroundColor White
}

function RetrievePaths {
    param (
        [string]$path
    )
    $csprojFile = $null
    $directory = Split-Path -Path $path -Parent
    $changedFilePath = $directory
    while ($directory) {
        $csprojFile = Get-ChildItem -Path $directory -Filter *.csproj -File -ErrorAction SilentlyContinue
        Invoke-DebugLog "Checking directory: $directory and found [$csprojFile]"
        $directory = Split-Path -Path $directory -Parent
        if ($csprojFile) {
            Invoke-DebugLog "Found csproj file: $($csprojFile.FullName)"
            break
        }
    }

    if (-not $csprojFile) {
        Write-Host "No csproj file found in the directory hierarchy starting from $path"
    }

    $changedFileName = [System.IO.Path]::GetFileNameWithoutExtension($path)
    $csprojFileName = [System.IO.Path]::GetFileNameWithoutExtension($csprojFile.FullName)

    $relativePath = $changedFilePath.Substring($changedFilePath.LastIndexOf('\') + 1)
    $relativePath = $relativePath -replace '\\', '.'

    $changedFqn = $csprojFileName + "." + $relativePath

    $obj = @{
        success = [bool]$csprojFile
        csprojPath = $directory
        csprojName = $csprojFileName
        changedPath = $changedFilePath
        changedName = $changedFileName
        changedFqn = $changedFqn
    }

    Write-Host $($obj | ConvertTo-Json -Depth 10)
    return $obj
}

# Builds our Watcher
function Register-Watcher {
    Write-Host "Watching $folder"
    $filter = "*.cs"
    $watcher = New-Object IO.FileSystemWatcher $folder, $filter -Property @{ 
        IncludeSubdirectories = $true
        EnableRaisingEvents = $true
    }

    return $watcher
}
function ShowSpinner {
    param (
        [string[]]$spinnerChars = @('|', '/', '-', '\'), # Array of spinner characters
        [int]$currentIndex = 0                          # Current index in the spinner array
    )

    # Display the current spinner character
    Write-Host "`r$($spinnerChars[$currentIndex])" -NoNewline

    # Return the next index (loop back to 0 if at the end of the array)
    return ($currentIndex + 1) % $spinnerChars.Length
}
$tcrRunning = $false
$global:tcrPaused = $false
function DoTheWork{
    $FileSystemWatcher = Register-Watcher
    $Action = {

            
        if($global:tcrPaused){ 
            return
        }
         
        $filePath = $event.SourceEventArgs.FullPath
        if ($filePath -match "\\obj\\") {
            #Write-Host "Ignoring changes in obj directory: $filePath" -ForegroundColor Yellow
            return
        }

        # Ensure the event is for a file with exactly the .cs extension
        if ($filePath -match "\.cs$" -or $filePath -match "\.csproj$") {
            #Write-Host "Processing file: $filePath"
            $tcrRunning = $true
            TCR $event
            $tcrRunning = $false
        } else {
            #Write-Host "Ignoring file with unsupported extension: $filePath" -ForegroundColor Yellow
        }
    }
    # add event handlers
    $handlers = . {
        Register-ObjectEvent -InputObject $FileSystemWatcher -EventName "Changed" -Action $Action -SourceIdentifier FSChange
        Register-ObjectEvent -InputObject $FileSystemWatcher -EventName "Created" -Action $Action -SourceIdentifier FSCreate
        Register-ObjectEvent -InputObject $FileSystemWatcher -EventName "Deleted" -Action $Action -SourceIdentifier FSDelete
        Register-ObjectEvent -InputObject $FileSystemWatcher -EventName "Renamed" -Action $Action -SourceIdentifier FSRename
    }

    try
    {
        $spinnerIndex = 0 # Initialize the spinner index
        do
        {
            # Check for key press to toggle pause
            if ([System.Console]::KeyAvailable) {
                $key = [System.Console]::ReadKey($true).Key
                if ($key -eq 'P') {
                    $global:tcrPaused = -not $global:tcrPaused
                    if ($global:tcrPaused ) {
                        Write-Host "`rPaused. Press 'P' again to resume." -ForegroundColor Yellow
                    } else {
                        Write-Host "`rResumed." -ForegroundColor Green
                    }
                }
            }

            # If paused, skip processing
            if ($global:tcrPaused) {
                Start-Sleep -Milliseconds 100
                continue
            }

            
            if($tcrRunning) {
                Wait-Event -Timeout 1
            }
            else{
                # Call the spinner function and update the spinner index
                $spinnerIndex = ShowSpinner -currentIndex $spinnerIndex
                Wait-Event -Timeout 1 # Keep the reduced timeout here
            }
            
        } while ($true)
    }
    finally
    {
        Write-Host "`nExiting. Thank you for playing!"
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

# Trap Ctrl+C to gracefully exit
trap {
    Write-Host "Ctrl+C pressed. Exiting..."
    break
}

# Save the current directory
$originalFolder = Get-Location

try {
    # Change to the passed-in folder
    Set-Location $folder
    Write-Host "Changed directory to $folder"

    # Perform the work
    DoTheWork
}
finally {
    # Change back to the original directory
    Set-Location $originalFolder
    Write-Host "Returned to original directory: $originalFolder"
}