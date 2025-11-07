import { useState, useEffect } from 'react';
import { rebarClient } from '../api/rebar';
import type { ActorPermissionsResponse, EntitiesResponse } from '../api/rebar';
import { Alert, AlertDescription } from './ui/alert';
import Button from './ui/button';
import Badge from './ui/badge';

const colors = {
  user: '#818cf8',
  group: '#34d399',
  doc: '#fbbf24',
  folder: '#f472b6',
  default: '#9ca3af',
};

export default function ActorPermissions() {
  const [entities, setEntities] = useState<EntitiesResponse | null>(null);
  const [selectedActor, setSelectedActor] = useState<{ type: string; id: string } | null>(null);
  const [permissions, setPermissions] = useState<ActorPermissionsResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadEntities();
  }, []);

  const loadEntities = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await rebarClient.getEntities();
      setEntities(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load entities');
    } finally {
      setLoading(false);
    }
  };

  const loadActorPermissions = async (actorType: string, actorId: string) => {
    setLoading(true);
    setError(null);
    setSelectedActor({ type: actorType, id: actorId });
    try {
      const data = await rebarClient.getActorPermissions(actorType, actorId);
      setPermissions(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load permissions');
      setPermissions(null);
    } finally {
      setLoading(false);
    }
  };

  if (loading && !entities) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="text-gray-500">Loading entities...</div>
      </div>
    );
  }

  if (error && !entities) {
    return (
      <Alert variant="destructive">
        <AlertDescription>{error}</AlertDescription>
      </Alert>
    );
  }

  if (!entities || Object.keys(entities.entities).length === 0) {
    return (
      <Alert>
        <AlertDescription>
          No entities found. Create some tuples to see actor permissions.
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <div className="px-4 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-semibold text-gray-900">Actor Permissions</h1>
        <p className="mt-2 text-sm text-gray-600">
          Select an actor to see all permissions and actions they can perform
        </p>
      </div>

      {/* Actor Selector */}
      <div className="mb-6 bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-sm font-medium text-gray-900 mb-4">Select an Actor</h3>
        <div className="space-y-4">
          {Object.entries(entities.entities)
            .filter(([type]) => type === 'user' || type === 'group')
            .map(([type, entityList]) => (
              <div key={type}>
                <div className="flex items-center gap-2 mb-2">
                  <div
                    className="w-3 h-3 rounded-full"
                    style={{ backgroundColor: colors[type as keyof typeof colors] || colors.default }}
                  />
                  <span className="text-sm font-medium text-gray-700">{type}</span>
                  <span className="text-xs text-gray-500">({entityList.length})</span>
                </div>
                <div className="flex flex-wrap gap-2 ml-5">
                  {entityList.map((entity) => (
                    <Button
                      key={entity.id}
                      size="sm"
                      variant={
                        selectedActor &&
                        selectedActor.type === type &&
                        selectedActor.id === entity.object_id.toString()
                          ? 'default'
                          : 'outline'
                      }
                      onClick={() => loadActorPermissions(type, entity.object_id.toString())}
                      className="text-xs"
                    >
                      {entity.object_id}
                    </Button>
                  ))}
                </div>
              </div>
            ))}
        </div>
      </div>

      {/* Loading State */}
      {loading && selectedActor && (
        <div className="flex items-center justify-center py-12 bg-white rounded-lg border border-gray-200">
          <div className="text-gray-500">Loading permissions...</div>
        </div>
      )}

      {/* Error State */}
      {error && selectedActor && (
        <Alert variant="destructive" className="mb-6">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Permissions Display */}
      {!loading && permissions && (
        <div className="space-y-6">
          {/* Summary Stats */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-4">
            <div className="bg-white rounded-lg border border-gray-200 p-4">
              <div className="text-sm text-gray-500">Total Permissions</div>
              <div className="text-2xl font-semibold text-gray-900 mt-1">
                {permissions.total_permissions}
              </div>
            </div>
            <div className="bg-white rounded-lg border border-gray-200 p-4">
              <div className="text-sm text-gray-500">Direct</div>
              <div className="text-2xl font-semibold text-indigo-600 mt-1">
                {permissions.direct_count}
              </div>
            </div>
            <div className="bg-white rounded-lg border border-gray-200 p-4">
              <div className="text-sm text-gray-500">Via Groups</div>
              <div className="text-2xl font-semibold text-green-600 mt-1">
                {permissions.group_count}
              </div>
            </div>
            <div className="bg-white rounded-lg border border-gray-200 p-4">
              <div className="text-sm text-gray-500">Inherited</div>
              <div className="text-2xl font-semibold text-purple-600 mt-1">
                {permissions.inherited_count}
              </div>
            </div>
          </div>

          {/* Group Memberships */}
          {permissions.group_memberships && permissions.group_memberships.length > 0 && (
            <div className="bg-white rounded-lg border border-gray-200 p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-3">Group Memberships</h3>
              <div className="flex flex-wrap gap-2">
                {permissions.group_memberships.map((group) => (
                  <Badge key={group} className="bg-green-100 text-green-800">
                    {group}
                  </Badge>
                ))}
              </div>
            </div>
          )}

          {/* Resources & Permissions */}
          <div className="bg-white rounded-lg border border-gray-200 p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">
              Permissions by Resource
            </h3>

            {permissions.resources.length === 0 && (
              <div className="text-center py-8 text-gray-500">
                This actor has no permissions yet
              </div>
            )}

            <div className="space-y-4">
              {permissions.resources.map((resource) => (
                <div
                  key={resource.resource}
                  className="border border-gray-200 rounded-lg p-4 hover:border-indigo-300 transition-colors"
                >
                  <div className="flex items-start justify-between mb-3">
                    <div className="flex items-center gap-2">
                      <div
                        className="w-3 h-3 rounded-full"
                        style={{
                          backgroundColor:
                            colors[resource.resource_type as keyof typeof colors] ||
                            colors.default,
                        }}
                      />
                      <span className="font-semibold text-gray-900">{resource.resource}</span>
                    </div>
                    <Badge className="bg-gray-100 text-gray-700">
                      {resource.permissions.length} permission
                      {resource.permissions.length !== 1 ? 's' : ''}
                    </Badge>
                  </div>

                  <div className="space-y-2">
                    {resource.permissions.map((perm, idx) => (
                      <div
                        key={idx}
                        className="flex items-center justify-between p-2 bg-gray-50 rounded"
                      >
                        <div className="flex items-center gap-2">
                          <Badge
                            className={
                              perm.type === 'direct'
                                ? 'bg-indigo-100 text-indigo-800'
                                : perm.type === 'group'
                                ? 'bg-green-100 text-green-800'
                                : 'bg-purple-100 text-purple-800'
                            }
                          >
                            {perm.permission}
                          </Badge>
                          {(perm.type === 'group' || perm.type === 'inherited') && perm.via && (
                            <span className="text-xs text-gray-500">via {perm.via}</span>
                          )}
                        </div>
                        <span className="text-xs text-gray-400 uppercase">{perm.type}</span>
                      </div>
                    ))}

                    {resource.actions.length > 0 && (
                      <div className="mt-3 p-3 bg-blue-50 border border-blue-200 rounded">
                        <div className="text-xs font-medium text-blue-900 mb-2">Available Actions</div>
                        <div className="flex flex-wrap gap-1">
                          {resource.actions.map((action) => (
                            <Badge
                              key={action}
                              className="bg-blue-100 text-blue-800 text-xs"
                            >
                              {action.replace('can_', '')}
                            </Badge>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* No Selection State */}
      {!loading && !permissions && !selectedActor && (
        <div className="flex items-center justify-center py-12 bg-white rounded-lg border border-gray-200">
          <div className="text-gray-500">Select an actor above to view their permissions</div>
        </div>
      )}
    </div>
  );
}
