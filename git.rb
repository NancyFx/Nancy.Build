include Rake::DSL

class Git
  @@debug = true
  @@git_command = "git"

  def self.checkout(branch)
    self.execute_command "checkout #{branch}"
  end

  def self.push(*branch)
    self.execute_command "push #{branch.first if !branch.empty?}"
  end

  def self.pull(*branch)
    self.execute_command "pull #{branch.first if !branch.empty?}"
  end

  def self.add(files)
    self.execute_command "add #{files}"
  end

  def self.commit(message)
    self.execute_command "commit -m \"#{message}\""
  end

  def self.commit_all(message)
    self.execute_command "commit -am \"#{message}\""
  end

  def self.tag(tag, lightweight=true, *message)
    messageParameter = "-m \"#{message.first}\"" if !message.empty?

    self.execute_command "tag #{'-a' if !lightweight} #{tag} #{messageParameter}"
  end

  def self.push_tags()
    self.execute_command "push --tags"
  end

  def self.prep_submodules()
    self.execute_command "submodule init"
    self.execute_command "submodule update"
  end

  def self.execute_command(command)
    if @@debug
        puts "[#{@@git_command} #{command}]"
      else
        sh "#{@@git_command} #{command}"
    end
  end
end