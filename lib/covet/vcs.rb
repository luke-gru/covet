module Covet
  module VCS
    # Gets file and line numbers that have changed since an arbitrary point in the VCS's
    # (Version Control System's) history.
    # @return Set<Array>
    def self.changes_since(since = :last_commit)
      require_relative "vcs/#{Covet.vcs}"
      Covet::VCS.const_get(Covet.vcs.capitalize).changes_since(since)
    rescue LoadError
      raise NotImplementedError, "#{self.class} can't get line changes using VCS: #{Covet.vcs} (not implemented)"
    end

    # @return String|nil absolute path of VCS repository
    def self.repository_root
      require_relative "vcs/#{Covet.vcs}"
      Covet::VCS.const_get(Covet.vcs.capitalize).repository_root
    rescue LoadError
      raise NotImplementedError, "#{self.class} can't find repository root using: #{Covet.vcs} (not implemented)"
    end
  end
end
