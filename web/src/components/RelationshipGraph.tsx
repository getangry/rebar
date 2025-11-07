import { useState, useEffect } from 'react';
import { rebarClient } from '../api/rebar';
import type { GraphResponse, EntitiesResponse } from '../api/rebar';
import { Group } from '@visx/group';
import { Graph } from '@visx/network';
import { LinearGradient } from '@visx/gradient';
import { Alert, AlertDescription } from './ui/alert';
import Button from './ui/button';

interface Node {
  id: string;
  type: string;
  label: string;
  depth?: number;
  x?: number;
  y?: number;
}

interface Link {
  source: Node;
  target: Node;
  label: string;
}

const colors = {
  user: '#818cf8',
  group: '#34d399',
  doc: '#fbbf24',
  folder: '#f472b6',
  default: '#9ca3af',
};

export default function RelationshipGraph() {
  const [entities, setEntities] = useState<EntitiesResponse | null>(null);
  const [selectedEntity, setSelectedEntity] = useState<string | null>(null);
  const [graphData, setGraphData] = useState<GraphResponse | null>(null);
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

  const loadRelationships = async (entityId: string) => {
    setLoading(true);
    setError(null);
    setSelectedEntity(entityId);
    try {
      const data = await rebarClient.getRelationships(entityId);
      setGraphData(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load relationships');
      setGraphData(null);
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
          No entities found. Create some tuples to see the relationship graph.
        </AlertDescription>
      </Alert>
    );
  }

  // Build graph data for visx with layout
  const buildGraphData = (): { nodes: Node[]; links: Link[] } => {
    if (!graphData) return { nodes: [], links: [] };

    const width = 1200;
    const height = 800;
    const centerX = width / 2;
    const centerY = height / 2;

    // Group nodes by depth
    const nodesByDepth: Record<number, any[]> = {};
    graphData.nodes.forEach(node => {
      const depth = (node as any).depth || 0;
      if (!nodesByDepth[depth]) nodesByDepth[depth] = [];
      nodesByDepth[depth].push(node);
    });

    const nodesMap = new Map<string, Node>();

    // Layout nodes by depth (radial layout)
    Object.entries(nodesByDepth).forEach(([depthStr, depthNodes]) => {
      const depth = parseInt(depthStr);
      const radius = depth === 0 ? 0 : 150 + (depth * 150); // Increase radius per depth level
      const angleStep = (2 * Math.PI) / Math.max(depthNodes.length, 1);

      depthNodes.forEach((node, index) => {
        let x, y;
        if (depth === 0) {
          // Center node
          x = centerX;
          y = centerY;
        } else {
          // Arrange in circle
          const angle = index * angleStep;
          x = centerX + radius * Math.cos(angle);
          y = centerY + radius * Math.sin(angle);
        }

        nodesMap.set(node.id, {
          id: node.id,
          type: node.type,
          label: node.label,
          depth: depth,
          x,
          y,
        } as any);
      });
    });

    const links: Link[] = graphData.edges.map(edge => {
      const source = nodesMap.get(edge.source)!;
      const target = nodesMap.get(edge.target)!;
      const label = (edge as any).label || edge.relation;
      return { source, target, label };
    });

    return {
      nodes: Array.from(nodesMap.values()),
      links,
    };
  };

  const graph = buildGraphData();
  const width = 1200;
  const height = 800;

  return (
    <div>
      {/* Header */}
      <div className="mb-6">
        <h2 className="text-2xl font-semibold text-gray-900">Relationship Graph</h2>
        <p className="mt-2 text-sm text-gray-600">
          Select an entity to visualize its relationships
        </p>
      </div>

      {/* Entity Selector */}
      <div className="mb-6 bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-sm font-medium text-gray-900 mb-4">Select an Entity</h3>
        <div className="space-y-4">
          {Object.entries(entities.entities).map(([type, entityList]) => (
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
                    variant={selectedEntity === entity.id ? 'default' : 'outline'}
                    onClick={() => loadRelationships(entity.id)}
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
      {loading && selectedEntity && (
        <div className="flex items-center justify-center py-12 bg-white rounded-lg border border-gray-200">
          <div className="text-gray-500">Loading relationships...</div>
        </div>
      )}

      {/* Error State */}
      {error && selectedEntity && (
        <Alert variant="destructive" className="mb-6">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Graph Visualization */}
      {!loading && graphData && graph.nodes.length > 0 && (
        <div>
          {/* Stats */}
          <div className="mb-4 text-sm text-gray-600">
            Showing {graphData.node_count} nodes and {graphData.edge_count} relationships
            {graphData.center_entity && (
              <span className="ml-2 text-indigo-600 font-medium">
                centered on {graphData.center_entity}
              </span>
            )}
          </div>

          {/* Legend */}
          <div className="mb-6 flex items-center gap-4 flex-wrap">
            <div className="text-sm font-medium text-gray-700">Entity Types:</div>
            {Object.entries(colors).map(([type, color]) => (
              <div key={type} className="flex items-center gap-2">
                <div
                  className="w-4 h-4 rounded-full"
                  style={{ backgroundColor: color }}
                />
                <span className="text-sm text-gray-600">{type}</span>
              </div>
            ))}
          </div>

          {/* Network Graph */}
          <div className="bg-white rounded-lg border border-gray-200 p-6 overflow-x-auto">
            <svg width={width} height={height}>
              <LinearGradient id="links-gradient" from="#475569" to="#64748b" />
              <rect width={width} height={height} rx={14} fill="#ffffff" />
              <Graph<Link, Node>
                graph={graph}
                nodeComponent={({ node }) => {
                  const nodeColor = colors[node.type as keyof typeof colors] || colors.default;
                  const isCenterNode = graphData.center_entity === node.id;
                  const radius = isCenterNode ? 12 : node.depth === 1 ? 8 : 6;

                  return (
                    <Group>
                      <circle
                        r={radius}
                        fill={nodeColor}
                        stroke={isCenterNode ? '#6366f1' : '#fff'}
                        strokeWidth={isCenterNode ? 3 : 2}
                        strokeOpacity={isCenterNode ? 1 : 0.8}
                      />
                      <text
                        dy=".33em"
                        fontSize={isCenterNode ? 12 : 10}
                        fontFamily="system-ui, sans-serif"
                        textAnchor="middle"
                        fill="#1f2937"
                        fontWeight={isCenterNode ? 'bold' : 'normal'}
                        y={radius + 12}
                      >
                        {node.label}
                      </text>
                    </Group>
                  );
                }}
                linkComponent={({ link }) => (
                  <Group>
                    <line
                      x1={link.source.x}
                      y1={link.source.y}
                      x2={link.target.x}
                      y2={link.target.y}
                      stroke="#475569"
                      strokeWidth={2.5}
                      strokeOpacity={0.9}
                      markerEnd="url(#arrowhead)"
                    />
                    <text
                      x={(link.source.x! + link.target.x!) / 2}
                      y={(link.source.y! + link.target.y!) / 2}
                      dy="-5"
                      fontSize={9}
                      fontFamily="system-ui, sans-serif"
                      textAnchor="middle"
                      fill="#64748b"
                    >
                      {link.label}
                    </text>
                  </Group>
                )}
              />
              <defs>
                <marker
                  id="arrowhead"
                  markerWidth="10"
                  markerHeight="10"
                  refX="9"
                  refY="3"
                  orient="auto"
                  markerUnits="strokeWidth"
                >
                  <path d="M0,0 L0,6 L9,3 z" fill="#475569" />
                </marker>
              </defs>
            </svg>
          </div>

          {/* Node Details */}
          <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {Object.entries(graph.nodes.reduce((acc, node) => {
              if (!acc[node.type]) acc[node.type] = [];
              acc[node.type].push(node);
              return acc;
            }, {} as Record<string, Node[]>)).map(([type, nodes]) => (
              <div key={type} className="bg-white rounded-lg border border-gray-200 p-4">
                <div className="flex items-center gap-2 mb-3">
                  <div
                    className="w-3 h-3 rounded-full"
                    style={{ backgroundColor: colors[type as keyof typeof colors] || colors.default }}
                  />
                  <h3 className="font-semibold text-gray-900">{type}</h3>
                  <span className="text-sm text-gray-500">({nodes.length})</span>
                </div>
                <div className="space-y-1 text-sm text-gray-600">
                  {nodes.slice(0, 5).map((node) => (
                    <div key={node.id}>{node.label}</div>
                  ))}
                  {nodes.length > 5 && (
                    <div className="text-gray-400 italic">+{nodes.length - 5} more</div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Empty State */}
      {!loading && graphData && graph.nodes.length === 0 && (
        <Alert>
          <AlertDescription>
            No relationships found for this entity.
          </AlertDescription>
        </Alert>
      )}

      {/* No Selection State */}
      {!loading && !graphData && !selectedEntity && (
        <div className="flex items-center justify-center py-12 bg-white rounded-lg border border-gray-200">
          <div className="text-gray-500">Select an entity above to visualize its relationships</div>
        </div>
      )}
    </div>
  );
}
