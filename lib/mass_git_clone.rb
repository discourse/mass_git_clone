# frozen_string_literal: true

require "fileutils"
require "open3"
require "parallel"

def run(*args)
  out, err, status = Open3.capture3(*args)
  raise <<~ERROR if !status.success?
    Status #{status.exitstatus} running #{args.inspect}

    stdout:
    #{out}

    stderr:
    #{err}
  ERROR
  out
end

def prefixed_puts(str)
  prefix = "[reset-all-repos]"
  if n = Parallel.worker_number
    prefix += "[t#{n}]"
  end
  print "#{prefix} #{str}\n"
end

# Clone or update a repo with the given URL
# On failure, return the repo url
# On success, return nil
def update_repo(repo_url)
  dir_name = File.basename(repo_url, ".git")
  if Dir.exist?(dir_name)
    prefixed_puts "Updating #{dir_name}..."

    run "git", "-C", dir_name, "stash", "-u", "--quiet", "-m", "autostashed by mass_git_clone"

    run "git", "-C", dir_name, "remote", "set-url", "origin", repo_url
    run "git", "-C", dir_name, "remote", "set-head", "origin", "-a"

    default_branch =
      File.basename(
        run("git", "-C", dir_name, "symbolic-ref", "--short", "refs/remotes/origin/HEAD").strip
      )

    run "git", "-C", dir_name, "checkout", "-f", default_branch
    run "git", "-C", dir_name, "fetch", "origin", default_branch
    run "git", "-C", dir_name, "reset", "--hard", "origin/#{default_branch}"
    run "git", "-C", dir_name, "clean", "-f", "-d"
  else
    prefixed_puts "Cloning #{dir_name}..."
    run "git", "clone", "--quiet", repo_url, dir_name
  end
  nil
rescue => e
  prefixed_puts "Error while working on #{repo_url}\n\n#{e.message}"
  repo_url
end

module MassGitClone
  def self.mass_clone(repo_base_dir:, repo_list:)
    use_ssh =
      begin
        run "git", "ls-remote", "git@github.com:discourse/discourse", "main"
        prefixed_puts "Using SSH for GitHub..."
        true
      rescue => e
        prefixed_puts "SSH failed. Using https for GitHub..."
        false
      end

    all_repos = repo_list.map(&:strip).filter { |l| l.length > 0 }
    if all_repos.size === 0
      prefixed_puts "No plugin URLs supplied"
      exit 1
    end

    all_repos =
      all_repos.map do |repo|
        if !repo.match?(%r{\A[\w-]+/[\w-]+\z})
          repo # Full URL, leave untouched
        elsif use_ssh
          "git@github.com:#{repo}"
        else
          "https://github.com/#{repo}"
        end
      end

    Dir.mkdir(repo_base_dir) if !Dir.exist?(repo_base_dir)

    Dir.chdir(repo_base_dir) do
      failures =
        Parallel
          .map(all_repos, in_threads: ENV["PARALLEL"]&.to_i || 10) do |repo_url|
            update_repo(repo_url)
          end
          .reject(&:nil?)

      final_dirs = Dir.glob("*")
      expected_dirs = Set.new(all_repos.map { |r| File.basename(r, ".git") })
      to_delete = final_dirs.reject { |dir| expected_dirs.include?(dir) }

      if to_delete.any?
        puts
        prefixed_puts "Deleting #{to_delete.size} stale directories"
        to_delete.each { |dir| FileUtils.rm_rf(dir) }
      end

      puts
      if failures.any?
        prefixed_puts "#{failures.count} repo(s) failed to update"
        prefixed_puts failures.map { |url| "    #{url}" }.join("\n")
        exit 1
      else
        prefixed_puts "Done - all repositories are up-to-date 🚀"
      end
    end
  end
end
