require './git'
require 'rubygems'
require 'albacore'

namespace :nancy do
  SHARED_ASSEMBLY_INFO = 'src/SharedAssemblyInfo.cs'

  sub_projects = [
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

  desc "Prepares a release"
  task :prep_release, :version do |task, args|
    if !args.version.nil?
      puts "Prepping #{args.version}"

      Rake::Task['nancy:tag_nancy'].invoke(args.version)

      puts "Updating sub projects.."
      sub_projects.each do |project|
        Rake::Task['nancy:update_project'].reenable
        Rake::Task['nancy:update_project'].invoke(project, args.version)
      end
    end
  end

  task :tag_nancy, :version do |task, args|
    puts "Updating Nancy version to v#{args.version} and creating tag"

    Dir.logged_chdir '../Nancy' do
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

    sub_projects.each do |project|
      Dir.logged_chdir get_project_directory(project) do
        puts "Updating: #{project}"

        Git.push 'origin/master'
        Git.push_tags
      end
    end
  end

  desc "Updates #{SHARED_ASSEMBLY_INFO} version"
  assemblyinfo :update_version, :version do |asm, args|
      asm.input_file = SHARED_ASSEMBLY_INFO
      asm.version = args.version if !args.version.nil?
      asm.output_file = SHARED_ASSEMBLY_INFO
  end

  def get_project_directory(project)
    "../#{project}"
  end
end
