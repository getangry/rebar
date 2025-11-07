import { useState, useEffect } from 'react';
import { rebarClient } from '../api/rebar';
import type { SchemaResponse } from '../api/rebar';
import Button from './ui/button';
import Badge from './ui/badge';
import { Alert, AlertDescription } from './ui/alert';
import StatsCard from './ui/stats-card';
import RelationshipGraph from './RelationshipGraph';

export default function SchemaExplorer() {
  const [schema, setSchema] = useState<SchemaResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showGraph, setShowGraph] = useState(false);

  useEffect(() => {
    loadSchema();
  }, []);

  const loadSchema = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await rebarClient.getSchema();
      setSchema(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load schema');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-center py-12">
          <div className="text-gray-500">Loading schema...</div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="px-4 sm:px-6 lg:px-8">
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      </div>
    );
  }

  if (!schema) {
    return null;
  }

  if (showGraph) {
    return (
      <div className="px-4 sm:px-6 lg:px-8">
        <div className="mb-6">
          <Button onClick={() => setShowGraph(false)} variant="outline">
            ← Back to Schema
          </Button>
        </div>
        <RelationshipGraph />
      </div>
    );
  }

  const totalRelationships = Object.values(schema.stats).reduce(
    (sum, stat) => sum + stat.total,
    0
  );

  return (
    <div className="px-4 sm:px-6 lg:px-8">
      {/* Page header */}
      <div className="mb-8">
        <h1 className="text-2xl font-semibold text-gray-900">Schema Explorer</h1>
        <p className="mt-2 text-sm text-gray-600">
          Browse entity types, their allowed relations, and view relationship statistics.
        </p>
      </div>

      {/* Summary Stats */}
      <div className="mb-8">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatsCard
            name="Entity Types"
            value={Object.keys(schema.types).length.toString()}
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" />
              </svg>
            }
          />
          <StatsCard
            name="Total Relationships"
            value={totalRelationships.toString()}
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244" />
              </svg>
            }
          />
          <StatsCard
            name="As Subject"
            value={Object.values(schema.stats).reduce((sum, s) => sum + s.as_subject, 0).toString()}
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
              </svg>
            }
          />
          <StatsCard
            name="As Actor"
            value={Object.values(schema.stats).reduce((sum, s) => sum + s.as_actor, 0).toString()}
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
              </svg>
            }
          />
        </div>
      </div>

      {/* View Graph Button */}
      <div className="mb-6">
        <Button onClick={() => setShowGraph(true)} className="bg-indigo-600 hover:bg-indigo-700">
          <svg className="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5m.75-9l3-3 2.148 2.148A12.061 12.061 0 0116.5 7.605" />
          </svg>
          View Relationship Graph
        </Button>
      </div>

      {/* Entity Types */}
      <div className="space-y-6">
        <h2 className="text-lg font-semibold text-gray-900">Entity Types</h2>

        <div className="grid grid-cols-1 gap-6 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
          {Object.entries(schema.types).map(([typeName, typeDef]) => {
            const stats = schema.stats[typeName];
            const relations = typeDef.relations || {};

            return (
              <div
                key={typeName}
                className="bg-white rounded-lg border border-gray-200 overflow-hidden hover:border-indigo-500 transition-colors"
              >
                {/* Header */}
                <div className="bg-gray-50 px-6 py-4 border-b border-gray-200">
                  <div className="flex items-center justify-between">
                    <h3 className="text-lg font-semibold text-gray-900">{typeName}</h3>
                    <Badge variant="default">{stats.total} relationships</Badge>
                  </div>
                </div>

                {/* Stats */}
                <div className="px-6 py-4 border-b border-gray-200">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <div className="text-sm text-gray-600">As Subject</div>
                      <div className="text-2xl font-semibold text-gray-900">{stats.as_subject}</div>
                    </div>
                    <div>
                      <div className="text-sm text-gray-600">As Actor</div>
                      <div className="text-2xl font-semibold text-gray-900">{stats.as_actor}</div>
                    </div>
                  </div>
                </div>

                {/* Relations */}
                <div className="px-6 py-4">
                  <div className="text-sm font-medium text-gray-700 mb-3">Allowed Relations</div>
                  {Object.keys(relations).length > 0 ? (
                    <div className="space-y-3">
                      {Object.entries(relations).map(([relationName, allowedTypes]) => (
                        <div key={relationName} className="flex items-start">
                          <div className="flex-shrink-0">
                            <Badge variant="outline" className="font-mono text-xs">
                              {relationName}
                            </Badge>
                          </div>
                          <div className="ml-3 flex-1">
                            <div className="text-xs text-gray-600">
                              Allows:{' '}
                              <span className="font-mono text-gray-900">
                                {(allowedTypes as string[]).join(', ')}
                              </span>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="text-sm text-gray-500 italic">No relations defined</div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
