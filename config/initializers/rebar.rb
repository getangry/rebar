# Rebar Configuration
#
# Performance Characteristics (tested with 1.3M tuples):
# - Actor permissions query: 2-5 seconds average
# - Supports billion-row scale through bounded graph expansion
# - Memory-efficient: expands from actor outward, not full database scan
#
# Optimization Strategy:
# Instead of checking all entities (O(n) where n = total entities),
# we expand from the actor's reachable graph (O(m) where m = bounded by config).
# This changes a 1.3M entity scan into checking only ~200-500 discovered entities.

module Rebar
  class Config
    class << self
      # Actor permissions expansion limits
      # These prevent unbounded queries when computing inherited permissions

      # Maximum direct resources to expand from (per actor)
      # Higher = more inherited permissions found, but slower queries
      # Tested: 100 gives 2-5s response time with 1.3M tuples
      def max_direct_resources
        ENV.fetch('REBAR_MAX_DIRECT_RESOURCES', 100).to_i
      end

      # Maximum children to find per parent resource
      # Controls how deep to traverse parent→child hierarchies
      # Tested: 20 provides good balance for folder/document trees
      def max_children_per_parent
        ENV.fetch('REBAR_MAX_CHILDREN_PER_PARENT', 20).to_i
      end

      # Maximum resources to check per group
      # Limits resources discovered through group memberships
      # Tested: 20 handles typical group access patterns
      def max_resources_per_group
        ENV.fetch('REBAR_MAX_RESOURCES_PER_GROUP', 20).to_i
      end

      # Maximum children to find per group resource
      # Controls cascading from group-owned resources
      # Tested: 10 prevents excessive expansion from shared resources
      def max_children_per_group_resource
        ENV.fetch('REBAR_MAX_CHILDREN_PER_GROUP_RESOURCE', 10).to_i
      end

      # Enable/disable inherited permissions computation
      # Set to 'false' for extremely large datasets if you don't need this feature
      # When disabled, only direct and group permissions are returned
      def compute_inherited_permissions?
        ENV.fetch('REBAR_COMPUTE_INHERITED', 'true') == 'true'
      end
    end
  end
end
