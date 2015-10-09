module Covet
  # Gets lines that have changed since an arbitrary point in the VCS's
  # (Version Control System's) history.
  module LineChangesVCS
    # @return Set
    def self.changes_since(since = :last_commit)
      require_relative "vcs/#{Covet.vcs}"
      Covet::VCS.const_get(Covet.vcs.capitalize).changes_since(since)
    rescue LoadError
      raise ArgumentError, "#{self.class} can't get line changes using VCS: #{Covet.vcs} (not implemented)"
    end
  end
end
