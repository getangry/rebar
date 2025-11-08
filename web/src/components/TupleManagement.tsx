import { useState } from 'react';
import { rebarClient } from '../api/rebar';
import type { RelationshipTuple } from '../api/rebar';
import Button from './ui/button';
import { InputGroup } from './ui/input-group';
import { Alert, AlertDescription } from './ui/alert';

interface TupleWithMetadata extends RelationshipTuple {
  reason?: string;
}

export default function TupleManagement() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [showAddForm, setShowAddForm] = useState(false);

  // Form state
  const [newTuple, setNewTuple] = useState<TupleWithMetadata>({
    subject: '',
    id: '',
    relation: '',
    actor: '',
    actor_id: '',
    actor_rel: '',
    reason: '',
  });


  const handleAddTuple = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);
    setLoading(true);

    try {
      await rebarClient.createRelationship({
        subject: newTuple.subject,
        id: newTuple.id,
        relation: newTuple.relation,
        actor: newTuple.actor,
        actor_id: newTuple.actor_id,
        actor_rel: newTuple.actor_rel || undefined,
      });

      setSuccess(`Successfully created relationship: ${newTuple.actor}:${newTuple.actor_id} → ${newTuple.relation} → ${newTuple.subject}:${newTuple.id}`);

      // Reset form
      setNewTuple({
        subject: '',
        id: '',
        relation: '',
        actor: '',
        actor_id: '',
        actor_rel: '',
        reason: '',
      });
      setShowAddForm(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create relationship');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8">
      {/* Page header */}
      <div className="mb-8">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold text-gray-900">Tuple Management</h1>
            <p className="mt-2 text-sm text-gray-600">
              Create and manage relationship tuples in your authorization system.
            </p>
          </div>
          <Button
            onClick={() => setShowAddForm(!showAddForm)}
            variant="default"
          >
            {showAddForm ? 'Cancel' : '+ Add Tuple'}
          </Button>
        </div>
      </div>

      {/* Success/Error Messages */}
      {success && (
        <div className="mb-6">
          <Alert variant="success">
            <AlertDescription>{success}</AlertDescription>
          </Alert>
        </div>
      )}

      {error && (
        <div className="mb-6">
          <Alert variant="destructive">
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        </div>
      )}

      {/* Add Tuple Form */}
      {showAddForm && (
        <div className="mb-8 bg-white rounded-lg border border-gray-200 p-6">
          <h3 className="text-base font-semibold text-gray-900 mb-6">Create New Relationship Tuple</h3>
          <form onSubmit={handleAddTuple}>
            <div className="space-y-6">
              {/* Resource (Subject) */}
              <div className="border-b border-gray-200 pb-6">
                <h4 className="text-sm font-medium text-gray-900 mb-4">Resource (What)</h4>
                <div className="grid grid-cols-1 gap-6 sm:grid-cols-2">
                  <InputGroup
                    label="Subject Type"
                    id="subject"
                    placeholder="e.g., document, folder, project"
                    value={newTuple.subject}
                    onChange={(e) => setNewTuple({ ...newTuple, subject: e.target.value })}
                    helpText="The type of resource being accessed"
                    required
                  />
                  <InputGroup
                    label="Resource ID"
                    id="id"
                    placeholder="e.g., doc-123, folder-456"
                    value={newTuple.id}
                    onChange={(e) => setNewTuple({ ...newTuple, id: e.target.value })}
                    helpText="The specific instance identifier"
                    required
                  />
                </div>
              </div>

              {/* Relation */}
              <div className="border-b border-gray-200 pb-6">
                <h4 className="text-sm font-medium text-gray-900 mb-4">Relationship</h4>
                <div className="grid grid-cols-1 gap-6 sm:grid-cols-2">
                  <InputGroup
                    label="Relation"
                    id="relation"
                    placeholder="e.g., owner, viewer, editor, member"
                    value={newTuple.relation}
                    onChange={(e) => setNewTuple({ ...newTuple, relation: e.target.value })}
                    helpText="The type of relationship or permission"
                    required
                  />
                </div>
              </div>

              {/* Actor (Who) */}
              <div className="border-b border-gray-200 pb-6">
                <h4 className="text-sm font-medium text-gray-900 mb-4">Actor (Who)</h4>
                <div className="grid grid-cols-1 gap-6 sm:grid-cols-2">
                  <InputGroup
                    label="Actor Type"
                    id="actor"
                    placeholder="e.g., user, group, service"
                    value={newTuple.actor}
                    onChange={(e) => setNewTuple({ ...newTuple, actor: e.target.value })}
                    helpText="The type of entity with the relationship"
                    required
                  />
                  <InputGroup
                    label="Actor ID"
                    id="actor_id"
                    placeholder="e.g., alice, group-123"
                    value={newTuple.actor_id}
                    onChange={(e) => setNewTuple({ ...newTuple, actor_id: e.target.value })}
                    helpText="The specific entity identifier"
                    required
                  />
                  <InputGroup
                    label="Actor Relation (Optional)"
                    id="actor_rel"
                    placeholder="e.g., member (for indirect relations)"
                    value={newTuple.actor_rel}
                    onChange={(e) => setNewTuple({ ...newTuple, actor_rel: e.target.value })}
                    helpText="For userset relations (advanced)"
                  />
                </div>
              </div>

              {/* Context/Metadata */}
              <div>
                <h4 className="text-sm font-medium text-gray-900 mb-4">Context (Optional)</h4>
                <div className="grid grid-cols-1 gap-6">
                  <div>
                    <label htmlFor="reason" className="block text-sm font-medium text-gray-700 mb-2">
                      Reason
                    </label>
                    <textarea
                      id="reason"
                      rows={3}
                      value={newTuple.reason}
                      onChange={(e) => setNewTuple({ ...newTuple, reason: e.target.value })}
                      placeholder="Why is this relationship being created? (appears in audit logs)"
                      className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    />
                  </div>
                </div>
              </div>
            </div>

            <div className="mt-6 flex items-center gap-x-3">
              <Button type="submit" variant="default" disabled={loading}>
                {loading ? 'Creating...' : 'Create Relationship'}
              </Button>
              <Button
                type="button"
                variant="secondary"
                onClick={() => setShowAddForm(false)}
              >
                Cancel
              </Button>
            </div>
          </form>
        </div>
      )}

      {/* Quick Examples */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-6">
        <h3 className="text-sm font-semibold text-gray-900 mb-3">Common Examples</h3>
        <div className="space-y-3 text-sm text-gray-700">
          <div>
            <strong>Grant ownership:</strong>
            <code className="ml-2 bg-white px-2 py-1 rounded text-xs text-gray-900">
              user:alice → owner → document:doc-123
            </code>
          </div>
          <div>
            <strong>Add viewer:</strong>
            <code className="ml-2 bg-white px-2 py-1 rounded text-xs text-gray-900">
              user:bob → viewer → folder:folder-456
            </code>
          </div>
          <div>
            <strong>Group membership:</strong>
            <code className="ml-2 bg-white px-2 py-1 rounded text-xs text-gray-900">
              user:charlie → member → group:engineers
            </code>
          </div>
          <div>
            <strong>Indirect permission (via group):</strong>
            <code className="ml-2 bg-white px-2 py-1 rounded text-xs text-gray-900">
              group:engineers → editor → project:proj-789
            </code>
          </div>
        </div>
      </div>

      {/* Permission Checker */}
      <div className="mt-8 bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-base font-semibold text-gray-900 mb-6">Quick Permission Check</h3>
        <PermissionChecker />
      </div>
    </div>
  );
}

// Inline Permission Checker Component
function PermissionChecker() {
  const [checking, setChecking] = useState(false);
  const [result, setResult] = useState<{ allow: boolean } | null>(null);
  const [checkData, setCheckData] = useState({
    actor: '',
    actor_id: '',
    permission: '',
    subject: '',
    subject_id: '',
  });

  const handleCheck = async (e: React.FormEvent) => {
    e.preventDefault();
    setChecking(true);
    setResult(null);

    try {
      const allowed = await rebarClient.checkPermission({
        actor: checkData.actor,
        actor_id: checkData.actor_id,
        permission: checkData.permission,
        subject: checkData.subject,
        subject_id: checkData.subject_id,
      });
      setResult({ allow: allowed });
    } catch (err) {
      console.error('Permission check failed:', err);
      setResult({ allow: false });
    } finally {
      setChecking(false);
    }
  };

  return (
    <form onSubmit={handleCheck}>
      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <InputGroup
          label="Actor"
          id="check_actor"
          placeholder="user"
          value={checkData.actor}
          onChange={(e) => setCheckData({ ...checkData, actor: e.target.value })}
        />
        <InputGroup
          label="Actor ID"
          id="check_actor_id"
          placeholder="alice"
          value={checkData.actor_id}
          onChange={(e) => setCheckData({ ...checkData, actor_id: e.target.value })}
        />
        <InputGroup
          label="Permission"
          id="check_permission"
          placeholder="view"
          value={checkData.permission}
          onChange={(e) => setCheckData({ ...checkData, permission: e.target.value })}
        />
        <InputGroup
          label="Subject"
          id="check_subject"
          placeholder="document"
          value={checkData.subject}
          onChange={(e) => setCheckData({ ...checkData, subject: e.target.value })}
        />
        <InputGroup
          label="Subject ID"
          id="check_subject_id"
          placeholder="doc-123"
          value={checkData.subject_id}
          onChange={(e) => setCheckData({ ...checkData, subject_id: e.target.value })}
        />
        <div className="flex items-end">
          <Button type="submit" variant="default" disabled={checking} className="w-full">
            {checking ? 'Checking...' : 'Check Permission'}
          </Button>
        </div>
      </div>

      {result !== null && (
        <div className={`mt-4 p-4 rounded-lg ${result.allow ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'}`}>
          <div className="flex items-center">
            <span className="text-2xl mr-3">{result.allow ? '✅' : '❌'}</span>
            <div>
              <div className={`font-semibold ${result.allow ? 'text-green-900' : 'text-red-900'}`}>
                {result.allow ? 'Permission Granted' : 'Permission Denied'}
              </div>
              <div className={`text-sm ${result.allow ? 'text-green-700' : 'text-red-700'}`}>
                {checkData.actor}:{checkData.actor_id} {result.allow ? 'CAN' : 'CANNOT'} {checkData.permission} {checkData.subject}:{checkData.subject_id}
              </div>
            </div>
          </div>
        </div>
      )}
    </form>
  );
}
