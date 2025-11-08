# Rebar Authorization Schemas
# This file loads all schema definitions from the schemas directory

# Load all schema files
schema_files = Dir[File.join(__dir__, "*.rb")].reject { |f| f.end_with?("index.rb") }
schema_files.sort.each { |f| load f }

# Log loaded schemas
Rails.logger.info "Loaded #{AuthSchema.list_schemas.size} authorization schemas: #{AuthSchema.list_schemas.join(', ')}"
