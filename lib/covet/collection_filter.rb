require 'rbconfig'
require 'set'

module Covet
  # Responsible for filtering out files that shouldn't be logged in the
  # `run_log` during the coverage collection phase. For instance, if using
  # the `minitest` test runner, we shouldn't log coverage information
  # for internal `minitest` methods (unless we're using covet ON `minitest` itself),
  # The same goes for `rake`, etc. This minimizes the amount of JSON we have to save
  # in the `run_log`, and also the amount of processing we have to do on the `run_log`
  # structure when generating the `run_list`.
  module CollectionFilter
    if (gem_whitelist = ENV['COVET_GEM_WHITELIST'])
      @@gem_whitelist = gem_whitelist.split(',').reject(&:empty?)
    else
      @@gem_whitelist = []
    end
    @@custom_filters = [] # @var Array<Proc>
    @@file_whitelist = [] # @var Array<String>, full file path whitelist
    @@regexp_whitelist = [] # @var Array<Regexp>
    @@filter_stats = Hash.new { |h,k| h[k] = Set.new } # @var Hash<String => Set>, holds info on which files were blacklisted or whitelisted from `run_log`

    # @param String|Symbol gem_name
    def self.whitelist_gem(gem_name)
      @@gem_whitelist << gem_name.to_s
    end

    # FIXME: should take filename AND method name
    # @param [Proc] filter, arity = 1, takes filename
    def self.add_custom_filter(&filter)
      @@custom_filters << filter
    end
    def self.add_to_file_whitelist(fname)
      unless fname.start_with?(File::SEPARATOR)
        raise ArgumentError, "expected #{fname} to be an absolute path"
      end
      @@file_whitelist << fname
    end
    def self.add_to_regexp_whitelist(regexp)
      @@regexp_whitelist << regexp
    end

    def self.files_filtered
      Hash[@@filter_stats.map { |k, v| [k, v.to_a] }]
    end

    # @return Hash
    def self.filter(raw_coverage_info)
      raw_coverage_info = raw_coverage_info.dup
      # NOTE: The list of activated gems isn't cached, because it could be
      # that a test method activates a gem or calls code that activates a
      # gem. In that case, we want to omit the newly activated gem from the
      # run log as well (unless it's whitelisted).
      gem_base_dirs_to_omit = Gem.loaded_specs.values.reject do |spec|
        @@gem_whitelist.include?(spec.name)
      end.map do |spec|
        spec.full_gem_path
      end

      files_to_omit = []

      # find file names to omit from the run log
      raw_coverage_info.each do |filename, _|
        if whitelisted_filename?(filename)
          @@filter_stats['whitelisted'] << filename
          next # don't omit
        end

        if filename.start_with?(ruby_stdlib_dir)
          @@filter_stats['stdlib_files'] << filename
          files_to_omit << filename
          next
        end

        omitted = gem_base_dirs_to_omit.find do |gem_base_dir|
          if filename.start_with?(gem_base_dir)
            @@filter_stats['gem_files'] << filename
            files_to_omit << filename
          end
        end
        next if omitted

        # custom filters
        @@custom_filters.find do |filter|
          if filter.call(filename)
            @@filter_stats['custom_filters'] << filename
            files_to_omit << filename
          end
        end
      end

      files_to_omit.each do |fname|
        raw_coverage_info.delete(fname)
      end

      raw_coverage_info
    end

    private

      def self.whitelisted_filename?(filename)
        if @@file_whitelist.include?(filename)
          return true
        end
        @@regexp_whitelist.find { |re| re === filename }
      end

      def self.ruby_stdlib_dir
        RbConfig::CONFIG['libdir']
      end

  end
end
