module Covet
  module VCS
    module Git
      require 'rugged'

      # Find lines in git-indexed files that were changed (added/deleted/modified)
      # in the codebase since `revision`.
      # @raise Rugged::Error, Rugged::InvalidError, TypeError
      # @return Set<Array>
      def self.changes_since(revision = :last_commit)
        repo = Rugged::Repository.new(find_git_repo_path!) # raises if can't find git repo
        lines_to_run = Set.new
        diff_opts = {
          :ignore_whitespace => true,
          :ignore_filemode => true,
        }
        diff = case revision.to_s
        when 'last_commit', 'HEAD'
          repo.index.diff(diff_opts)
        else
          # raises Rugged::Error or TypeError if `revision` is invalid Git object id
          # (tag name or sha1, etc.)
          commit = Rugged::Commit.new(repo, revision)
          repo.index.diff(commit, diff_opts)
        end
        diff.each_patch { |patch|
          file = patch.delta.old_file[:path]

          patch.each_hunk { |hunk|
            hunk.each_line { |line|
              case line.line_origin
              when :addition
                lines_to_run << [file, line.new_lineno]
              when :deletion
                lines_to_run << [file, line.old_lineno]
              when :context
                lines_to_run << [file, line.new_lineno]
              end
            }
          }
        }
        lines_to_run
      end

      # find git repository path at or below `Dir.pwd`
      def self.find_git_repo_path!
        dir = orig_dir = Dir.pwd
        found = Dir.exist?('.git') && dir
        while !found && dir && Dir.exist?(dir)
          old_dir = Dir.pwd
          Dir.chdir('..')
          dir = Dir.pwd
          return if old_dir == dir # at root directory
          if dir && Dir.exist?('.git')
            found = dir
          end
        end
        found
      ensure
        Dir.chdir(orig_dir) if Dir.pwd != orig_dir
      end

    end
  end
end
