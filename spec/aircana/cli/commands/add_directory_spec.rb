# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require_relative "../../../../lib/aircana/cli/commands/add_directory"

RSpec.describe Aircana::CLI::AddDirectory do
  let(:test_dir) { File.join(Dir.pwd, "spec_test_#{Time.now.to_i}_#{rand(1000)}") }
  let(:relevant_files_dir) { File.join(Dir.pwd, "spec_relevant_#{Time.now.to_i}_#{rand(1000)}") }

  before do
    FileUtils.mkdir_p(test_dir)
    FileUtils.mkdir_p(relevant_files_dir)

    allow(Aircana).to receive_message_chain(:configuration, :relevant_project_files_dir).and_return(relevant_files_dir)
    allow(Aircana).to receive(:create_dir_if_needed)

    @log_messages = []
    logger_double = instance_double("Logger")
    allow(logger_double).to receive(:info) { |msg| @log_messages << [:info, msg] }
    allow(logger_double).to receive(:warn) { |msg| @log_messages << [:warn, msg] }
    allow(logger_double).to receive(:error) { |msg| @log_messages << [:error, msg] }
    allow(logger_double).to receive(:debug) { |msg| @log_messages << [:debug, msg] }
    allow(Aircana).to receive(:logger).and_return(logger_double)

    # Mock the RelevantFiles context
    allow(Aircana::Contexts::RelevantFiles).to receive(:remove_all)
    allow(Aircana::Contexts::RelevantFiles).to receive(:add)
  end

  after do
    FileUtils.rm_rf(test_dir)
    FileUtils.rm_rf(relevant_files_dir)
  end

  describe ".run" do
    context "when directory does not exist" do
      it "logs an error and returns early" do
        non_existent_dir = "/path/that/does/not/exist"

        described_class.run(non_existent_dir)

        expect(@log_messages).to include([:error, "Directory not found: #{non_existent_dir}"])
        expect(Aircana::Contexts::RelevantFiles).not_to have_received(:add)
      end
    end

    context "when directory is not readable" do
      it "logs an error and returns early" do
        unreadable_dir = "/path/to/unreadable/dir"

        # Mock File.directory? and File.readable? for this test
        allow(File).to receive(:directory?).with(unreadable_dir).and_return(true)
        allow(File).to receive(:readable?).with(unreadable_dir).and_return(false)

        described_class.run(unreadable_dir)

        expect(@log_messages).to include([:error, "Directory not readable: #{unreadable_dir}"])
        expect(Aircana::Contexts::RelevantFiles).not_to have_received(:add)
      end
    end

    context "when directory is empty" do
      it "logs info message and returns early" do
        described_class.run(test_dir)

        expect(@log_messages).to include([:info, "No files found in directory: #{test_dir}"])
        expect(Aircana::Contexts::RelevantFiles).not_to have_received(:add)
      end
    end

    context "when directory contains files" do
      before do
        # Create test files
        File.write(File.join(test_dir, "file1.rb"), "puts 'hello world'")
        File.write(File.join(test_dir, "file2.js"), "console.log('hello');")

        # Create subdirectory with files
        subdir = File.join(test_dir, "subdir")
        FileUtils.mkdir_p(subdir)
        File.write(File.join(subdir, "nested.txt"), "nested content")
      end

      it "finds all files recursively and adds them to relevant files" do
        described_class.run(test_dir)

        expect(@log_messages).to include([:info, "Found 3 files in directory: #{test_dir}"])
        expect(@log_messages).to include([:info, "Successfully added 3 files from directory"])

        expect(Aircana::Contexts::RelevantFiles).to have_received(:add) do |files|
          expect(files).to be_an(Array)
          expect(files.length).to eq(3)
          expect(files.map { |f| File.basename(f) }).to contain_exactly("file1.rb", "file2.js", "nested.txt")
        end
      end

      context "when directory has many files" do
        before do
          # Create 101 more files to trigger warning
          101.times { |i| File.write(File.join(test_dir, "file#{i}.txt"), "content #{i}") }
        end

        it "warns about high token usage for large directories" do
          described_class.run(test_dir)

          expect(@log_messages).to include([:warn, "Large number of files (104) may result in high token usage"])
        end
      end
    end

    context "with ignored file patterns" do
      before do
        # Create files that should be ignored
        FileUtils.mkdir_p(File.join(test_dir, ".git"))
        File.write(File.join(test_dir, ".git", "config"), "git config")

        FileUtils.mkdir_p(File.join(test_dir, "node_modules"))
        File.write(File.join(test_dir, "node_modules", "package.json"), "{}")

        File.write(File.join(test_dir, ".DS_Store"), "mac metadata")
        File.write(File.join(test_dir, "image.jpg"), "fake image data")
        File.write(File.join(test_dir, "video.mp4"), "fake video data")
        File.write(File.join(test_dir, "archive.zip"), "fake archive")

        # Create files that should be included
        File.write(File.join(test_dir, "valid_file.rb"), "ruby code")
        File.write(File.join(test_dir, "README.md"), "documentation")
      end

      it "filters out ignored files and includes valid ones" do
        described_class.run(test_dir)

        expect(Aircana::Contexts::RelevantFiles).to have_received(:add) do |files|
          basenames = files.map { |f| File.basename(f) }

          # Should include valid files
          expect(basenames).to include("valid_file.rb", "README.md")

          # Should exclude ignored files
          expect(basenames).not_to include("config", "package.json", ".DS_Store", "image.jpg", "video.mp4",
                                           "archive.zip")
        end
      end
    end
  end

  describe "file collection (private methods)" do
    before do
      # Create test file structure
      File.write(File.join(test_dir, "root.txt"), "root content")

      subdir1 = File.join(test_dir, "subdir1")
      FileUtils.mkdir_p(subdir1)
      File.write(File.join(subdir1, "sub1.txt"), "sub1 content")

      subdir2 = File.join(test_dir, "subdir1", "subdir2")
      FileUtils.mkdir_p(subdir2)
      File.write(File.join(subdir2, "sub2.txt"), "sub2 content")
    end

    it "returns all files recursively" do
      files = described_class.send(:collect_files_recursively, test_dir)

      expect(files).to be_an(Array)
      expect(files.length).to eq(3)

      basenames = files.map { |f| File.basename(f) }
      expect(basenames).to contain_exactly("root.txt", "sub1.txt", "sub2.txt")
    end

    it "excludes directories from results" do
      files = described_class.send(:collect_files_recursively, test_dir)

      files.each do |file|
        expect(File.file?(file)).to be true
        expect(File.directory?(file)).to be false
      end
    end
  end

  describe "ignore patterns (private methods)" do
    it "ignores .git directory files" do
      expect(described_class.send(:should_ignore_file?, "/project/.git/config")).to be true
    end

    it "ignores node_modules directory files" do
      expect(described_class.send(:should_ignore_file?, "/project/node_modules/package.json")).to be true
    end

    it "ignores .DS_Store files" do
      expect(described_class.send(:should_ignore_file?, "/project/.DS_Store")).to be true
    end

    it "ignores image files" do
      expect(described_class.send(:should_ignore_file?, "/project/image.jpg")).to be true
      expect(described_class.send(:should_ignore_file?, "/project/IMAGE.PNG")).to be true
    end

    it "ignores video files" do
      expect(described_class.send(:should_ignore_file?, "/project/video.mp4")).to be true
      expect(described_class.send(:should_ignore_file?, "/project/VIDEO.AVI")).to be true
    end

    it "ignores archive files" do
      expect(described_class.send(:should_ignore_file?, "/project/archive.zip")).to be true
      expect(described_class.send(:should_ignore_file?, "/project/backup.tar.gz")).to be true
    end

    it "ignores build directories" do
      expect(described_class.send(:should_ignore_file?, "/project/dist/bundle.js")).to be true
      expect(described_class.send(:should_ignore_file?, "/project/build/output.js")).to be true
    end

    it "does not ignore regular source files" do
      expect(described_class.send(:should_ignore_file?, "/project/src/main.rb")).to be false
      expect(described_class.send(:should_ignore_file?, "/project/README.md")).to be false
      expect(described_class.send(:should_ignore_file?, "/project/config.yml")).to be false
    end
  end
end
