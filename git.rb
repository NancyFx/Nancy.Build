include Rake::DSL

class Git
  @@debug = true
  @@git_command = "git"

  def self.checkout(branch)
    self.execute_command "checkout #{branch}"
  end

  def self.push(*branch)
    self.execute_command "push #{branch}"
  end

  def self.pull(*branch)
    self.execute_command "pull #{branch}"
  end

  def self.commit(message)
    self.execute_command "commit -m \"#{message}\""
  end

  def self.commit_all(message)
    self.execute_command "commit -am \"#{message}\""
  end

  def self.tag(tag)
    self.execute_command "tag #{tag}"
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