import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { rebarClient } from '../api/rebar';
import type { Service } from '../api/rebar';
import Button from './ui/button';
import Badge from './ui/badge';
import { Alert, AlertDescription } from './ui/alert';

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
    schema_name: 'default',
  });

  // Subject/relation management
  const [newSubject, setNewSubject] = useState('');
  const [newRelation, setNewRelation] = useState('');

  // API key display
  const [newApiKey, setNewApiKey] = useState<string | null>(null);

  useEffect(() => {
    if (id) {
      loadService();
    }
  }, [id]);

  const loadService = async () => {
    if (!id) return;

    setLoading(true);
    setError(null);
    try {
      const data = await rebarClient.getService(parseInt(id));
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

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  if (loading) {
    return (
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center py-12">
          <p className="text-gray-600 dark:text-gray-400">Loading service...</p>
        </div>
      </div>
    );
  }

  if (!service) {
    return (
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center py-12">
          <p className="text-gray-600 dark:text-gray-400">Service not found</p>
          <Button onClick={() => navigate('/services')} className="mt-4">
            Back to Services
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="mb-6">
        <button
          onClick={() => navigate('/services')}
          className="text-sm text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300 mb-2 flex items-center gap-1"
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
                className="text-3xl font-bold text-gray-900 dark:text-white bg-transparent border-b-2 border-gray-300 dark:border-gray-700 focus:border-blue-500 focus:outline-none"
              />
            ) : (
              <h1 className="text-3xl font-bold text-gray-900 dark:text-white">{service.name}</h1>
            )}
            {isEditing ? (
              <textarea
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                placeholder="Description"
                className="mt-2 w-full text-gray-600 dark:text-gray-400 bg-transparent border border-gray-300 dark:border-gray-700 rounded-md p-2 focus:border-blue-500 focus:outline-none"
                rows={2}
              />
            ) : (
              <p className="text-gray-600 dark:text-gray-400 mt-1">
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
              <div className="bg-gray-100 dark:bg-gray-800 p-3 rounded-md">
                <code className="text-sm break-all">{newApiKey}</code>
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
          <div className="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Configuration</h2>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Status</label>
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

              <div>
                <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Schema</label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.schema_name}
                    onChange={(e) => setFormData({ ...formData, schema_name: e.target.value })}
                    className="mt-1 w-full rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 px-3 py-2 text-sm"
                  />
                ) : (
                  <div className="mt-1">
                    <code className="text-sm bg-gray-100 dark:bg-gray-700 px-2 py-1 rounded">
                      {service.schema_name}
                    </code>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Allowed Subjects */}
          <div className="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">Allowed Subjects</h2>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
              Empty list means all subjects are allowed
            </p>
            <div className="space-y-3">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={newSubject}
                  onChange={(e) => setNewSubject(e.target.value)}
                  placeholder="e.g., user, document, folder"
                  className="flex-1 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 px-3 py-2 text-sm"
                  onKeyPress={(e) => e.key === 'Enter' && handleAddSubject()}
                />
                <Button onClick={handleAddSubject} size="sm">Add</Button>
              </div>
              <div className="flex flex-wrap gap-2">
                {service.allowed_subjects.length === 0 ? (
                  <span className="text-sm text-gray-500 dark:text-gray-400">All subjects allowed</span>
                ) : (
                  service.allowed_subjects.map((subject) => (
                    <Badge key={subject} variant="secondary" className="pr-1">
                      {subject}
                      <button
                        onClick={() => handleRemoveSubject(subject)}
                        className="ml-2 text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
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
          <div className="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">Allowed Relations</h2>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
              Empty list means all relations are allowed
            </p>
            <div className="space-y-3">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={newRelation}
                  onChange={(e) => setNewRelation(e.target.value)}
                  placeholder="e.g., editor, viewer, owner"
                  className="flex-1 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 px-3 py-2 text-sm"
                  onKeyPress={(e) => e.key === 'Enter' && handleAddRelation()}
                />
                <Button onClick={handleAddRelation} size="sm">Add</Button>
              </div>
              <div className="flex flex-wrap gap-2">
                {service.allowed_relations.length === 0 ? (
                  <span className="text-sm text-gray-500 dark:text-gray-400">All relations allowed</span>
                ) : (
                  service.allowed_relations.map((relation) => (
                    <Badge key={relation} variant="secondary" className="pr-1">
                      {relation}
                      <button
                        onClick={() => handleRemoveRelation(relation)}
                        className="ml-2 text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
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
          {/* API Key */}
          <div className="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">API Key</h2>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
              API keys are hashed and cannot be retrieved. Generate a new key if needed.
            </p>
            <Button onClick={handleRegenerateKey} variant="outline" className="w-full">
              Regenerate API Key
            </Button>
          </div>

          {/* Metadata */}
          <div className="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Metadata</h2>
            <div className="space-y-3 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-500 dark:text-gray-400">Service ID</span>
                <span className="text-gray-900 dark:text-white font-mono">{service.id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500 dark:text-gray-400">Tenant</span>
                <span className="text-gray-900 dark:text-white">{service.tenant_id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500 dark:text-gray-400">Created</span>
                <span className="text-gray-900 dark:text-white">{formatDate(service.created_at)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500 dark:text-gray-400">Updated</span>
                <span className="text-gray-900 dark:text-white">{formatDate(service.updated_at)}</span>
              </div>
            </div>
          </div>

          {/* Danger Zone */}
          <div className="bg-white dark:bg-gray-800 rounded-lg border border-red-200 dark:border-red-900 p-6">
            <h2 className="text-lg font-semibold text-red-600 dark:text-red-400 mb-4">Danger Zone</h2>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
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
