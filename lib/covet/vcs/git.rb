module Covet
  module VCS
    module Git
      require 'rugged'

      # Find lines in git-indexed files that were changed (added/deleted/modified)
      # in the codebase since `revision`.
      # @raise Rugged::Error, Rugged::InvalidError, TypeError
      # @return Set<Array>
      def self.changes_since(revision = :last_commit)
        repo = Rugged::Repository.new(Dir.pwd)
        lines_to_run = Set.new
        diff = case revision.to_s
        when 'last_commit', 'HEAD'
          repo.index.diff
        else
          # raises Rugged::Error or TypeError if `revision` is invalid Git object id
          # (tag name or sha1, etc.)
          commit = Rugged::Commit.new(repo, revision)
          repo.index.diff(commit)
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

    end
  end
end
