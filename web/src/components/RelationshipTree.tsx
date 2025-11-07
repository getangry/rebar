import { useState, useEffect } from 'react';
import { rebarClient } from '../api/rebar';
import type { GraphResponse } from '../api/rebar';
import { Group } from '@visx/group';
import { hierarchy, Tree } from '@visx/hierarchy';
import { LinearGradient } from '@visx/gradient';
import { Alert, AlertDescription } from './ui/alert';

interface TreeNode {
  name: string;
  type: string;
  children?: TreeNode[];
}

const colors = {
  user: '#818cf8',
  group: '#34d399',
  doc: '#fbbf24',
  folder: '#f472b6',
  default: '#9ca3af',
};

export default function RelationshipTree() {
  const [graphData, setGraphData] = useState<GraphResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadGraph();
  }, []);

  const loadGraph = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await rebarClient.getGraph();
      setGraphData(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load graph');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="text-gray-500">Loading relationship graph...</div>
      </div>
    );
  }

  if (error) {
    return (
      <Alert variant="destructive">
        <AlertDescription>{error}</AlertDescription>
      </Alert>
    );
  }

  if (!graphData || graphData.nodes.length === 0) {
    return (
      <Alert>
        <AlertDescription>
          No relationships found. Create some tuples to see the relationship graph.
        </AlertDescription>
      </Alert>
    );
  }

  // Convert graph data to tree structure for visx
  const buildTree = (): TreeNode => {
    // Group nodes by type
    const nodesByType: Record<string, any[]> = {};
    graphData.nodes.forEach((node) => {
      if (!nodesByType[node.type]) {
        nodesByType[node.type] = [];
      }
      nodesByType[node.type].push(node);
    });

    // Build tree with types as top level
    const root: TreeNode = {
      name: 'Relationships',
      type: 'root',
      children: Object.entries(nodesByType).map(([type, nodes]) => ({
        name: `${type} (${nodes.length})`,
        type: type,
        children: nodes.map((node) => ({
          name: node.label,
          type: node.type,
        })),
      })),
    };

    return root;
  };

  const treeData = buildTree();
  const width = 1200;
  const height = 800;
  const margin = { top: 40, left: 40, right: 40, bottom: 40 };

  const yMax = height - margin.top - margin.bottom;
  const xMax = width - margin.left - margin.right;

  return (
    <div>
      {/* Header */}
      <div className="mb-6">
        <h2 className="text-2xl font-semibold text-gray-900">Relationship Graph</h2>
        <p className="mt-2 text-sm text-gray-600">
          Showing {graphData.node_count} nodes and {graphData.edge_count} relationships
        </p>
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

      {/* Tree Visualization */}
      <div className="bg-white rounded-lg border border-gray-200 p-6 overflow-x-auto">
        <svg width={width} height={height}>
          <LinearGradient id="links-gradient" from="#fd9b93" to="#fe6e9e" />
          <rect width={width} height={height} rx={14} fill="#fafafa" />
          <Group top={margin.top} left={margin.left}>
            <Tree<TreeNode>
              root={hierarchy(treeData, (d) => d.children)}
              size={[yMax, xMax]}
              separation={(a, b) => (a.parent === b.parent ? 1 : 0.5) / a.depth}
            >
              {(tree) => (
                <Group>
                  {/* Links */}
                  {tree.links().map((link, i) => (
                    <line
                      key={`link-${i}`}
                      x1={link.source.y}
                      y1={link.source.x}
                      x2={link.target.y}
                      y2={link.target.x}
                      stroke="#cbd5e1"
                      strokeWidth="1.5"
                      strokeOpacity={0.6}
                    />
                  ))}

                  {/* Nodes */}
                  {tree.descendants().map((node, i) => {
                    const nodeColor = colors[node.data.type as keyof typeof colors] || colors.default;
                    const isRoot = node.depth === 0;
                    const isType = node.depth === 1;

                    return (
                      <Group key={`node-${i}`} top={node.x} left={node.y}>
                        <circle
                          r={isRoot ? 12 : isType ? 8 : 6}
                          fill={nodeColor}
                          stroke={isRoot ? '#6366f1' : '#fff'}
                          strokeWidth={isRoot ? 3 : 2}
                          strokeOpacity={isRoot ? 1 : 0.8}
                        />
                        <text
                          dy=".33em"
                          fontSize={isRoot ? 14 : isType ? 12 : 10}
                          fontFamily="system-ui, sans-serif"
                          textAnchor="middle"
                          fill="#1f2937"
                          fontWeight={isRoot || isType ? 'bold' : 'normal'}
                          x={node.y > xMax / 2 ? -20 : 20}
                          y={0}
                        >
                          {node.data.name}
                        </text>
                      </Group>
                    );
                  })}
                </Group>
              )}
            </Tree>
          </Group>
        </svg>
      </div>

      {/* Node Details */}
      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {Object.entries(graphData.nodes.reduce((acc, node) => {
          if (!acc[node.type]) acc[node.type] = [];
          acc[node.type].push(node);
          return acc;
        }, {} as Record<string, typeof graphData.nodes>)).map(([type, nodes]) => (
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
  );
}
