require './git'
require './executor'
require 'rubygems'
require 'albacore'
require 'FileUtils'

namespace :nancy do
  BASE_GITHUB_PATH = 'git@github.com:grumpydev/'
  SHARED_ASSEMBLY_INFO = 'src/SharedAssemblyInfo.cs'
  WORKING_DIRECTORY = 'Working'
  NANCY_DIRECTORY = "#{WORKING_DIRECTORY}/Nancy"

  SUB_PROJECTS = [
      'Nancy.Bootstrappers.StructureMap',
      'Nancy.Bootstrappers.Unity'
  ]

  Dir.class_eval do
    def self.logged_chdir(dir, &block)
      puts "Entering #{dir}"
      self.chdir(dir, &block)
      puts "Leaving #{dir} (Now: #{Dir.pwd})"
    end
  end

  desc "Creates the working directory and gets projects from GitHub"
  task :get_projects do
    puts "Deleting working folder" if File.exists? WORKING_DIRECTORY
    FileUtils.rm_rf(WORKING_DIRECTORY)
    Dir.mkdir(WORKING_DIRECTORY)

    Dir.logged_chdir WORKING_DIRECTORY do
      puts "Getting projects from github account: #{BASE_GITHUB_PATH}"
      Git.clone(get_git_url('Nancy'))

      SUB_PROJECTS.each do |project|
        Git.clone(get_git_url(project))
      end
    end
  end

  desc "Prepares a release"
  task :prep_release, [:version] => [:get_projects] do |task, args|
    if !args.version.nil?
      puts "Prepping #{args.version}"

      Rake::Task['nancy:tag_nancy'].invoke(args.version)

      puts "Updating sub projects.."
      SUB_PROJECTS.each do |project|
        Rake::Task['nancy:update_project'].reenable
        Rake::Task['nancy:update_project'].invoke(project, args.version)
      end
    end
  end

  task :tag_nancy, :version do |task, args|
    puts "Updating Nancy version to v#{args.version} and creating tag"

    Dir.logged_chdir NANCY_DIRECTORY do
      Rake::Task['nancy:update_version'].invoke(args.version)
      Git.add(SHARED_ASSEMBLY_INFO)
      Git.commit("Updated SharedAssemblyInfo to v#{args.version}")

      Git.tag "v#{args.version}", false, "Tagged v#{args.version}"
      Git.push_tags
    end
  end

  task :update_project, :project, :version do |task, args|
    puts "Updating: #{args.project} to v#{args.version}"

    Dir.logged_chdir get_project_directory(args.project) do
      Git.prep_submodules

      Dir.logged_chdir 'dependencies/Nancy' do
        Git.checkout 'master'
        Git.pull
        Git.checkout "v#{args.version}"
      end

      Git.commit_all "Updated submodule to tag: v#{args.version}"
      Git.tag "v#{args.version}", false, "Tagged v#{args.version}"
    end
  end

  desc "Pushes all sub projects into github"
  task :push_subprojects do
    puts "Pushing subprojects.."

    SUB_PROJECTS.each do |project|
      Dir.logged_chdir get_project_directory(project) do
        puts "Updating: #{project}"

        Git.push 'origin master'
        Git.push_tags
      end
    end
  end

  desc "Builds all nuget packages"
  task :build_nugets do
    puts "Building nugets"

    Dir.logged_chdir NANCY_DIRECTORY do
      puts "Building Nuget: Nancy"

      Executor.execute_command("rake nuget_package")
    end

    SUB_PROJECTS.each do |project|
      Dir.logged_chdir get_project_directory(project) do
        puts "Pushing Nugets: #{project}"

        Executor.execute_command("rake nuget_package")
      end
    end
  end

  desc "Pushes all nuget packages using the specified API key"
  task :push_nugets, :api_key do |task, args|
    puts "Pushing nugets"

    Dir.logged_chdir NANCY_DIRECTORY do
      puts "Pushing Nuget: Nancy"

      Executor.execute_command("rake nuget_publish[#{args.api_key}]")
    end

    SUB_PROJECTS.each do |project|
      Dir.logged_chdir get_project_directory(project) do
        puts "Building Nugets: #{project}"

        Executor.execute_command("rake nuget_publish[#{args.api_key}]")
      end
    end
  end

  desc "Updates #{SHARED_ASSEMBLY_INFO} version"
  assemblyinfo :update_version, :version do |asm, args|
      asm.input_file = SHARED_ASSEMBLY_INFO
      asm.version = args.version if !args.version.nil?
      asm.output_file = SHARED_ASSEMBLY_INFO
  end

  def get_git_url(project)
    "#{BASE_GITHUB_PATH}#{project}.git"
  end

  def get_project_directory(project)
    "#{WORKING_DIRECTORY}/#{project}"
  end
end
