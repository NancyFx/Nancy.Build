#addin "nuget:?package=Newtonsoft.Json&version=8.0.3"

// Arguments
var target = Argument<string>("target", "Default");
var version = Argument<string>("targetversion", null);
var nugetapikey = Argument<string>("apikey", "");
var debug = Argument<bool>("debug", false);
var BASE_GITHUB_PATH = "https://github.com/NancyFx";
var WORKING_DIRECTORY = "Working";
var projectJsonFiles = GetFiles("./Working/**/project.json");

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
  if(string.IsNullOrWhiteSpace(nugetapikey)){
    throw new CakeException("No NuGet API key provided.");
   }
  
  SUB_PROJECTS.ForEach(project => {
    LogInfo("Packaging Nuget for : "+ project);
    CakeExecuteScript(GetProjectDirectory(project, WORKING_DIRECTORY) + "/build.cake", new CakeSettings{ Arguments = new Dictionary<string, string>{{"target", "Package-NuGet"}}});   
  });
   
});

Task("Publish-Nuget")
  .Does(() =>
{
  SUB_PROJECTS.ForEach(project => {
    LogInfo("Packaging Nuget for : "+ project);
    CakeExecuteScript(GetProjectDirectory(project, WORKING_DIRECTORY) + "/build.cake", new CakeSettings{ Arguments = new Dictionary<string, string>{{"target", "Publish-NuGet"},{"apikey",nugetapikey}}});   
  });
   
});

Task("Update-Projects")
.Description("Updates all sub project submodules")
.Does(() =>
{
  SUB_PROJECTS.Skip(1).ToList().ForEach(project => {
    LogInfo(string.Format("Updating: {0} to v#{1}",project,version));
    var dir = GetProjectDirectory(project,WORKING_DIRECTORY);
    PrepSubModules(dir);
    ExecuteGit(dir+"/dependencies/Nancy","checkout 'master'");
    ExecuteGit(dir+"/dependencies/Nancy","pull");
    ExecuteGit(dir+"/dependencies/Nancy",string.Format("checkout v{0}",version));
    ExecuteGit(dir,string.Format("commit -am \"Updated submodule to tag: v{0}\"",version);
    ExecuteGit(dir,string.Format("tag v{0}",version);
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
    LogInfo("Getting "+ project +" from github");
    StartProcess("git", new ProcessSettings {
      Arguments = string.Format("clone --recursive {0} {1}/{2}", GetProjectGitUrl(project, BASE_GITHUB_PATH), WORKING_DIRECTORY,project)
    });
  });
});

Task("Build-Projects")
.IsDependentOn("Get-Projects")
.Description("Builds all projects")
.Does(() =>
{
  SUB_PROJECTS.ForEach(project => {
    LogInfo("Building "+ project);
    CakeExecuteScript(GetProjectDirectory(project, WORKING_DIRECTORY) + "/build.cake", new CakeSettings{ Arguments = new Dictionary<string, string>{{"target", target}}});   
  });
});


Task("Test-Projects")
.IsDependentOn("Build-Projects")
.Description("Tests all projects")
.Does(() =>
{
  SUB_PROJECTS.ForEach(project => {
    LogInfo("Running test for : "+ project);
    CakeExecuteScript(GetProjectDirectory(project, WORKING_DIRECTORY) + "/build.cake", new CakeSettings{ Arguments = new Dictionary<string, string>{{"target", "Test"}}});   
  });
});

Task("Clean")
.Description("Cleans up (deletes!) the working directory")
.Does(() =>
{
  CleanDirectory("./"+WORKING_DIRECTORY);
});

Task("Prepare-Release")
  .Does(() =>
 {
  // Update version.
  UpdateProjectJsonVersion(version, projectJsonFiles);

  foreach (var file in projectJsonFiles) 
  {
    ExecuteGit(GetProjectDirectory(project, WORKING_DIRECTORY), string.Format("add {0}", file.FullPath));
    ExecuteGit(GetProjectDirectory(project, WORKING_DIRECTORY), string.Format("commit -m \"Updated version to {0}\"", version));
    ExecuteGit(GetProjectDirectory(project, WORKING_DIRECTORY), string.Format("tag \"v{0}\"", version));
  }
 });

Task("Prepare-Release-Nancy")
.Description("Prepares the main Nancy repo for a release")
.Does(() => 
{
  CakeExecuteScript(GetProjectDirectory("Nancy", WORKING_DIRECTORY) + "/build.cake", new CakeSettings{ Arguments = new Dictionary<string, string>{{"target", "Prepare-Release"},{"targetversion",target}}});   
});

Task("Default")
    .IsDependentOn("Build-Projects");
 
Task("Push-SubProjects")
 .Does(() => {
    SUB_PROJECTS.Skip(1).ToList().ForEach(project => {
      LogInfo(string.Format("Updating: {0}",project));
      ExecuteGit(GetProjectDirectory(project, WORKING_DIRECTORY),"push origin master");
      ExecuteGit(GetProjectDirectory(project, WORKING_DIRECTORY),"push --tags");
    });
});   
	
RunTarget(target);

public string GetProjectGitUrl(string project, string url)
{
  return string.Format("{0}/{1}",url ,project);
}

public string GetProjectDirectory(string project, string dir)
{
  return string.Format("./{0}/{1}",dir ,project);
}

public void UpdateProjectJsonVersion(string version, FilePathCollection filePaths)
{
  LogInfo("Setting version to "+ version);
  foreach (var file in filePaths) 
  {
    var project = Newtonsoft.Json.Linq.JObject.Parse(
      System.IO.File.ReadAllText(file.FullPath, Encoding.UTF8));

    project["version"].Replace(version);

    System.IO.File.WriteAllText(file.FullPath, project.ToString(), Encoding.UTF8);
  }
}

public void LogInfo(string message)
{
  Information(logAction=>logAction(message));
}

public void ExecuteGit(string workingDir, string command)
{
  LogInfo("Changing directory to "+ workingDir);
  if (debug)
  {
    Console.WriteLine("Executing git " + command + " in " + workingDir);
  }
  else 
  {
    StartProcess("git",new ProcessSettings {
       Arguments = string.Format("{0}", command),
       WorkingDirectory = workingDir
     });
  }
}

public void PrepSubModules(string workingDir)
{
  ExecuteGit(workingDir,"submodule init");
  ExecuteGit(workingDir,"submodule update");
}