require_relative 'vcs'

module Covet
  module Utils
    # Converts given filename or glob path to absolute paths and checks for their
    # existence. If file is not found, warns and returns an empty array. If given relative
    # non-glob file path, converts it using the following heuristic:
    #   1) If the file exists relative to the current working directory, convert and return its absolute path.
    #   2) If the file exists relative to the VCS repository root, convert and return its absolute path.
    #   3) Otherwise, warn and return empty list.
    # @return Array<String>
    def self.convert_to_absolute_paths!(fname_or_glob, options = {})
      if options[:allow_globs] && fname_or_glob.include?('*')
        return Dir.glob(fname_or_glob).map { |fname| convert_to_absolute_paths!(fname) }.flatten
      end
      # absolute path
      if fname_or_glob.start_with?(File::SEPARATOR)
        if File.exist?(fname_or_glob)
          return [fname_or_glob]
        else
          warn "File '#{fname_or_glob}' doesn't exist"
          return []
        end
      end
      # relative path
      if File.exist?(abs = File.join(Dir.pwd, fname_or_glob))
        return [abs]
      end
      if File.exist?(abs = File.join(VCS.repository_root, fname_or_glob))
        return [abs]
      end
      warn "File '#{fname_or_glob}' doesn't exist"
      []
    end
  end
end
