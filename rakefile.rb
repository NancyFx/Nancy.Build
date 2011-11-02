require './git'
require './executor'
require 'rubygems'
require 'albacore'
require 'FileUtils'

task :default do
  puts "Nancy Release Script"
  puts
  puts "** Usage **"
  puts
  puts "nancy:prep_release[version]"
  puts
  puts "\t* Grabs all the projects from GitHub"
  puts "\t* Updates SharedAssemblyInfo with [version]"
  puts "\t* Tags Nancy with [version] and pushes"
  puts "\t* Updates all the subproject submodules to point to [version]"
  puts "\t* Tags each subproject with [version] (but doesn't push)"
  puts
  puts "nancy:test_subprojects"
  puts
  puts "\t* Builds all subprojects and executes their tests"
  puts
  puts "nancy:push_subprojects"
  puts
  puts "\t* Pushes all the updated subprojects"
  puts
  puts "nancy:build_nugets"
  puts
  puts "\t* Builds nugets for Nancy and all subprojects"
  puts
  puts "nancy:push_nugets[api_key]"
  puts
  puts "\t* Pushes and publishes nugets for Nancy and all subprojects"
  puts "\t  using the given [api_key]"
  puts
  puts "nancy:clean_working"
  puts
  puts "\t* Cleans (removes) the working directory once done"
  puts
  Rake::Task['nancy:dump_config'].invoke
end

namespace :nancy do
  BASE_GITHUB_PATH = 'git@github.com:NancyFx/'
  SHARED_ASSEMBLY_INFO = 'src/SharedAssemblyInfo.cs'
  WORKING_DIRECTORY = 'Working'
  NANCY_DIRECTORY = "#{WORKING_DIRECTORY}/Nancy"

  SUB_PROJECTS = [
      'Nancy.Bootstrappers.Autofac',
      'Nancy.Bootstrappers.Ninject',
      'Nancy.Bootstrappers.StructureMap',
      'Nancy.Bootstrappers.Unity',
      'Nancy.Bootstrappers.Windsor',
      'Nancy.SassAndCoffee',
      'Nancy.Serialization.ProtBuf',
      'Nancy.Serialization.ServiceStack'
  ]

  Dir.class_eval do
    def self.logged_chdir(dir, &block)
      puts "Entering #{dir}"
      self.chdir(dir, &block)
      puts "Leaving #{dir} (Now: #{Dir.pwd})"
    end
  end

  desc "Dumps the current config to the console"
  task :dump_config do
    puts "** Config **"
    puts
    puts "Base Github Path: \t#{BASE_GITHUB_PATH}"
    puts "Debug Mode: \t\t#{Executor.debug?}"
    puts "Subprojects:"
    SUB_PROJECTS.each do |project|
      puts "\t\t\t#{project}"
    end
  end

  desc "Updates all sub project submodules to point at master"
  task :fix_submodules do
    puts "Fixing all submodules to point to master"

     Dir.logged_chdir WORKING_DIRECTORY do
      SUB_PROJECTS.each do |project|
        Dir.logged_chdir project do
          Git.prep_submodules rescue nil

          Dir.logged_chdir 'dependencies/nancy' do
            Git.checkout 'master'
          end

          Git.add '.'
          Git.commit 'Updated submodule'
          Git.push 'origin master'
        end
      end
    end
  end

  desc "Cleans up (deletes!) the working directory"
  task :clean_working do
    puts "Deleting working folder" if File.exists? WORKING_DIRECTORY
    FileUtils.rm_rf(WORKING_DIRECTORY)
  end

  desc "Creates the working directory and gets projects from GitHub"
  task :get_projects => :clean_working do
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

  desc "Builds and runs tests for all subprojects"
  task :test_subprojects do
    puts "Building and testing subprojects.."

    SUB_PROJECTS.each do |project|
      Dir.logged_chdir get_project_directory(project) do
        puts "Building and testing: #{project}"

        Executor.execute_command("rake xunit")
      end
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
