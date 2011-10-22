class Executor
  @@debug = false

  def self.execute_command(command, args = "")
    if @@debug
        puts "[#{command} #{args}]"
      else
        sh "#{command} #{args}"
    end
  end
end