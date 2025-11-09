class AttributeCache
  # Multi-tier caching strategy for attributes
  # L1: Process memory (LRU cache, 5 second TTL)
  # L2: Redis (5 minute TTL)
  # L3: Database read replica
  # L4: Primary database

  L1_TTL = 5.seconds
  L2_TTL = 5.minutes
  L1_MAX_SIZE = 10_000

  class << self
    # Fetch entity attributes with multi-tier caching
    def fetch_entity_attrs(subject, subject_id, tenant_id: 'default')
      cache_key = entity_cache_key(subject, subject_id, tenant_id)

      # L1: Process cache
      l1_result = l1_cache.fetch(cache_key)
      return l1_result if l1_result

      # L2: Redis cache
      l2_result = l2_fetch(cache_key) do
        # L3/L4: Database (uses read replica if available)
        load_entity_attrs_from_db(subject, subject_id, tenant_id)
      end

      # Store in L1 for subsequent requests
      l1_cache.set(cache_key, l2_result, ttl: L1_TTL)

      l2_result
    end

    # Fetch relationship attributes with multi-tier caching
    def fetch_rel_attrs(tuple_id, tenant_id: 'default')
      cache_key = rel_cache_key(tuple_id, tenant_id)

      # L1: Process cache
      l1_result = l1_cache.fetch(cache_key)
      return l1_result if l1_result

      # L2: Redis cache
      l2_result = l2_fetch(cache_key) do
        # L3/L4: Database
        load_rel_attrs_from_db(tuple_id, tenant_id)
      end

      # Store in L1
      l1_cache.set(cache_key, l2_result, ttl: L1_TTL)

      l2_result
    end

    # Invalidate caches for entity attributes
    def invalidate_entity(subject, subject_id, tenant_id: 'default')
      cache_key = entity_cache_key(subject, subject_id, tenant_id)
      l1_cache.delete(cache_key)
      l2_delete(cache_key)
      Rails.logger.debug("Invalidated entity cache: #{cache_key}")
    end

    # Invalidate caches for relationship attributes
    def invalidate_rel(tuple_id, tenant_id: 'default')
      cache_key = rel_cache_key(tuple_id, tenant_id)
      l1_cache.delete(cache_key)
      l2_delete(cache_key)
      Rails.logger.debug("Invalidated rel cache: #{cache_key}")
    end

    # Batch fetch entity attributes (prevents N+1)
    def batch_fetch_entity_attrs(subjects, tenant_id: 'default')
      # subjects = [{ subject: 'document', subject_id: '123' }, ...]
      cache_keys = subjects.map { |s| entity_cache_key(s[:subject], s[:subject_id], tenant_id) }

      # Try L1 first
      results = {}
      uncached_subjects = []

      subjects.each_with_index do |s, idx|
        cached = l1_cache.fetch(cache_keys[idx])
        if cached
          results[s[:subject_id]] = cached
        else
          uncached_subjects << s
        end
      end

      return results if uncached_subjects.empty?

      # Batch load from database for uncached items
      subject_ids = uncached_subjects.map { |s| s[:subject_id] }
      db_results = AttributeVersion
        .for_tenant(tenant_id)
        .where(subject_id: subject_ids)
        .current
        .select(:id, :subject_id, :metadata, :max_requests, :current_requests, :requires_mfa, :risk_level)
        .index_by(&:subject_id)

      # Populate caches
      uncached_subjects.each do |s|
        attr = db_results[s[:subject_id]]
        cache_key = entity_cache_key(s[:subject], s[:subject_id], tenant_id)

        # Store in L2
        l2_set(cache_key, attr, ttl: L2_TTL)

        # Store in L1
        l1_cache.set(cache_key, attr, ttl: L1_TTL)

        results[s[:subject_id]] = attr
      end

      results
    end

    # Get cache statistics
    def stats
      {
        l1: l1_cache.stats,
        l2: l2_stats
      }
    end

    # Clear all caches (use with caution!)
    def clear_all!
      l1_cache.clear
      l2_clear_pattern('attrs:*')
      Rails.logger.warn("Cleared all attribute caches")
    end

    private

    # L1 Cache (Process Memory)
    def l1_cache
      @l1_cache ||= L1Cache.new(max_size: L1_MAX_SIZE)
    end

    # L2 Cache Operations (Redis)
    def l2_fetch(key)
      cached = Rails.cache.read(key)
      return deserialize(cached) if cached

      result = yield
      l2_set(key, result, ttl: L2_TTL) if result
      result
    end

    def l2_set(key, value, ttl:)
      Rails.cache.write(key, serialize(value), expires_in: ttl)
    end

    def l2_delete(key)
      Rails.cache.delete(key)
    end

    def l2_clear_pattern(pattern)
      # Redis-specific: delete by pattern
      if Rails.cache.respond_to?(:redis)
        redis = Rails.cache.redis
        keys = redis.keys(pattern)
        redis.del(*keys) if keys.any?
      end
    end

    def l2_stats
      if Rails.cache.respond_to?(:stats)
        Rails.cache.stats
      else
        { available: false }
      end
    end

    # Database loading (uses read replica if configured)
    def load_entity_attrs_from_db(subject, subject_id, tenant_id)
      AttributeVersion
        .for_tenant(tenant_id)
        .for_subject(subject, subject_id)
        .current
        .select(:id, :subject_id, :metadata, :max_requests, :current_requests, :requires_mfa, :risk_level)
        .first
    end

    def load_rel_attrs_from_db(tuple_id, tenant_id)
      RelTupleAttribute
        .for_tenant(tenant_id)
        .for_tuple(tuple_id)
        .current
        .select(:id, :tuple_id, :metadata, :usage_count, :max_usage, :granted_by, :approval_required, :approval_status, :valid_until)
        .first
    end

    # Cache key generation
    def entity_cache_key(subject, subject_id, tenant_id)
      "attrs:entity:#{tenant_id}:#{subject}:#{subject_id}:current"
    end

    def rel_cache_key(tuple_id, tenant_id)
      "attrs:rel:#{tenant_id}:#{tuple_id}:current"
    end

    # Serialization for Redis
    def serialize(value)
      return nil if value.nil?

      # Convert ActiveRecord object to hash
      if value.respond_to?(:attributes)
        value.attributes
      else
        value
      end
    end

    def deserialize(value)
      return nil if value.nil?
      value # Already a hash from Redis
    end
  end

  # L1 Cache Implementation (Thread-safe LRU)
  class L1Cache
    def initialize(max_size: 10_000)
      @cache = {}
      @access_times = {}
      @max_size = max_size
      @mutex = Mutex.new
      @hits = 0
      @misses = 0
    end

    def fetch(key)
      @mutex.synchronize do
        if @cache.key?(key)
          entry = @cache[key]
          # Check if expired
          if entry[:expires_at] > Time.current
            @access_times[key] = Time.current
            @hits += 1
            return entry[:value]
          else
            # Expired
            @cache.delete(key)
            @access_times.delete(key)
          end
        end

        @misses += 1
        nil
      end
    end

    def set(key, value, ttl:)
      @mutex.synchronize do
        # Evict least recently used if at capacity
        if @cache.size >= @max_size
          lru_key = @access_times.min_by { |k, v| v }&.first
          @cache.delete(lru_key)
          @access_times.delete(lru_key)
        end

        @cache[key] = {
          value: value,
          expires_at: Time.current + ttl
        }
        @access_times[key] = Time.current
      end
    end

    def delete(key)
      @mutex.synchronize do
        @cache.delete(key)
        @access_times.delete(key)
      end
    end

    def clear
      @mutex.synchronize do
        @cache.clear
        @access_times.clear
        @hits = 0
        @misses = 0
      end
    end

    def stats
      @mutex.synchronize do
        total = @hits + @misses
        hit_rate = total > 0 ? (@hits.to_f / total * 100).round(2) : 0

        {
          size: @cache.size,
          max_size: @max_size,
          hits: @hits,
          misses: @misses,
          hit_rate: "#{hit_rate}%"
        }
      end
    end
  end
end
