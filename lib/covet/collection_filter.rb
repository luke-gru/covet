module Covet
  # Responsible for filtering out files that shouldn't be logged in the
  # `run_log` during the coverage collection and logging phase. For instance,
  # if using the `minitest` test runner, we shouldn't log coverage information
  # for internal `minitest` methods (unless we're using covet ON `minitest` itself),
  # (or `rake`, etc). This minimizes the amount of JSON we have to save in the `run_log`,
  # and also the amount of processing we have to do on the `run_log` structure when
  # generating the `run_list`.
  module CollectionFilter
    # TODO: look into filtering all active gems
    DEFAULT_GEM_FILTERS = %w(rspec minitest rake).freeze
    @@gem_filters = DEFAULT_GEM_FILTERS.dup
    @@custom_filters = [] # @var Array<Proc>
    @@file_whitelist = [] # @var Array<String>, full file path whitelist
    @@regexp_whitelist = [] # @var Array<Regexp>

    # @param String|Symbol gem_name
    def self.add_gem_filter(gem_name)
      @@gem_filters << gem_name.to_s
      @@gem_filters.uniq!
    end
    # @param String|Symbol gem_name
    def self.remove_gem_filter(gem_name)
      @@gem_filters.remove(gem_name.to_s)
    end
    # FIXME: should take filename AND method name
    # @param Proc filter, arity = 1, takes filename
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

    # @return Hash
    def self.filter(raw_coverage_info)
      raw_coverage_info = raw_coverage_info.dup
      gem_base_dirs = Gem::Specification.select(&:activated?).select do |spec|
        @@gem_filters.include?(spec.name)
      end.map do |spec|
        spec.full_gem_path
      end

      keys_to_delete = []

      raw_coverage_info.each do |filename, _|
        next if whitelisted_filename?(filename)
        # gem filters
        gem_base_dirs.each do |gem_base_dir|
          if filename.start_with?(gem_base_dir)
            keys_to_delete << filename
          end
        end
        next if keys_to_delete.include?(filename)

        # custom filters
        @@custom_filters.each do |filter|
          if filter.call(filename)
            keys_to_delete << filename
          end
        end
      end


      keys_to_delete.each do |fname|
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

  end
end
