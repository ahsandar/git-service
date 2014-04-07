module Git
  module GitHelper

    GIT = 'git'
    GIT_PULL = 'git pull'
    GIT_CLEAN = 'git clean -f'
    GIT_RESET = 'git reset --hard HEAD'
    GIT_MASTER = 'git checkout master'
    GIT_BRANCH = 'git branch'
    GIT_CHECKOUT = 'git checkout'


    def logger
      @log ||= Logger.new('git')
    end

    def cmd
      @git_cmd ||= CommandService.new
    end

    def execute_git_command(options, remote_repo_path)

      raise ScmServiceException.new "Cannot connect to git repository : #{remote_repo_path}" unless connected? remote_repo_path

      log.msg "executing git command...."
      destination = options[:destination]
      git_repo(options) do
        git_checkout(destination,options[:branch])
      end
      cmd_result = cmd.execute!
  
      raise ScmServiceException.new cmd_result unless $?.success? && File.exists?(destination)
      log.msg ".... code checked out"
      destination
    end

    def scm_host_name(remote_repo_path)
      remote_repo_path.scan(/@(.*):/).first.first rescue ''
    end

    def connected?(remote_repo_path)
      is_connected = false
      host_name = scm_host_name remote_repo_path
      unless host_name.empty?
        output = CommandService.run_now("ping -c 4 #{host_name}")
        is_connected = output=~/\s0\.0%\spacket\sloss/#("100% packet loss")
      end
      is_connected
    end

    def git_repo(options, &update_block)
      destination = options[:destination]
      git_clone(options)  unless (File.exists?( destination))
      git_fetch_branches(destination)
      update_block.call if block_given?
    end

    def git_clone(options)
      logger.msg "cloning code ... #{options.inspect}"
      cmd << GIT
      cmd << options[:action]
      cmd << options[:source]
      cmd << options[:destination]
      cmd.seperate_cmd
      cmd.execute!
    end

    def git_branches(destination, &block)
      logger.msg "git all branches #{destination}"
      output = git_branch(destination)
      output.each_line do |branch_name|
        yield branch_name if block_given? && !branch_name.blank?
      end
    end

    def git_fetch_branches(destination)
      logger.msg "git fetch all branches"
      git_branches destination do |branch|
        branch_name = sanitize_branch_name(branch)
        logger.msg "git fetch branch '#{branch_name}' on #{destination}"
        git_update(destination, branch_name)
        cmd.execute!
      end
    end

    def git_update(destination, branch)
      git_checkout(destination, branch)
      git_pull(destination, branch)
    end

    def git_checkout(destination, branch = 'master')
      logger.msg "checking out branch '#{branch}' #{destination} "
      destination_directory(destination) do
        cmd << "#{GIT_CHECKOUT} #{branch}"
      end
    end

    def git_pull(destination, branch)
      logger.msg "pulling branch '#{branch}'"
      destination_directory(destination) do
        cmd << GIT_PULL
      end
    end

    def destination_directory(destination, &block)
      cmd << 'cd'
      cmd << destination
      cmd.seperate_cmd
      cmd << reset_local_repository_cmd(destination)
      cmd.seperate_cmd
      if block_given?
        block.call
        cmd.seperate_cmd
      end
    end

    def git_branch(destination)
      CommandService.run_now(["cd #{destination}", GIT_BRANCH].join(';'))
    end

    def sanitize_branch_name(branch)
      branch.gsub('*','').strip
    end

    def repository_name(remote_repo_path)
      File.basename(remote_repo_path).gsub('.git','')
    end

    def reset_local_repository_cmd(path)
      ["cd #{path}", GIT_CLEAN,  GIT_RESET,  GIT_MASTER].join(';')
    end

    def remove_local_repository(local_repo_path)
      post_op_local_repository(local_repo_path) do |repo_path|
        log.msg "removing local_repository_path .... #{repo_path}"
        cmd.remove_entry_secure(repo_path)
      end
    end

    def reset_local_repository(local_repo_path)
      post_op_local_repository(local_repo_path) do |repo_path|
        log.msg "resetting local_repository_path .... #{repo_path}"
        CommandService.run_now(reset_local_repository_cmd(repo_path))
        log.msg "local_repository_path reset .... #{repo_path}"
      end
    end

    def post_op_local_repository(local_repo_path, &block)
      cmd.timestamp_log
      if (File.exists?(local_repo_path)) && (!DEBUG_MODE)
        yield local_repo_path if block_given?
      else
        log.msg "No repo at #{local_repository_path} or DEBUG_MODE is on"
      end
    end

  end
end