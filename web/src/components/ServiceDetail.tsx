import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { rebarClient } from '../api/rebar';
import type { Service, SchemaResponse } from '../api/rebar';
import Button from './ui/button';
import Badge from './ui/badge';
import { Alert, AlertDescription } from './ui/alert';
import Autocomplete from './ui/autocomplete';

export default function ServiceDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const [service, setService] = useState<Service | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isEditing, setIsEditing] = useState(false);

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    description: '',
  });

  // Subject/relation/schema management
  const [newSubject, setNewSubject] = useState('');
  const [newRelation, setNewRelation] = useState('');
  const [newSchema, setNewSchema] = useState('');

  // API key display
  const [newApiKey, setNewApiKey] = useState<string | null>(null);
  const [showCreateKeyForm, setShowCreateKeyForm] = useState(false);
  const [newKeyName, setNewKeyName] = useState('');

  // Schema data for autocomplete
  const [availableSubjects, setAvailableSubjects] = useState<string[]>([]);
  const [availableRelations, setAvailableRelations] = useState<string[]>([]);

  useEffect(() => {
    if (id) {
      loadService();
    }
  }, [id]);

  useEffect(() => {
    loadSchema();
  }, []);

  const loadSchema = async () => {
    try {
      const schema = await rebarClient.getSchema();

      // Extract all unique subject types
      const subjects = Object.keys(schema.types);
      setAvailableSubjects(subjects);

      // Extract all unique relations from all types
      const relations = new Set<string>();
      Object.values(schema.types).forEach((type) => {
        if (type.relations) {
          Object.keys(type.relations).forEach((rel) => relations.add(rel));
        }
      });
      setAvailableRelations(Array.from(relations).sort());
    } catch (err) {
      console.error('Failed to load schema for autocomplete:', err);
    }
  };

  const loadService = async () => {
    if (!id) return;

    setLoading(true);
    setError(null);
    try {
      const data = await rebarClient.getService(id);
      setService(data);
      setFormData({
        name: data.name,
        description: data.description || '',
        schema_name: data.schema_name,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load service');
    } finally {
      setLoading(false);
    }
  };

  const handleUpdate = async () => {
    if (!service) return;

    try {
      const updated = await rebarClient.updateService(service.id, formData);
      setService(updated);
      setIsEditing(false);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update service');
    }
  };

  const handleDelete = async () => {
    if (!service) return;
    if (!confirm(`Are you sure you want to delete "${service.name}"? This action cannot be undone.`)) {
      return;
    }

    try {
      await rebarClient.deleteService(service.id);
      navigate('/services');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete service');
    }
  };

  const handleRegenerateKey = async () => {
    if (!service) return;
    if (!confirm(`Are you sure you want to regenerate the API key for "${service.name}"? The old key will stop working immediately.`)) {
      return;
    }

    try {
      const response = await rebarClient.regenerateServiceKey(service.id);
      setNewApiKey(response.api_key);
      setService(response.service);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to regenerate API key');
    }
  };

  const handleToggleActive = async () => {
    if (!service) return;

    try {
      const updated = service.active
        ? await rebarClient.deactivateService(service.id)
        : await rebarClient.activateService(service.id);
      setService(updated);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update service status');
    }
  };

  const handleAddSubject = async () => {
    if (!service || !newSubject.trim()) return;

    try {
      const updated = await rebarClient.addServiceSubject(service.id, newSubject.trim());
      setService(updated);
      setNewSubject('');
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add subject');
    }
  };

  const handleRemoveSubject = async (subject: string) => {
    if (!service) return;

    try {
      const updated = await rebarClient.removeServiceSubject(service.id, subject);
      setService(updated);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to remove subject');
    }
  };

  const handleAddRelation = async () => {
    if (!service || !newRelation.trim()) return;

    try {
      const updated = await rebarClient.addServiceRelation(service.id, newRelation.trim());
      setService(updated);
      setNewRelation('');
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add relation');
    }
  };

  const handleRemoveRelation = async (relation: string) => {
    if (!service) return;

    try {
      const updated = await rebarClient.removeServiceRelation(service.id, relation);
      setService(updated);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to remove relation');
    }
  };

  const handleAddSchema = async () => {
    if (!service || !newSchema.trim()) return;

    try {
      const updated = await rebarClient.addServiceSchema(service.id, newSchema.trim());
      setService(updated);
      setNewSchema('');
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add schema');
    }
  };

  const handleRemoveSchema = async (schema: string) => {
    if (!service) return;

    try {
      const updated = await rebarClient.removeServiceSchema(service.id, schema);
      setService(updated);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to remove schema');
    }
  };

  const handleCreateApiKey = async () => {
    if (!service) return;

    try {
      const response = await rebarClient.createApiKey(service.id, newKeyName || undefined);
      setNewApiKey(response.api_key);
      setService(response.service);
      setShowCreateKeyForm(false);
      setNewKeyName('');
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create API key');
    }
  };

  const handleRevokeApiKey = async (apiKeyId: string, keyName?: string) => {
    if (!service) return;
    const confirmMessage = `Are you sure you want to revoke ${keyName || 'this API key'}? This action cannot be undone and the key will stop working immediately.`;
    if (!confirm(confirmMessage)) return;

    try {
      const response = await rebarClient.revokeApiKey(service.id, apiKeyId);
      setService(response.service);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to revoke API key');
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  if (loading) {
    return (
      <div className="px-4 sm:px-6 lg:px-8">
        <div className="text-center py-12">
          <p className="text-gray-600">Loading service...</p>
        </div>
      </div>
    );
  }

  if (!service) {
    return (
      <div className="px-4 sm:px-6 lg:px-8">
        <div className="text-center py-12">
          <p className="text-gray-600">Service not found</p>
          <Button onClick={() => navigate('/services')} className="mt-4">
            Back to Services
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="px-4 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="mb-8">
        <button
          onClick={() => navigate('/services')}
          className="text-sm text-gray-500 hover:text-gray-700 mb-2 flex items-center gap-1"
        >
          <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" strokeWidth="2" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
          Back to Services
        </button>
        <div className="flex items-start justify-between">
          <div className="flex-1">
            {isEditing ? (
              <input
                type="text"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                className="text-2xl font-semibold text-gray-900 bg-transparent border-b-2 border-gray-300 focus:border-blue-500 focus:outline-none"
              />
            ) : (
              <h1 className="text-2xl font-semibold text-gray-900">{service.name}</h1>
            )}
            {isEditing ? (
              <textarea
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                placeholder="Description"
                className="mt-2 w-full text-gray-600 bg-transparent border border-gray-300 rounded-md p-2 focus:border-blue-500 focus:outline-none"
                rows={2}
              />
            ) : (
              <p className="text-gray-600 mt-1">
                {service.description || 'No description'}
              </p>
            )}
          </div>
          <div className="flex gap-2 ml-4">
            {isEditing ? (
              <>
                <Button onClick={handleUpdate} size="sm">
                  Save Changes
                </Button>
                <Button onClick={() => setIsEditing(false)} variant="outline" size="sm">
                  Cancel
                </Button>
              </>
            ) : (
              <Button onClick={() => setIsEditing(true)} variant="outline" size="sm">
                Edit
              </Button>
            )}
          </div>
        </div>
      </div>

      {error && (
        <Alert variant="destructive" className="mb-6">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {newApiKey && (
        <Alert className="mb-6">
          <AlertDescription>
            <div className="space-y-2">
              <p className="font-semibold">New API Key Generated</p>
              <p className="text-sm">Save this API key now. For security reasons, it won't be shown again.</p>
              <div className="bg-gray-100 p-3 rounded-md">
                <code className="text-sm text-gray-900 break-all">{newApiKey}</code>
              </div>
              <div className="flex gap-2">
                <Button onClick={() => copyToClipboard(newApiKey)} size="sm">
                  Copy to Clipboard
                </Button>
                <Button onClick={() => setNewApiKey(null)} variant="outline" size="sm">
                  Dismiss
                </Button>
              </div>
            </div>
          </AlertDescription>
        </Alert>
      )}

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column - Details */}
        <div className="lg:col-span-2 space-y-6">
          {/* Status & Schema */}
          <div className="bg-white rounded-lg border border-gray-200 p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Configuration</h2>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <label className="text-sm font-medium text-gray-700">Status</label>
                  <div className="mt-1">
                    <Badge variant={service.active ? 'success' : 'default'}>
                      {service.active ? 'Active' : 'Inactive'}
                    </Badge>
                  </div>
                </div>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={handleToggleActive}
                >
                  {service.active ? 'Deactivate' : 'Activate'}
                </Button>
              </div>

            </div>
          </div>

          {/* Schemas */}
          <div className="bg-white rounded-lg border border-gray-200 p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-2">Schemas</h2>
            <p className="text-sm text-gray-500 mb-4">
              Schemas that this service can access
            </p>
            <div className="space-y-3">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={newSchema}
                  onChange={(e) => setNewSchema(e.target.value)}
                  placeholder="e.g., default, custom-schema"
                  className="flex-1 rounded-md border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900"
                  onKeyPress={(e) => e.key === 'Enter' && handleAddSchema()}
                />
                <Button onClick={handleAddSchema} size="sm">Add</Button>
              </div>
              <div className="flex flex-wrap gap-2">
                {service.schemas.map((schema) => (
                  <Badge
                    key={schema}
                    variant="secondary"
                    className="flex items-center gap-2"
                  >
                    {schema}
                    {service.schemas.length > 1 && (
                      <button
                        onClick={() => handleRemoveSchema(schema)}
                        className="text-gray-500 hover:text-gray-700"
                      >
                        ×
                      </button>
                    )}
                  </Badge>
                ))}
              </div>
            </div>
          </div>

          {/* Allowed Subjects */}
          <div className="bg-white rounded-lg border border-gray-200 p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-2">Allowed Subjects</h2>
            <p className="text-sm text-gray-500 mb-4">
              Empty list means all subjects are allowed
            </p>
            <div className="space-y-3">
              <div className="flex gap-2">
                <Autocomplete
                  value={newSubject}
                  onChange={setNewSubject}
                  options={availableSubjects}
                  placeholder="e.g., user, document, folder"
                  className="flex-1 rounded-md border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900"
                  onSubmit={handleAddSubject}
                />
                <Button onClick={handleAddSubject} size="sm">Add</Button>
              </div>
              <div className="flex flex-wrap gap-2">
                {service.allowed_subjects.length === 0 ? (
                  <span className="text-sm text-gray-500">All subjects allowed</span>
                ) : (
                  service.allowed_subjects.map((subject) => (
                    <Badge key={subject} variant="secondary" className="pr-1">
                      {subject}
                      <button
                        onClick={() => handleRemoveSubject(subject)}
                        className="ml-2 text-gray-500 hover:text-gray-700"
                      >
                        ×
                      </button>
                    </Badge>
                  ))
                )}
              </div>
            </div>
          </div>

          {/* Allowed Relations */}
          <div className="bg-white rounded-lg border border-gray-200 p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-2">Allowed Relations</h2>
            <p className="text-sm text-gray-500 mb-4">
              Empty list means all relations are allowed
            </p>
            <div className="space-y-3">
              <div className="flex gap-2">
                <Autocomplete
                  value={newRelation}
                  onChange={setNewRelation}
                  options={availableRelations}
                  placeholder="e.g., editor, viewer, owner"
                  className="flex-1 rounded-md border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900"
                  onSubmit={handleAddRelation}
                />
                <Button onClick={handleAddRelation} size="sm">Add</Button>
              </div>
              <div className="flex flex-wrap gap-2">
                {service.allowed_relations.length === 0 ? (
                  <span className="text-sm text-gray-500">All relations allowed</span>
                ) : (
                  service.allowed_relations.map((relation) => (
                    <Badge key={relation} variant="secondary" className="pr-1">
                      {relation}
                      <button
                        onClick={() => handleRemoveRelation(relation)}
                        className="ml-2 text-gray-500 hover:text-gray-700"
                      >
                        ×
                      </button>
                    </Badge>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Right Column - API Key & Metadata */}
        <div className="space-y-6">
          {/* API Keys */}
          <div className="bg-white rounded-lg border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">API Keys</h2>
              <Button onClick={() => setShowCreateKeyForm(!showCreateKeyForm)} size="sm">
                {showCreateKeyForm ? 'Cancel' : '+ New Key'}
              </Button>
            </div>

            {showCreateKeyForm && (
              <div className="mb-4 p-4 bg-gray-50 rounded-lg border border-gray-200">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Key Name (optional)
                </label>
                <input
                  type="text"
                  value={newKeyName}
                  onChange={(e) => setNewKeyName(e.target.value)}
                  placeholder="e.g., Production Server, Mobile App"
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm mb-2"
                />
                <Button onClick={handleCreateApiKey} size="sm" className="w-full">
                  Create API Key
                </Button>
              </div>
            )}

            <div className="space-y-3">
              {service.api_keys.length === 0 ? (
                <p className="text-sm text-gray-500 text-center py-4">No API keys yet</p>
              ) : (
                service.api_keys.map((key) => (
                  <div key={key.id} className="border border-gray-200 rounded-lg p-4">
                    <div className="flex items-start justify-between mb-2">
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <code className="text-sm font-mono text-gray-900">{key.key_prefix}</code>
                          {key.active ? (
                            <span className="text-xs px-2 py-0.5 bg-green-100 text-green-700 rounded">Active</span>
                          ) : (
                            <span className="text-xs px-2 py-0.5 bg-gray-100 text-gray-600 rounded">Revoked</span>
                          )}
                        </div>
                        {key.name && (
                          <p className="text-sm text-gray-600 mt-1">{key.name}</p>
                        )}
                      </div>
                      {key.active && (
                        <button
                          onClick={() => handleRevokeApiKey(key.id, key.name)}
                          className="text-xs text-red-600 hover:underline"
                        >
                          Revoke
                        </button>
                      )}
                    </div>
                    <div className="grid grid-cols-2 gap-2 mt-3 text-xs text-gray-500">
                      <div>
                        <span className="font-medium">Created:</span> {new Date(key.created_at).toLocaleDateString()}
                      </div>
                      <div>
                        <span className="font-medium">Usage:</span> {key.usage_count.toLocaleString()} requests
                      </div>
                      <div className="col-span-2">
                        <span className="font-medium">Last used:</span>{' '}
                        {key.last_used_at ? (
                          <>
                            {new Date(key.last_used_at).toLocaleString()}
                            {new Date(key.last_used_at) < new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) && (
                              <span className="ml-2 text-orange-600">(Stale)</span>
                            )}
                          </>
                        ) : (
                          <span className="text-orange-600">Never</span>
                        )}
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>

            <p className="text-xs text-gray-500 mt-4">
              API keys are hashed and cannot be retrieved. The key is only shown once during creation.
            </p>
          </div>

          {/* Metadata */}
          <div className="bg-white rounded-lg border border-gray-200 p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Metadata</h2>
            <div className="space-y-3 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-500">Service ID</span>
                <span className="text-gray-900 font-mono">{service.id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Tenant</span>
                <span className="text-gray-900">{service.tenant_id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Created</span>
                <span className="text-gray-900">{formatDate(service.created_at)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Updated</span>
                <span className="text-gray-900">{formatDate(service.updated_at)}</span>
              </div>
            </div>
          </div>

          {/* Danger Zone */}
          <div className="bg-white rounded-lg border border-red-200 p-6">
            <h2 className="text-lg font-semibold text-red-600 mb-4">Danger Zone</h2>
            <p className="text-sm text-gray-600 mb-4">
              Once deleted, this service and its API key will be permanently removed.
            </p>
            <Button
              onClick={handleDelete}
              variant="destructive"
              className="w-full"
            >
              Delete Service
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
