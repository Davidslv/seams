# frozen_string_literal: true

require "fileutils"
require "seams/generators/dummy_app_writer"

RSpec.describe Seams::Generators::DummyAppWriter do
  let(:engine_path) { File.expand_path("../../tmp/dummy_app_writer/engines/example", __dir__) }
  let(:schema) do
    <<~SCHEMA
      create_table :examples do |t|
        t.string :name, null: false
        t.timestamps
      end
    SCHEMA
  end

  before { FileUtils.rm_rf(engine_path) }
  after  { FileUtils.rm_rf(engine_path) }

  describe ".write!" do
    before do
      described_class.write!(
        engine_path: engine_path,
        engine_module: "Example",
        mount_at: "/example",
        schema: schema,
        host_user: "class User < ApplicationRecord\nend\n"
      )
    end

    let(:expected_files) do
      %w[
        spec/dummy/config/boot.rb
        spec/dummy/config/application.rb
        spec/dummy/config/environment.rb
        spec/dummy/config/database.yml
        spec/dummy/config/environments/test.rb
        spec/dummy/config/initializers/secret_key.rb
        spec/dummy/config/routes.rb
        spec/dummy/db/schema.rb
        spec/dummy/app/models/application_record.rb
        spec/dummy/app/models/user.rb
        spec/dummy/app/controllers/application_controller.rb
        spec/dummy/log/.keep
        spec/dummy/tmp/.keep
        spec/spec_helper.rb
        spec/rails_helper.rb
      ]
    end

    it "creates the dummy app skeleton" do
      expected_files.each do |relative|
        expect(File.exist?(File.join(engine_path, relative))).to be(true), "missing #{relative}"
      end
    end

    it "wires application.rb to require the engine module's lib root" do
      content = File.read(File.join(engine_path, "spec/dummy/config/application.rb"))
      expect(content).to include('require "example"')
      expect(content).to include("module Dummy")
    end

    it "wires routes.rb to mount the engine at the specified path" do
      content = File.read(File.join(engine_path, "spec/dummy/config/routes.rb"))
      expect(content).to include('mount Example::Engine, at: "/example"')
    end

    it "wraps the supplied schema body inside ActiveRecord::Schema.define using the host's Rails version" do
      content = File.read(File.join(engine_path, "spec/dummy/db/schema.rb"))
      # Major.minor of whatever Rails is loaded — defaults to 8.1 when
      # called outside a Rails context (e.g. seams gem unit specs).
      expect(content).to match(/ActiveRecord::Schema\[\d+\.\d+\]\.define/)
      expect(content).to include("create_table :examples")
    end

    it "writes the supplied host User body" do
      content = File.read(File.join(engine_path, "spec/dummy/app/models/user.rb"))
      expect(content).to include("class User < ApplicationRecord")
    end

    it "writes a dummy ApplicationController that stubs authenticate_identity! as a no-op" do
      # Engine ApplicationControllers ship with `before_action
      # :authenticate_identity!` by default. Engine request specs run
      # against the dummy app's ApplicationController, which here must
      # expose the method so the before_action chain resolves rather
      # than raising NoMethodError. Specs that want to exercise the
      # unauthenticated path stub or override this method.
      content = File.read(File.join(engine_path, "spec/dummy/app/controllers/application_controller.rb"))
      expect(content).to include("class ApplicationController < ActionController::Base")
      expect(content).to match(/def authenticate_identity!/)
    end

    it "rails_helper.rb loads the dummy environment + schema" do
      content = File.read(File.join(engine_path, "spec/rails_helper.rb"))
      expect(content).to include('require File.expand_path("dummy/config/environment", __dir__)')
      expect(content).to include("load File.expand_path(\"dummy/db/schema.rb\", __dir__)")
    end
  end

  describe ".write! without mount or host User" do
    before do
      described_class.write!(
        engine_path: engine_path,
        engine_module: "Example",
        schema: schema
      )
    end

    it "still creates the boilerplate but skips routes mount + user.rb" do
      routes = File.read(File.join(engine_path, "spec/dummy/config/routes.rb"))
      expect(routes).not_to include("mount")
      expect(File.exist?(File.join(engine_path, "spec/dummy/app/models/user.rb"))).to be(false)
    end
  end
end
