# frozen_string_literal: true

# Entry point for the Seams custom RuboCop cops. Add this line to your
# host application's .rubocop.yml to enable boundary enforcement:
#
#   plugins:
#     - seams/cops
#
# All cops live under the RuboCop::Cop::Seams namespace.

require "rubocop"

require "seams/cops/no_cross_engine_model_access"
require "seams/cops/no_cross_engine_dependency"
require "seams/cops/known_queue_names"
require "seams/cops/migration_comments"
