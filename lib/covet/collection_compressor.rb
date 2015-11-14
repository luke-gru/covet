module Covet
  module CollectionCompressor

    # Turn sparse Array returned from `Coverage.peek_result` into
    # more compact representation - a Hash of only the lines that
    # were executed at least once.
    # @param [Hash] coverage_info
    def self.compress(coverage_info)
      ret = {}
      coverage_info.each do |fname, cov_ary|
        ret[fname] ||= {}
        cov_ary.each_with_index do |times_run, idx|
          next if times_run.to_i == 0
          ret[fname][idx+1] = times_run # lineno = idx + 1
        end
      end
      ret
    end
  end
end
