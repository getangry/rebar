import { useState } from 'react';
import { rebarClient } from '../api/rebar';

interface Log {
  type: 'info' | 'success' | 'error';
  message: string;
  timestamp: Date;
}

export default function RebarDemo() {
  const [logs, setLogs] = useState<Log[]>([]);
  const [loading, setLoading] = useState(false);

  const addLog = (type: Log['type'], message: string) => {
    setLogs((prev) => [...prev, { type, message, timestamp: new Date() }]);
  };

  const clearLogs = () => setLogs([]);

  const clearDemoData = async () => {
    setLoading(true);
    clearLogs();

    try {
      addLog('info', '🧹 Clearing old demo data...');

      // Delete all demo-related tuples
      await rebarClient.batchDelete([
        { subject: 'doc', id: 'quarterly-report', relation: 'owner', actor: 'user', actor_id: 'alice' },
        { subject: 'doc', id: 'quarterly-report', relation: 'editor', actor: 'user', actor_id: 'bob' },
        { subject: 'group', id: 'engineering', relation: 'member', actor: 'user', actor_id: 'charlie' },
        { subject: 'group', id: 'engineering', relation: 'member', actor: 'user', actor_id: 'diana' },
        { subject: 'doc', id: 'tech-specs', relation: 'viewer', actor: 'group', actor_id: 'engineering', actor_rel: 'member' },
      ]);

      addLog('success', '✅ Demo data cleared');
      addLog('info', '');
    } catch (error) {
      addLog('error', `❌ Error clearing data: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setLoading(false);
    }
  };

  const runDemo = async () => {
    setLoading(true);
    clearLogs();

    try {
      addLog('info', '🧹 Clearing any existing demo data first...');

      // Clear old data silently (don't fail if doesn't exist)
      try {
        await rebarClient.batchDelete([
          { subject: 'doc', id: 'quarterly-report', relation: 'owner', actor: 'user', actor_id: 'alice' },
          { subject: 'doc', id: 'quarterly-report', relation: 'editor', actor: 'user', actor_id: 'bob' },
          { subject: 'group', id: 'engineering', relation: 'member', actor: 'user', actor_id: 'charlie' },
          { subject: 'group', id: 'engineering', relation: 'member', actor: 'user', actor_id: 'diana' },
          { subject: 'doc', id: 'tech-specs', relation: 'viewer', actor: 'group', actor_id: 'engineering', actor_rel: 'member' },
        ]);
      } catch {
        // Ignore errors from deleting non-existent tuples
      }

      addLog('info', '🚀 Starting Rebar API Demo...');
      addLog('info', '');

      // Step 1: Create document ownership
      addLog('info', '📝 Step 1: Creating document ownership');
      await rebarClient.createRelationship({
        subject: 'doc',
        id: 'quarterly-report',
        relation: 'owner',
        actor: 'user',
        actor_id: 'alice',
      });
      addLog('success', '✅ Alice is now owner of quarterly-report');
      addLog('info', '');

      // Step 2: Check permission
      addLog('info', '🔍 Step 2: Checking if Alice can view the document');
      const aliceCanView = await rebarClient.checkPermission({
        actor: 'user',
        actor_id: 'alice',
        permission: 'viewer',
        subject: 'doc',
        subject_id: 'quarterly-report',
      });
      addLog(
        'success',
        `✅ Alice can view: ${aliceCanView} (owners automatically get viewer permission)`
      );
      addLog('info', '');

      // Step 3: Share with Bob
      addLog('info', '🤝 Step 3: Sharing document with Bob (editor access)');
      await rebarClient.createRelationship({
        subject: 'doc',
        id: 'quarterly-report',
        relation: 'editor',
        actor: 'user',
        actor_id: 'bob',
      });
      addLog('success', '✅ Bob now has editor access');
      addLog('info', '');

      // Step 4: Check Bob's permission
      addLog('info', '🔍 Step 4: Checking if Bob can view the document');
      const bobCanView = await rebarClient.checkPermission({
        actor: 'user',
        actor_id: 'bob',
        permission: 'viewer',
        subject: 'doc',
        subject_id: 'quarterly-report',
      });
      addLog('success', `✅ Bob can view: ${bobCanView} (editors get viewer permission)`);
      addLog('info', '');

      // Step 5: Create group structure
      addLog('info', '👥 Step 5: Creating engineering team structure');
      await rebarClient.batchCreate([
        {
          subject: 'group',
          id: 'engineering',
          relation: 'member',
          actor: 'user',
          actor_id: 'charlie',
        },
        {
          subject: 'group',
          id: 'engineering',
          relation: 'member',
          actor: 'user',
          actor_id: 'diana',
        },
        {
          subject: 'doc',
          id: 'tech-specs',
          relation: 'viewer',
          actor: 'group',
          actor_id: 'engineering',
          actor_rel: 'member',
        },
      ]);
      addLog('success', '✅ Engineering team created with 2 members');
      addLog('success', '✅ Tech specs shared with engineering team');
      addLog('info', '');

      // Step 6: Check group member permission
      addLog('info', '🔍 Step 6: Checking if Charlie (eng member) can view tech specs');
      const charlieCanView = await rebarClient.checkPermission({
        actor: 'user',
        actor_id: 'charlie',
        permission: 'viewer',
        subject: 'doc',
        subject_id: 'tech-specs',
      });
      addLog('success', `✅ Charlie can view: ${charlieCanView} (through group membership)`);
      addLog('info', '');

      // Step 7: Explain permission
      addLog('info', '🧠 Step 7: Getting explanation of Charlie\'s permission');
      const explanation = await rebarClient.explainPermission({
        actor: 'user',
        actor_id: 'charlie',
        permission: 'viewer',
        subject: 'doc',
        subject_id: 'tech-specs',
      });
      if (explanation.allow && explanation.path) {
        addLog('success', `✅ Permission path: ${JSON.stringify(explanation.path, null, 2)}`);
      }
      addLog('info', '');

      // Step 8: Revoke access
      addLog('info', '❌ Step 8: Revoking Bob\'s editor access');
      await rebarClient.deleteRelationship({
        subject: 'doc',
        id: 'quarterly-report',
        relation: 'editor',
        actor: 'user',
        actor_id: 'bob',
      });
      addLog('success', '✅ Bob\'s editor access revoked');
      addLog('info', '');

      // Step 9: Verify revocation
      addLog('info', '🔍 Step 9: Verifying Bob no longer has access');
      const bobStillHasAccess = await rebarClient.checkPermission({
        actor: 'user',
        actor_id: 'bob',
        permission: 'editor',
        subject: 'doc',
        subject_id: 'quarterly-report',
      });
      addLog('success', `✅ Bob can edit: ${bobStillHasAccess} (access successfully revoked)`);
      addLog('info', '');

      addLog('success', '🎉 Demo completed successfully!');
    } catch (error) {
      addLog('error', `❌ Error: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setLoading(false);
    }
  };

  const testHealth = async () => {
    try {
      addLog('info', '🏥 Checking API health...');
      await rebarClient.health();
      addLog('success', '✅ API is healthy!');
    } catch (error) {
      addLog('error', `❌ API health check failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  };

  return (
    <div style={{ padding: '2rem', maxWidth: '1200px', margin: '0 auto' }}>
      <h1>🔐 Rebar Authorization API Demo</h1>
      <p style={{ color: '#666', marginBottom: '2rem' }}>
        This demo showcases the Relationship-Based Access Control (ReBAC) system.
        Click "Run Demo" to see how permissions work through relationships.
      </p>

      <div style={{ display: 'flex', gap: '1rem', marginBottom: '2rem' }}>
        <button
          onClick={runDemo}
          disabled={loading}
          style={{
            padding: '0.75rem 1.5rem',
            fontSize: '1rem',
            background: loading ? '#ccc' : '#007bff',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: loading ? 'not-allowed' : 'pointer',
          }}
        >
          {loading ? '⏳ Running...' : '▶️ Run Demo'}
        </button>

        <button
          onClick={clearDemoData}
          disabled={loading}
          style={{
            padding: '0.75rem 1.5rem',
            fontSize: '1rem',
            background: loading ? '#ccc' : '#dc3545',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: loading ? 'not-allowed' : 'pointer',
          }}
        >
          🧹 Clear Demo Data
        </button>

        <button
          onClick={testHealth}
          disabled={loading}
          style={{
            padding: '0.75rem 1.5rem',
            fontSize: '1rem',
            background: '#28a745',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: loading ? 'not-allowed' : 'pointer',
          }}
        >
          🏥 Health Check
        </button>

        <button
          onClick={clearLogs}
          style={{
            padding: '0.75rem 1.5rem',
            fontSize: '1rem',
            background: '#6c757d',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
          }}
        >
          🗑️ Clear Logs
        </button>
      </div>

      <div
        style={{
          background: '#1e1e1e',
          color: '#d4d4d4',
          padding: '1.5rem',
          borderRadius: '8px',
          fontFamily: 'monospace',
          fontSize: '14px',
          lineHeight: '1.6',
          maxHeight: '600px',
          overflowY: 'auto',
        }}
      >
        {logs.length === 0 ? (
          <div style={{ color: '#888' }}>No logs yet. Click "Run Demo" to start!</div>
        ) : (
          logs.map((log, index) => (
            <div
              key={index}
              style={{
                color:
                  log.type === 'error'
                    ? '#f85149'
                    : log.type === 'success'
                    ? '#7ee787'
                    : '#d4d4d4',
                marginBottom: '0.25rem',
              }}
            >
              {log.message}
            </div>
          ))
        )}
      </div>

      <div style={{ marginTop: '2rem', padding: '1rem', background: '#f8f9fa', borderRadius: '4px' }}>
        <h3>📚 What's Happening?</h3>
        <ul style={{ lineHeight: '1.8' }}>
          <li><strong>Ownership:</strong> Alice owns the quarterly report (direct relationship)</li>
          <li><strong>Permission Cascade:</strong> Owners automatically get editor and viewer permissions</li>
          <li><strong>Sharing:</strong> Documents can be shared with specific users</li>
          <li><strong>Group-Based Access:</strong> Teams can have collective permissions</li>
          <li><strong>Group Expansion:</strong> Team members inherit team permissions</li>
          <li><strong>Dynamic Revocation:</strong> Access can be removed instantly</li>
        </ul>
      </div>

      <div style={{ marginTop: '1rem', color: '#666', fontSize: '0.9rem' }}>
        <p>
          <strong>API Endpoints:</strong> This demo uses the Rebar API at{' '}
          <code>http://localhost:3000</code> (proxied through Vite)
        </p>
        <p>
          <strong>Documentation:</strong> See <code>USAGE.md</code> for complete API reference
        </p>
      </div>
    </div>
  );
}
