# C# TCR
OK... It's been a while. I've whipped up a new script that I'm gonna be trying to use on a bigger project and see how it goes.

The original script is left as is; this is now about the tcrAdvanced.ps1 script.

## Improvements
I've tried to make this useful and fluid as part of my standard flow of working. I expect it to continue to get tweaks as pain points show themselves.

Right now the big changes are
* Tests limited to changes
* Arlo's Commit Notation PopUp
* Pausing
* BEEP BEEP

### Tests limited to changes
Assumptions: 
* Test classes are the same name as their file
* Test classes are named [ClassUnderTest]Tests

When a file changes, the script only runs the test class for that file. It may still have to build and will run all the tests in the class; but it should narrow it to just that one test class.

I don't know how much time this saves yet. It's longer than I want it to be... but... it's a try.

### Arlo's Commit Notation PopUp
I've whipped up powershell to popup a dialog box ontop of everything else when the tests pass. It's intended to facilitate using [Arlo's Commit Notation](https://github.com/RefactoringCombos/ArlosCommitNotation) and do very small commits.  
Which means; if you're doing TDD like you mean it - you'll have tests pass with a small change, which will show the popup; which you can then do a commit.  

Rinse and Repeat. 

You don't have to - it's there and it's a helper.

### Pausing
You can hit 'p' to pause. And then 'p' again to resume. This will allow for some changes without TCR fighting you. I added it for project creation... then I created a script to do my project creation for me to work with TCR.

### BEEP BEEP
It beeps. I tried to make happy and sad sounding beeps; but it'll beep at you after running the tests.

## Running
Running the script is pretty simple
```powershell
.\tcrAdvanced.ps1 -folder /path/to/your/sln
```
Give it the path and it'll start spinning.

That's it.
