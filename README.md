# Description

Cross-platform build script, using [CAKE](http://cakebuild.net/), which is used to release a new Nancy version. The script will update the main Nancy repository and all of the sub-repositories to the designed version and build & publish the Nuget packages.

The build script can be invoked either with `build.sh` (macOS/Linux) or `build.ps1` (Windows)

`build.[ps1|sh] --target="name-of-task" [--additional-task-parameters]`

## Available tasks

| Target           | Description                                                                                                                                                                                              |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Prepare-Release  | Fetches all repositories, set the Nancy version and push back to Nancy repository, updates all sub-repositories to point to the tagged Nancy version. Requires `--targetversion="x.y.z"` to be passed in |
| Test-Projects    | This will compile all repositories and run tests                                                                                                                                                         |
| Push-SubProjects | Pushes all the updated sub-repositories                                                                                                                                                                  |
| Package-NuGet    | Creates the `*.nupkgs`. Requires `-apikey="xxx"` and `--source="xxx"` to be passed in                                                                                                                    |
| Publish-Nuget    | Pushes the `*.nupkgs` to a source eg. MyGet/NuGet                                                                                                                                                        |
| Clean            | Remove the contents of the working directory                                                                                                                                                             |

## Release procedure

Execute the tasks in the following order:

- --target="Prepare-Release" --targetversion="X.X.X"

- --target="Test-Projects"

- --target="Push-SubProjects"

- --target="Package-NuGet"

- --target="Publish-Nuget" --apikey="XXX" --source="https://www.nuget.org/api/v2/package"

- --target="Clean"

**NOTE** To prevent any Git commands running add the `--nogit="true"` flag when calling the build script.
