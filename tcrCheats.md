# TCR Cheats
Ya gotta cheat to get a fair play with TCR.

This is all C# focused in Visual Studio. This is going to document the cheats I use so I don't have to rediscover them again.

These are currently focused around when creating and evolving a new class. As this grows, it'll get into other scenarios.

# Move Class out of Test Project
Problem: Extracting non-test class to the non-test project results in TCR; R-ing.

Solution:
Make the namespace to block-scoped
Put the class into the namespace it'll end up in while in the test file.
Move the class into it's own file (do not fix namesspaces)
Now move the class to the non-test project
undoe the block-scope in both files


# Add Generic
Problem: Adding a generic requires EITHER the test class, or actual class to be out of sync.
Problem: On-Save Clean Up (as I have it configured) nukes unused usings

Solution:
Use the Fully Qualified Domain name to reference the class and add the generic syntax in the test class.
Save the test file. TCR runs, fails, but nothing to nuke in non-test code.
Update non-test class to have generic.
TCR passes
Update test to use using instead of FQDN.

# Add abstract
Problem: Making a class abstract means existing instantiations cause tests to fail

Solution:
(if class is sealed, remove sealed - all still passes)
Create a private class in the test class and inherit from the target class.
Update tests to intantiate this testInstance and Liskov into the target class.
Update target class to be abstract.