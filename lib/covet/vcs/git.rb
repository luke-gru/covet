module Covet
  module VCS
    module Git
      require 'rugged'
      # @return Set
      def self.changes_since(since = :last_commit)
        repo = Rugged::Repository.new '.'
        lines_to_run = Set.new
        diff = case since
        when :last_commit
          repo.index.diff
        else
          raise NotImplementedError # FIXME: not yet implemented
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
                # Do nothing. FIXME: should we do something?
              end
            }
          }
        }
        lines_to_run
      end
    end
  end
end
