include Rake::DSL
require './executor'

class Git
  @@git_command = "git"

  def self.clone(url)
    Executor.execute_command @@git_command, "clone #{url}"
  end

  def self.checkout(branch)
    Executor.execute_command @@git_command, "checkout #{branch}"
  end

  def self.push(*branch)
    Executor.execute_command @@git_command, "push #{branch.first if !branch.empty?}"
  end

  def self.pull(*branch)
    Executor.execute_command @@git_command, "pull #{branch.first if !branch.empty?}"
  end

  def self.add(files)
    Executor.execute_command @@git_command, "add #{files}"
  end

  def self.commit(message)
    Executor.execute_command @@git_command, "commit -m \"#{message}\""
  end

  def self.commit_all(message)
    Executor.execute_command @@git_command, "commit -am \"#{message}\""
  end

  def self.tag(tag, lightweight=true, *message)
    message_parameter = ''
    message_parameter = "-m \"#{message.first}\"" if !message.empty?

    Executor.execute_command @@git_command, "tag #{'-a' if !lightweight} #{tag} #{message_parameter}"
  end

  def self.push_tags()
    Executor.execute_command @@git_command, "push --tags"
  end

  def self.prep_submodules()
    Executor.execute_command @@git_command, "submodule init"
    Executor.execute_command @@git_command, "submodule update"
  end
end