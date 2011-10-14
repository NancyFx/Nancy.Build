require "git"

namespace :nancy do
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
    puts "Tagging Nancy"

    Git.tag "v#{args.version}", false, "Tagged v#{args.version}"
    Git.execute_command 'push --tags'
  end

  task :update_project, :project, :version do |task, args|
    puts "Updating: #{args.project} to #{args.version}"

    Dir.logged_chdir get_project_directory(args.project) do
      Git.prep_submodules

      Dir.logged_chdir 'dependencies/Nancy' do
        Git.checkout 'master'
        Git.pull
        Git.checkout "v#{args.version}"
      end

      Git.commit_all "Updated submodule to #{args.version}"
    end
  end

  desc "Pushes all sub projects into github"
  task :push_subprojects do
    puts "Pushing subprojects.."

    sub_projects.each do |project|
      Dir.logged_chdir get_project_directory(project) do
        puts "Updating: #{project}"

        Git.push 'origin/master'
      end
    end
  end

  def get_project_directory(project)
    "../#{project}"
  end
end
