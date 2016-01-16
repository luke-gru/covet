require_relative 'log_file'

module Covet
  # Collects coverage log information during test runs.
  class LogCollection
    attr_reader :flushes, :size

    def initialize(options = {})
      @bufsize = options[:bufsize] || 100 # max log buffer size to keep in memory
      @log_file = LogFile.new(:filename => options[:filename], :mode => 'w')
      @buf = []
      @flushes = 0
      @size = 0
    end

    # @param [Array] logs
    def <<(logs)
      unless Array === logs
        raise TypeError, "expecting Array, got #{logs.class}"
      end
      @buf << logs
      if @buf.size == @bufsize
        flush!
      end
      @size += 1
      true
    end
    alias :append :<<

    def finish!
      if @flushes == 0 && @buf.size == 0
        return # avoid writing to file if no collections
      end
      flush! if @buf.any?
      @log_file.write_end
      true
    end

    private

      # Flushes buffer to file
      def flush!
        if @flushes == 0
          @log_file.write_start
        end
        @log_file.write_buf(@buf)
        @buf.clear
        @flushes += 1
      end

  end
end
