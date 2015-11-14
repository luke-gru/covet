require 'json'

module Covet
  # Represents log file of JSON coverage information for each test method.
  # For each write of a memory buffer to disk, a separate index file keeps track
  # of the file offset and bytes written for the buffer. This is so that when
  # there lots of tests in a test suite, we don't have to keep all coverage
  # information in memory. Instead, we flush the information and write it to
  # disk at certain intervals. This way, we can also load the information in
  # chunks as well, using the same index file.
  #
  # TODO: have way to rollback log file if interrupt occurs. Or just have it
  # be a tempfile until after the suite is done, then it's renamed.
  class LogFile

    LoadError = Class.new(StandardError)

    attr_reader :name, :writes

    def initialize(options = {})
      @name = options[:filename] || File.join(Dir.pwd, 'run_log.json')
      @index_file = LogFileIndex.new(:filename => options[:index_filename])
      @writes = 0
    end

    def write_start
      file.write('[')
      @writes += 1
    end

    def write_buf(buf)
      pos_start = file.pos
      file.write(JSON.dump(buf) + ',')
      @writes += 1
      pos_after = file.pos
      @index_file.add_index(pos_start, pos_after - pos_start)
    end

    def write_end
      file.pos -= 1 # remove final comma at end of array
      file.write(']')
      @writes += 1
      file.close
      @index_file.finish!
    end

    def load!
      JSON.load(File.read(@name))
    end

    # Yields each coverage buffer (Array) one a time from the run log.
    def load_each_buf! # yields
      @index_file.reload('r')
      reload('r')
      index = JSON.load(File.read(@index_file.name))
      index.each do |(pos, bytes_to_read)|
        file.pos = pos
        buf = file.read(bytes_to_read)
        if buf.end_with?(',', ']]')
          buf = buf[0..-2]
        end
        res = JSON.load(buf)
        yield res # @var Array
      end
    rescue JSON::ParserError => e
      raise LogFile::LoadError, e.message
    end

    def file_exists?
      File.exist?(@name)
    end

    # re-opens file
    def reload(mode)
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

    def reload(mode)
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
