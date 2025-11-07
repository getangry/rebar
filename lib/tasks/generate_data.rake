namespace :data do
  desc "Generate large-scale test data: 1M actors, 20 entity types, 10+ relationships per actor"
  task generate_large: :environment do
    include ProgressHelper

    tenant_id = ENV['TENANT'] || 'default'
    service_id = ENV['SERVICE_ID'] || 'load-test'
    num_actors = ENV['ACTORS']&.to_i || 1_000_000
    relationships_per_actor = ENV['RELATIONSHIPS']&.to_i || 10

    puts "🚀 Starting large-scale data generation"
    puts "   Tenant: #{tenant_id}"
    puts "   Service: #{service_id}"
    puts "   Actors: #{num_actors.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "   Relationships per actor: #{relationships_per_actor}"
    puts "   Total relationships: ~#{(num_actors * relationships_per_actor).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts ""

    # Define entity types and their IDs
    entity_types = {
      document: { count: 500_000, prefix: 'doc' },
      folder: { count: 100_000, prefix: 'folder' },
      project: { count: 50_000, prefix: 'proj' },
      workspace: { count: 20_000, prefix: 'ws' },
      team: { count: 10_000, prefix: 'team' },
      department: { count: 5_000, prefix: 'dept' },
      organization: { count: 1_000, prefix: 'org' },
      repository: { count: 100_000, prefix: 'repo' },
      issue: { count: 300_000, prefix: 'issue' },
      pull_request: { count: 200_000, prefix: 'pr' },
      comment: { count: 500_000, prefix: 'comment' },
      wiki_page: { count: 50_000, prefix: 'wiki' },
      dashboard: { count: 30_000, prefix: 'dash' },
      report: { count: 40_000, prefix: 'report' },
      dataset: { count: 25_000, prefix: 'data' },
      pipeline: { count: 15_000, prefix: 'pipe' },
      secret: { count: 20_000, prefix: 'secret' },
      api_key: { count: 30_000, prefix: 'key' },
      webhook: { count: 10_000, prefix: 'hook' },
      integration: { count: 5_000, prefix: 'int' }
    }

    # Relationship patterns
    relations = [:owner, :editor, :viewer, :admin, :member, :contributor, :reviewer, :maintainer]

    batch_size = 10_000
    total_tuples = 0
    start_time = Time.now

    puts "📊 Phase 1: Creating actors (users and groups)"
    puts "=" * 60

    # Create user actors
    user_batches = (num_actors / batch_size.to_f).ceil

    user_batches.times do |batch_idx|
      batch_start = batch_idx * batch_size
      batch_end = [batch_start + batch_size, num_actors].min
      batch_count = batch_end - batch_start

      tuples = []

      # Every 10 users, create a group and make them members
      groups_in_batch = batch_count / 10
      groups_in_batch.times do |group_idx|
        group_id = "group-#{batch_start / 10 + group_idx}"
        base_user_idx = batch_start + (group_idx * 10)

        # Add 10 users to each group
        10.times do |user_offset|
          user_id = "user-#{base_user_idx + user_offset}"
          tuples << {
            tenant_id: tenant_id,
            subject: 'group',
            id: group_id,
            relation: 'member',
            actor: 'user',
            actor_id: user_id,
            actor_rel: nil
          }
        end
      end

      # Bulk insert
      if tuples.any?
        ActiveRecord::Base.connection.execute(
          "INSERT INTO rel_tuples (tenant_id, subject, id, relation, actor, actor_id, actor_rel, created_at) VALUES " +
          tuples.map { |t|
            "(#{ActiveRecord::Base.connection.quote(t[:tenant_id])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:subject])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:id])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:relation])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:actor])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:actor_id])}, " +
            "NULL, NOW())"
          }.join(", ") +
          " ON CONFLICT DO NOTHING"
        )
        total_tuples += tuples.size

        progress = ((batch_idx + 1) * 100.0 / user_batches).round(1)
        elapsed = Time.now - start_time
        rate = total_tuples / elapsed
        eta = (num_actors * relationships_per_actor - total_tuples) / rate

        puts "   Batch #{batch_idx + 1}/#{user_batches} (#{progress}%) | " +
             "Tuples: #{total_tuples.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} | " +
             "Rate: #{rate.round(0)}/sec | " +
             "ETA: #{(eta / 60).round(1)}min"
      end
    end

    puts ""
    puts "📊 Phase 2: Creating entity relationships"
    puts "=" * 60

    # Distribute relationships across entity types
    entity_types.each do |entity_type, config|
      puts "\n   Creating #{entity_type} relationships..."

      entity_count = config[:count]
      entity_prefix = config[:prefix]

      # Calculate how many relationships to create for this entity type
      target_relationships = (num_actors * relationships_per_actor * (entity_count.to_f / entity_types.values.sum { |c| c[:count] })).to_i

      entity_batches = (target_relationships / batch_size.to_f).ceil

      entity_batches.times do |batch_idx|
        tuples = []

        batch_size.times do |i|
          # Pick a random user
          user_id = "user-#{rand(num_actors)}"

          # Pick a random entity
          entity_id = "#{entity_prefix}-#{rand(entity_count)}"

          # Pick a random relation
          relation = relations.sample

          # 20% chance of group-based permission
          if rand < 0.2
            group_id = "group-#{rand(num_actors / 10)}"
            tuples << {
              tenant_id: tenant_id,
              subject: entity_type.to_s,
              id: entity_id,
              relation: relation.to_s,
              actor: 'group',
              actor_id: group_id,
              actor_rel: 'member'
            }
          else
            tuples << {
              tenant_id: tenant_id,
              subject: entity_type.to_s,
              id: entity_id,
              relation: relation.to_s,
              actor: 'user',
              actor_id: user_id,
              actor_rel: nil
            }
          end
        end

        # Bulk insert
        if tuples.any?
          values_sql = tuples.map { |t|
            "(#{ActiveRecord::Base.connection.quote(t[:tenant_id])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:subject])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:id])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:relation])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:actor])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:actor_id])}, " +
            "#{t[:actor_rel] ? ActiveRecord::Base.connection.quote(t[:actor_rel]) : 'NULL'}, " +
            "NOW())"
          }.join(", ")

          ActiveRecord::Base.connection.execute(
            "INSERT INTO rel_tuples (tenant_id, subject, id, relation, actor, actor_id, actor_rel, created_at) VALUES #{values_sql} ON CONFLICT DO NOTHING"
          )

          total_tuples += tuples.size
        end

        if batch_idx % 10 == 0 || batch_idx == entity_batches - 1
          progress = ((batch_idx + 1) * 100.0 / entity_batches).round(1)
          elapsed = Time.now - start_time
          rate = total_tuples / elapsed

          puts "      Batch #{batch_idx + 1}/#{entity_batches} (#{progress}%) | " +
               "Total tuples: #{total_tuples.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} | " +
               "Rate: #{rate.round(0)}/sec"
        end
      end
    end

    puts ""
    puts "📊 Phase 3: Creating hierarchical relationships"
    puts "=" * 60

    # Create parent-child relationships for hierarchical entities
    hierarchical_pairs = [
      { parent: :organization, child: :department },
      { parent: :department, child: :team },
      { parent: :workspace, child: :project },
      { parent: :project, child: :folder },
      { parent: :folder, child: :document },
      { parent: :repository, child: :issue },
      { parent: :repository, child: :pull_request }
    ]

    hierarchical_pairs.each do |pair|
      parent_type = pair[:parent]
      child_type = pair[:child]
      parent_config = entity_types[parent_type]
      child_config = entity_types[child_type]

      next unless parent_config && child_config

      puts "\n   Linking #{child_type} → #{parent_type}..."

      # Create parent relationships for each child
      child_count = child_config[:count]
      parent_count = parent_config[:count]

      child_batches = (child_count / batch_size.to_f).ceil

      child_batches.times do |batch_idx|
        batch_start = batch_idx * batch_size
        batch_end = [batch_start + batch_size, child_count].min

        tuples = []

        (batch_start...batch_end).each do |child_idx|
          child_id = "#{child_config[:prefix]}-#{child_idx}"
          parent_id = "#{parent_config[:prefix]}-#{rand(parent_count)}"

          tuples << {
            tenant_id: tenant_id,
            subject: child_type.to_s,
            id: child_id,
            relation: 'parent',
            actor: parent_type.to_s,
            actor_id: parent_id,
            actor_rel: nil
          }
        end

        # Bulk insert
        if tuples.any?
          values_sql = tuples.map { |t|
            "(#{ActiveRecord::Base.connection.quote(t[:tenant_id])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:subject])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:id])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:relation])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:actor])}, " +
            "#{ActiveRecord::Base.connection.quote(t[:actor_id])}, " +
            "NULL, NOW())"
          }.join(", ")

          ActiveRecord::Base.connection.execute(
            "INSERT INTO rel_tuples (tenant_id, subject, id, relation, actor, actor_id, actor_rel, created_at) VALUES #{values_sql} ON CONFLICT DO NOTHING"
          )

          total_tuples += tuples.size
        end

        if batch_idx % 20 == 0 || batch_idx == child_batches - 1
          progress = ((batch_idx + 1) * 100.0 / child_batches).round(1)
          puts "      Batch #{batch_idx + 1}/#{child_batches} (#{progress}%)"
        end
      end
    end

    elapsed_time = Time.now - start_time

    puts ""
    puts "=" * 60
    puts "✅ Data generation complete!"
    puts "=" * 60
    puts "   Total tuples created: #{total_tuples.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "   Time elapsed: #{(elapsed_time / 60).round(2)} minutes"
    puts "   Average rate: #{(total_tuples / elapsed_time).round(0)} tuples/sec"
    puts ""
    puts "📊 Database statistics:"

    # Get actual counts
    actual_count = RelTuple.where(tenant_id: tenant_id).count
    puts "   Tuples in database: #{actual_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

    # Count unique actors
    unique_actors = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(DISTINCT actor || ':' || actor_id) FROM rel_tuples WHERE tenant_id = '#{tenant_id}'"
    ).first['count']
    puts "   Unique actors: #{unique_actors.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

    # Count entity types
    unique_subjects = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(DISTINCT subject) FROM rel_tuples WHERE tenant_id = '#{tenant_id}'"
    ).first['count']
    puts "   Entity types: #{unique_subjects}"

    puts ""
    puts "💡 Test the system:"
    puts "   curl -H \"X-Tenant: #{tenant_id}\" http://localhost:3000/api/actors/user/user-12345/permissions"
    puts "   curl -H \"X-Tenant: #{tenant_id}\" http://localhost:3000/api/schema"
  end

  desc "Clean up generated test data"
  task clean_large: :environment do
    tenant_id = ENV['TENANT'] || 'default'

    puts "🗑️  Cleaning up test data for tenant: #{tenant_id}"
    puts "   This will delete ALL tuples and audit logs for this tenant."
    print "   Are you sure? (yes/no): "

    confirmation = STDIN.gets.chomp

    if confirmation.downcase == 'yes'
      puts "   Deleting tuples..."
      deleted_tuples = RelTuple.where(tenant_id: tenant_id).delete_all
      puts "   ✅ Deleted #{deleted_tuples.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} tuples"

      puts "   Deleting audit logs..."
      deleted_logs = AuditLog.where(tenant_id: tenant_id).delete_all
      puts "   ✅ Deleted #{deleted_logs.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} audit logs"

      puts ""
      puts "✅ Cleanup complete!"
    else
      puts "   ❌ Cleanup cancelled"
    end
  end

  desc "Generate statistics for test data"
  task stats: :environment do
    tenant_id = ENV['TENANT'] || 'default'

    puts "📊 Statistics for tenant: #{tenant_id}"
    puts "=" * 60

    total = RelTuple.where(tenant_id: tenant_id).count
    puts "Total tuples: #{total.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

    # Count by subject type
    puts "\nBy entity type:"
    by_subject = ActiveRecord::Base.connection.execute(
      "SELECT subject, COUNT(*) as count FROM rel_tuples WHERE tenant_id = '#{tenant_id}' GROUP BY subject ORDER BY count DESC"
    )
    by_subject.each do |row|
      count_formatted = row['count'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      puts "   #{row['subject'].ljust(20)}: #{count_formatted.rjust(15)}"
    end

    # Count by relation
    puts "\nBy relation type:"
    by_relation = ActiveRecord::Base.connection.execute(
      "SELECT relation, COUNT(*) as count FROM rel_tuples WHERE tenant_id = '#{tenant_id}' GROUP BY relation ORDER BY count DESC"
    )
    by_relation.each do |row|
      count_formatted = row['count'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      puts "   #{row['relation'].ljust(20)}: #{count_formatted.rjust(15)}"
    end

    # Sample permission checks
    puts "\n⚡ Performance test (sample permission checks):"
    sample_users = ['user-1234', 'user-5678', 'user-9999', 'user-50000', 'user-999999']

    schema_path = Rails.root.join("config/auth_schema.rb")
    load schema_path
    repo = RebacRepo.new(tenant_id: tenant_id)
    engine = PermissionEngine.new(schema: AuthSchema, repo: repo)

    sample_users.each do |user_id|
      start_time = Time.now

      # Find a resource this user has access to
      tuple = RelTuple.where(tenant_id: tenant_id, actor: 'user', actor_id: user_id).first

      if tuple
        # Check permission
        result = engine.check('user', user_id, tuple.relation.to_sym, tuple.subject, tuple['id'])
        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        puts "   #{user_id} → #{tuple.subject}:#{tuple['id']} (#{tuple.relation}): #{result ? '✅' : '❌'} [#{elapsed_ms}ms]"
      end
    end
  end
end

module ProgressHelper
  # Helper module can be expanded for progress bars if needed
end
