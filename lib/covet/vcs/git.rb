module Covet
  module VCS
    module Git
      require 'set'
      require 'rugged'

      # Find lines in git-indexed files that were changed (added/deleted/modified)
      # in the codebase since `revision`.
      # @param [String|Symbol] revision, commit revision hash or special symbol
      #   representing a commit.
      # @raise Rugged::Error, Rugged::InvalidError, TypeError
      # @return Set<Array>
      def self.changes_since(revision = :last_commit)
        repo = Rugged::Repository.new(repository_root) # raises if can't find git repo
        lines_to_run = Set.new
        diff = case revision.to_s
        when 'last_commit', 'HEAD'
          repo.index.diff
        else
          # raises Rugged::Error or TypeError if `revision` is invalid Git object id
          # (tag name or sha1, etc.)
          commit = Rugged::Commit.new(repo, revision)
          repo.index.diff(commit, {}) # NOTE: for some reason, this call doesn't work properly if the second argument isn't given. Bug in rugged?
        end
        diff.each_patch { |patch|
          file = patch.delta.old_file[:path] # NOTE: old file is the index's version

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
      # @return String|nil, absolute path of repository
      def self.repository_root
        @repository_root ||= begin
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
          found || nil
        ensure
          Dir.chdir(orig_dir) if Dir.pwd != orig_dir
        end
      end

    end
  end
end
