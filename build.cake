// Arguments
var target = Argument<string>("target", "Default");
var version = Argument<string>("targetversion", null);
var nugetapikey = Argument<string>("apikey", "");
var nogit = Argument<bool>("nogit", false);
var source = Argument<string>("source", null);

var BASE_GITHUB_PATH = "git@github.com:NancyFx";
var WORKING_DIRECTORY = "Working";

var SUB_PROJECTS = new List<string>{
    "Nancy",
    "Nancy.Bootstrappers.Autofac",
    "Nancy.Bootstrappers.Ninject",
    "Nancy.Bootstrappers.StructureMap",
    "Nancy.Bootstrappers.Unity",
    "Nancy.Bootstrappers.Windsor",
    "Nancy.Serialization.ProtBuf",
    "Nancy.Serialization.ServiceStack",
    "Nancy.Serialization.JsonNet"
};

Task("Package-Nuget")
    .Does(() =>
    {
        SUB_PROJECTS.ForEach(project => {
            LogInfo("Packaging Nuget for : "+ project);

            var path = GetProjectDirectory(project, WORKING_DIRECTORY) + "/build.cake";
            var settings = GetCakeSettings(Context, new Dictionary<string, string> {
                {"target", "Package-NuGet"}
            });

            CakeExecuteScript(path, settings);
        });
    });

Task("Publish-NuGet")
    .Does(() =>
    {
        if(string.IsNullOrWhiteSpace(nugetapikey)){
            throw new CakeException("No NuGet API key provided.");
        }

        SUB_PROJECTS.ForEach(project => {
            LogInfo("Packaging Nuget for : "+ project);

            var path = GetProjectDirectory(project, WORKING_DIRECTORY) + "/build.cake";
            var settings = GetCakeSettings(Context, new Dictionary<string, string> {
                {"target", "Publish-NuGet"},
                {"apikey", nugetapikey},
                {"source", source}
            });

            CakeExecuteScript(path, settings);
        });
    });

Task("Update-Projects")
    .Description("Updates all sub project submodules")
    .Does(() =>
    {
        SUB_PROJECTS.Skip(1).ToList().ForEach(project => {
            LogInfo(string.Format("Updating: {0} to v{1}", project, version));

            var dir = GetProjectDirectory(project,WORKING_DIRECTORY);

            PrepSubModules(dir, nogit);

            ExecuteGit(dir + "/dependencies/Nancy", "fetch --tags", nogit);
            ExecuteGit(dir + "/dependencies/Nancy", string.Format("checkout v{0}", version), nogit);

            ExecuteGit(dir, string.Format("commit -am \"Updated submodule to v{0}\"", version), nogit);
            ExecuteGit(dir, string.Format("tag -a v{0} -m \"Tagged v{0}\"", version), nogit);
        });
    });

Task("Get-Projects")
    .Description("Creates the working directory and gets projects from GitHub")
    .IsDependentOn("Clean")
    .Does(() =>
    {
        CreateDirectory(WORKING_DIRECTORY);
        LogInfo("Getting projects from github account: "+BASE_GITHUB_PATH);

        SUB_PROJECTS.ForEach(project => {
            LogInfo("Getting " + project + " from github");
            StartProcess("git", new ProcessSettings {
                Arguments = string.Format("clone --recursive {0} {1}/{2}", GetProjectGitUrl(project, BASE_GITHUB_PATH), WORKING_DIRECTORY,project)
            });
        });
    });

Task("Test-Projects")
    .Description("Tests all projects")
    .Does(() =>
    {
        SUB_PROJECTS.ForEach(project => {
            LogInfo("Running test for : " + project);

            var path = GetProjectDirectory(project, WORKING_DIRECTORY) + "/build.cake";
            var settings = GetCakeSettings(Context, new Dictionary<string, string> {
              {"target", "Test"}
            });

            CakeExecuteScript(path, settings);
        });
    });

Task("Clean")
    .Description("Cleans up (deletes!) the working directory")
    .Does(() =>
    {
        CleanDirectory("./" + WORKING_DIRECTORY);
    });

Task("Prepare-Release")
    .IsDependentOn("Get-Projects")
    .IsDependentOn("Prepare-Release-Nancy")
    .IsDependentOn("Update-Projects")
    .Does(() =>
    {
        LogInfo("Preparing release for " + version);
    });

Task("Prepare-Release-Nancy")
    .Description("Sets the Nancy version that all sub repos depend on")
    .Does(() =>
    {
        var path = GetProjectDirectory("Nancy", WORKING_DIRECTORY) + "/build.cake";
        var settings = GetCakeSettings(Context, new Dictionary<string, string> {
            {"target", "Prepare-Release"},
            {"targetversion", version},
            {"nogit", nogit.ToString()}
        });

        CakeExecuteScript(path, settings);
    });

Task("Default")
    .IsDependentOn("Get-Projects")
    .IsDependentOn("Test-Projects");

Task("Push-SubProjects")
    .Does(() => {
        SUB_PROJECTS.Skip(1).ToList().ForEach(project => {
            LogInfo(string.Format("Updating: {0}", project));
            ExecuteGit(GetProjectDirectory(project, WORKING_DIRECTORY), "push origin master", nogit);
            ExecuteGit(GetProjectDirectory(project, WORKING_DIRECTORY), "push --tags", nogit);
        });
    });

RunTarget(target);

public string GetProjectGitUrl(string project, string url)
{
    return string.Format("{0}/{1}", url, project);
}

public string GetProjectDirectory(string project, string dir)
{
    return string.Format("./{0}/{1}", dir, project);
}

public void LogInfo(string message)
{
    Information(logAction => logAction(message));
}

public void ExecuteGit(string workingDir, string command, bool nogit)
{
    LogInfo(" - git " + command + " (" + workingDir + ")");

    if (!nogit)
    {
        StartProcess("git", new ProcessSettings {
            Arguments = string.Format("{0}", command),
            WorkingDirectory = workingDir
        });
    }
}

public void PrepSubModules(string workingDir, bool nogit)
{
    ExecuteGit(workingDir, "submodule init", nogit);
    ExecuteGit(workingDir, "submodule update", nogit);
}

public CakeSettings GetCakeSettings(ICakeContext context, IDictionary<string, string> arguments = null)
{
    var settings = new CakeSettings { Arguments = arguments };

    if (context.Environment.Runtime.IsCoreClr)
    {
        var cakePath = System.IO.Path
            .Combine(Context.Environment.ApplicationRoot.FullPath, "Cake.dll")
            .Substring(Context.Environment.WorkingDirectory.FullPath.Length + 1);

        settings.ToolPath = System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName;
        settings.ArgumentCustomization = args => string.Concat(cakePath, " ", args.Render());
    }

    return settings;
}
