require_relative '../lib/covet'
require_relative 'fakelib'
gem 'minitest'
begin
  require 'minitest' # minitest 5
  Minitest.autorun
rescue LoadError
  require 'minitest/unit' # minitest 4
  require 'minitest/autorun'
end
require 'rugged'
require 'tmpdir'
require 'fileutils'

Covet::CollectionFilter.whitelist_gem('covet')
Covet.register_coverage_collection!

class CovetUnitTest < defined?(Minitest::Test) ? Minitest::Test : Minitest::Unit::TestCase

  def setup
    Covet::BASE_COVERAGE.update({})
  end

  def coverage_before_and_after(&block)
    Covet.coverage_before_and_after(&block)
  end

  def generate_run_list_for_method(before, after, options = {})
    Covet.generate_run_list_for_method(before, after, options)
  end

  def change_file(fname, lineno, new_line) # yields
    check_file_exists!(fname)
    new_line << "\n" unless new_line.end_with?("\n")
    contents = File.read(fname).lines.to_a
    old_contents = contents.dup
    old_line = contents[lineno - 1]
    if old_line.nil?
      raise ArgumentError, "invalid line number for #{fname}: #{lineno}"
    end
    contents[lineno - 1] = new_line
    File.open(fname, 'w') do |f|
      f.write contents.join
    end
    yield
  ensure
    if old_contents
      File.open(fname, 'w') do |f|
        f.write old_contents.join
      end
    end
  end

  def method_in_coverage_info?(info, method)
    # TODO
  end

  def remove_file(fname) # yields
    check_file_exists!(fname)
    # TODO
  end

  def rename_file(fname, new_name) # yields
    check_file_exists!(fname)
    # TODO
  end

  def add_file(fname, contents) # yields
    check_file_doesnt_exist!(fname)
    # TODO
  end

  def with_collection_filter(filter) # yields
    # TODO
  end

  private

    def check_file_exists!(fname)
      unless File.exist?(fname)
        raise ArgumentError, "file doesn't exist: #{fname}"
      end
    end

    def check_file_doesnt_exist!(fname)
      if File.exist?(fname)
        raise ArgumentError, "file already exists: #{fname}"
      end
    end

end

class CovetIntegrationTest < defined?(Minitest::Test) ? Minitest::Test : Minitest::Unit::TestCase
  def with_new_repo(template: 'proj1', commit: true) # yields Rugged::Repository
    Dir.mktmpdir do |tmp|
      Dir.chdir(tmp) do
        if template
          @current_template = template
          FileUtils.cp_r template_files(template), tmp
          FileUtils.cp_r shared_template_files, tmp
          system('bundle install --quiet') or raise "bundle install failed"
          if commit
            system('git init > /dev/null && git add --all && git commit -m "first commit" > /dev/null') or raise "repo creation failed"
          end
        end
        repo = Rugged::Repository.new(tmp)
        yield repo
      end
    end
  end

  def run_covet_collect!
    assert_collected do
      template_run(%Q(bundle exec covet -c "rake test"))
    end
  end

  def template_run(cmd, expect_success: true, silence_output: true)
    covet_path = File.expand_path('../../', __FILE__)
    out, err = capture_subprocess_io do
      system("COVET_PATH='#{Shellwords.escape(covet_path)}' COVET_DEBUG=0 #{cmd}")
    end
    if $?.exitstatus != 0 && expect_success
      assert false, "command #{cmd} failed with status #{$?.exitstatus}"
    end
    unless silence_output
      STDOUT.puts out
      STDERR.puts err
    end
    [out, err]
  end

  def assert_collected # yields
    File.unlink('run_log.json') if File.exist?('run_log.json')
    File.unlink('run_log_index.json') if File.exist?('run_log_index.json')
    yield
    assert File.exist?('run_log.json'), "run_log.json should exist"
    assert File.exist?('run_log_index.json'), "run_log_index.json should exist"
  end

  private

    def template_files(tmpl)
      Dir.glob(File.join(template_path(tmpl), tmpl, '**/*'))
    end

    def template_path(tmpl)
      File.expand_path('../integration/repo_templates', __FILE__)
    end

    def template_file(tmpl, fname)
      File.join(template_path(tmpl), fname)
    end

    def change_file!(fname, changes)
      raise "file '#{fname}' doesn't exist" unless File.exist?(fname)
      old_contents_ary = File.readlines(fname)
      new_contents_ary = old_contents_ary.dup
      changes.each do |lineno, line|
        new_contents_ary[lineno - 1] = line
      end
      File.open(fname, 'w') { |f| f.write(new_contents_ary.join("\n")) }
    end

    def shared_template_files
      template_files('shared')
    end
end
