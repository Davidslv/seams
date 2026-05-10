# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "seams/generators/follow_up_generator"

RSpec.describe Seams::Generators::FollowUpGenerator do
  let(:destination_root) { File.expand_path("../../tmp/follow_up_generator_spec", __dir__) }
  let(:engine_dir) { File.join(destination_root, "engines/auth") }

  let(:generator_class) do
    Class.new(described_class) do
      engine_name "auth"
    end
  end

  let(:generator) do
    generator_class.new([], [], destination_root: destination_root)
  end

  before do
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(File.join(engine_dir, "lib/auth"))
  end

  after { FileUtils.rm_rf(destination_root) }

  describe ".engine_name" do
    it "raises a clear error when a subclass forgets to declare it" do
      undeclared = Class.new(described_class)
      expect { undeclared.engine_name }.to raise_error(ArgumentError, /must declare/)
    end
  end

  describe "#engine_path" do
    it "resolves a relative path inside the host's engines/<engine>/" do
      expect(generator.engine_path("lib/auth/engine.rb")).to eq(
        File.join(destination_root, "engines/auth/lib/auth/engine.rb")
      )
    end
  end

  describe "#assert_marker_exists!" do
    it "is a no-op when the marker is present" do
      File.write(File.join(engine_dir, "lib/auth/engine.rb"), <<~RUBY)
        module Auth
          # seams:insertion-point auth.engine.events
        end
      RUBY

      expect do
        generator.assert_marker_exists!(file: "lib/auth/engine.rb", marker: "auth.engine.events")
      end.not_to raise_error
    end

    it "raises Seams::GeneratorError when the marker is missing" do
      File.write(File.join(engine_dir, "lib/auth/engine.rb"), "module Auth; end\n")

      error = capture_assert_error("auth.engine.events")
      expect(error.message).to include("auth.engine.events")
      expect(error.message).to include("engines/auth/lib/auth/engine.rb")
      expect(error.message).to include("bin/rails generate seams:auth")
    end

    def capture_assert_error(marker)
      generator.assert_marker_exists!(file: "lib/auth/engine.rb", marker: marker)
      raise "expected Seams::GeneratorError but none raised"
    rescue Seams::GeneratorError => e
      e
    end

    it "raises Seams::GeneratorError when the engine file is missing entirely" do
      expect do
        generator.assert_marker_exists!(file: "lib/auth/engine.rb", marker: "auth.engine.events")
      end.to raise_error(Seams::GeneratorError, /not found/)
    end
  end
end
