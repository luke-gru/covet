require 'json'
require 'tempfile'
require 'fileutils'

module Covet
  # Represents log file of JSON coverage information for each test method that ran.
  # For each write of a memory buffer to disk, a separate index file keeps track
  # of the file offset and bytes written for the buffer. This is so that when
  # there lots of tests in a test suite, we don't have to keep all coverage
  # information in memory. Instead, we flush the information and write it to
  # disk at certain intervals. This way, we can also load the information in
  # chunks as well, using the same index file.
  # NOTE: Although this works, it's no longer needed because the coverage
  # information that's logged is much, much less than when this class was
  # first introduced. To give you an idea, running `covet` on `activesupport`
  # used to produce a 1GB coverage log, and now produces around 4MB. This is
  # due to compression of the coverage format, filtering of gem coverage, and
  # only logging the coverage changes between each test.
  class LogFile

    LoadError = Class.new(StandardError)
    LoadIndexError = Class.new(StandardError)

    attr_reader :name, :writes, :index_file

    def initialize(options = {})
      @mode = options[:mode] || 'w'
      @name = options[:filename] || File.join(Dir.pwd, 'run_log.json')
      if @mode != 'r'
        # We only want to create the real file during the `write_end` method, so write to
        # a tempfile until then. This is in case the user stops their test suite with an
        # interrupt.
        @tmpfile = Tempfile.new(File.basename(@name))
        @tmpname = @tmpfile.path
      else
        @tmpfile = nil
        @tmpname = nil
      end
      @index_file = LogFileIndex.new(:filename => options[:index_filename])
      @writes = 0
    end

    def write_start
      check_can_write!
      @tmpfile.write('[')
      @writes += 1
    end

    def write_buf(buf)
      check_can_write!
      pos_start = @tmpfile.pos
      @tmpfile.write(JSON.dump(buf) + ',')
      @writes += 1
      pos_after = @tmpfile.pos
      @index_file.add_index(pos_start, pos_after - pos_start)
    end

    def write_end
      check_can_write!
      @tmpfile.pos -= 1 # remove final comma at end of array
      @tmpfile.write(']')
      @writes += 1
      @tmpfile.close
      FileUtils.cp(@tmpfile, @name)
      @index_file.finish!
    end

    # Load entire (unbounded) structure into memory without using buffers.
    def load!
      JSON.load(File.read(@name))
    rescue JSON::ParserError => e
      raise LogFile::LoadError, e.message
    end

    # Yields each coverage buffer (Array) one a time from the run log.
    # @raises LogFile::LoadError
    def load_each_buf! # yields
      unless block_given?
        return to_enum(__method__)
      end
      @index_file.reload!('r')
      reload!('r')
      index = load_index!
      index.each do |(pos, bytes_to_read)|
        res = load_buf_from_file!(pos, bytes_to_read)
        yield res # @var Array
      end
    end

    # @raises LogFile::LoadError, LogFileIndex::LoadError
    # @return Array
    def load_buf!(buf_idx)
      @index_file.reload!('r')
      reload!('r')
      index = load_index!
      pos, bytes_to_read = index[buf_idx]
      load_buf_from_file!(pos, bytes_to_read)
    end

    # Run statistics and meta-info is stored as the final buffer in the log file.
    # @raises LogFile::LoadError
    # @return Hash
    def load_run_stats!
      load_buf!(-1).last[-1]
    end

    def file_exists?
      File.exist?(@name)
    end

    # re-opens file, can raise Errno::ENOENT
    def reload!(mode)
      if @file && !@file.closed?
        @file.close
      end
      @file = File.open(@name, mode)
    end

    private

      def file
        @file ||= File.open(@name, @mode)
      end

      def check_can_write!
        if @mode == 'r'
          raise "For writing to the log file, you must construct it with a different :mode. Mode: '#{@mode}'"
        end
      end

      # @raises LogFile::LoadError
      # @return Array
      def load_buf_from_file!(pos, bytes_to_read)
        file.pos = pos
        buf = file.read(bytes_to_read)
        if buf.end_with?(',', ']]')
          buf = buf[0..-2]
        end
        JSON.load(buf)
      rescue JSON::ParserError => e
        raise LogFile::LoadError, e.message
      end

      # @return Array
      def load_index!
        JSON.load(File.read(@index_file.name))
      rescue JSON::ParserError => e
        raise LogFile::LoadIndexError, e.message
      end

  end

  class LogFileIndex
    attr_reader :name

    def initialize(options = {})
      @name = options[:filename] || File.join(Dir.pwd, 'run_log_index.json')
      @index = []
    end

    def add_index(offset, bytes_written)
      @index << [offset, bytes_written]
    end

    def finish!
      if @index.size > 0
        file.write(JSON.dump(@index))
        file.close
      end
    end

    def reload!(mode)
      if @file && !@file.closed?
        @file.close
      end
      @file = File.open(@name, mode)
    end

    private

      def file
        @file ||= File.open(@name, 'w')
      end
  end
end
