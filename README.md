# README

Release procedures:

`./build.sh --target Prepare-Release --targetversion=X.X.X` - This will get all repos, set the Nancy version and push back to Nancy repo, update all sub repos with new Nancy version

`./build.sh --target Test-Projects` -  This will compile all repos and run tests

`./build.sh --target Push-SubProjects` - This will push all the updated sub repos

`./build.sh --target Package-NuGet` -- This will create the *.nupkgs

`./build.sh --target Publish-Nuget --apikey=XXX --source=https://www.nuget.org/api/v2/package` -- This will push the nupkgs to a source eg. MyGet/NuGet

`./build.sh --target Clean` -- This will remove the contents of the working directory

To prevent any git commands running add the `--nogit=true` when calling the build script. For example `./build.sh --target Prepare-Release --targetversion=X.X.X --nogit=true`

**NOTE:** You can replace `build.sh` with `build.ps1` if on Windows