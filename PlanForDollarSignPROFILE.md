Quick Start for DollarSignProfile:
* Overwrite your `$PROFILE` with DollarSignPROFILE.ps1 once manually:
```ps
iwr profile.jakehildreth.com | iex
```

That's it. When DollarSignPROFILE.ps1 changes, your local profile will be updated the next time you run PowerShell.

How it works:
1. On every load of `$PROFILE`, do iwr to get the current version of DollarSignPROFILE.ps1 and save it to an object
2. Generate the object's hash
3. Compare the object's hash against $PROFILE's hash
4. If the hashes don't match, write the object's contents to $PROFILE
5. Reload $PROFILE:
```ps
. $PROFILE
```