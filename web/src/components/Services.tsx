import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { rebarClient } from '../api/rebar';
import type { Service, CreateServiceRequest } from '../api/rebar';
import Button from './ui/button';
import Badge from './ui/badge';
import { InputGroup } from './ui/input-group';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from './ui/table';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from './ui/dialog';
import { Alert, AlertDescription } from './ui/alert';

export default function Services() {
  const navigate = useNavigate();
  const [services, setServices] = useState<Service[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Create dialog
  const [showDialog, setShowDialog] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [formData, setFormData] = useState<CreateServiceRequest>({
    name: '',
    description: '',
    schemas: ['default'],
    active: true,
    allowed_subjects: [],
    allowed_relations: [],
    metadata: {},
  });

  // New API key display (shown after creation)
  const [newApiKey, setNewApiKey] = useState<string | null>(null);
  const [showApiKeyDialog, setShowApiKeyDialog] = useState(false);

  useEffect(() => {
    loadServices();
  }, []);

  const loadServices = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await rebarClient.getServices();
      setServices(response.services);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load services');
    } finally {
      setLoading(false);
    }
  };

  const openCreateDialog = () => {
    setFormData({
      name: '',
      description: '',
      schemas: ['default'],
      active: true,
      allowed_subjects: [],
      allowed_relations: [],
      metadata: {},
    });
    setFormError(null);
    setShowDialog(true);
  };

  const handleSubmit = async () => {
    try {
      const created = await rebarClient.createService(formData);
      setServices([created, ...services]);

      // Show API key dialog
      if (created.api_key) {
        setNewApiKey(created.api_key);
        setShowApiKeyDialog(true);
      }

      setShowDialog(false);
      setFormError(null);
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to create service');
    }
  };

  const handleDelete = async (service: Service, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!confirm(`Are you sure you want to delete "${service.name}"? This action cannot be undone.`)) {
      return;
    }

    try {
      await rebarClient.deleteService(service.id);
      setServices(services.filter(s => s.id !== service.id));
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete service');
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8">
      <div className="mb-8">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold text-gray-900">Services</h1>
            <p className="mt-2 text-sm text-gray-600">
              Manage API clients and their access permissions
            </p>
          </div>
          <Button onClick={openCreateDialog}>Create Service</Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {loading ? (
        <div className="text-center py-8 text-gray-600">
          Loading services...
        </div>
      ) : services.length === 0 ? (
        <div className="text-center py-12 bg-white rounded-lg border border-gray-200">
          <p className="text-gray-600 mb-4">No services found</p>
          <Button onClick={openCreateDialog}>Create your first service</Button>
        </div>
      ) : (
        <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Name</TableHead>
                <TableHead>Schema</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Subjects</TableHead>
                <TableHead>Relations</TableHead>
                <TableHead>Created</TableHead>
                <TableHead>Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {services.map((service) => (
                <TableRow
                  key={service.id}
                  onClick={() => navigate(`/services/${service.id}`)}
                  className="cursor-pointer hover:bg-gray-50"
                >
                  <TableCell>
                    <div>
                      <div className="font-medium text-gray-900">
                        {service.name}
                      </div>
                      {service.description && (
                        <p className="text-sm text-gray-500">
                          {service.description}
                        </p>
                      )}
                    </div>
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-wrap gap-1">
                      {service.schemas.map((schema) => (
                        <code key={schema} className="text-xs text-gray-900 bg-gray-100 px-2 py-1 rounded">
                          {schema}
                        </code>
                      ))}
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge variant={service.active ? 'success' : 'default'}>
                      {service.active ? 'Active' : 'Inactive'}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <span className="text-sm text-gray-600">
                      {service.allowed_subjects.length === 0
                        ? 'All'
                        : service.allowed_subjects.length}
                    </span>
                  </TableCell>
                  <TableCell>
                    <span className="text-sm text-gray-600">
                      {service.allowed_relations.length === 0
                        ? 'All'
                        : service.allowed_relations.length}
                    </span>
                  </TableCell>
                  <TableCell className="text-sm text-gray-600">
                    {formatDate(service.created_at)}
                  </TableCell>
                  <TableCell onClick={(e) => e.stopPropagation()}>
                    <button
                      onClick={(e) => handleDelete(service, e)}
                      className="text-sm text-red-600 hover:underline"
                    >
                      Delete
                    </button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {/* Create Dialog */}
      <Dialog open={showDialog} onOpenChange={(open) => {
        setShowDialog(open);
        if (!open) setFormError(null);
      }}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Create Service</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            {formError && (
              <Alert variant="destructive">
                <AlertDescription>{formError}</AlertDescription>
              </Alert>
            )}
            <InputGroup
              label="Name"
              id="name"
              required
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              placeholder="e.g., Production App, Mobile Client"
            />
            <InputGroup
              label="Description"
              id="description"
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              placeholder="Optional description"
            />
            <p className="text-sm text-gray-500">
              Note: Service will be created with "default" schema. You can add more schemas after creation.
            </p>
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="active"
                checked={formData.active}
                onChange={(e) => setFormData({ ...formData, active: e.target.checked })}
                className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              />
              <label htmlFor="active" className="text-sm font-medium text-gray-700">
                Active
              </label>
            </div>
            <div className="flex gap-2 pt-4">
              <Button onClick={handleSubmit} className="flex-1">
                Create Service
              </Button>
              <Button onClick={() => setShowDialog(false)} variant="outline">
                Cancel
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* API Key Display Dialog */}
      <Dialog open={showApiKeyDialog} onOpenChange={setShowApiKeyDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>API Key Generated</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <Alert>
              <AlertDescription>
                Save this API key now. For security reasons, it won't be shown again.
              </AlertDescription>
            </Alert>
            <div className="bg-gray-100 p-4 rounded-lg">
              <code className="text-sm text-gray-900 break-all">{newApiKey}</code>
            </div>
            <div className="flex gap-2">
              <Button
                onClick={() => newApiKey && copyToClipboard(newApiKey)}
                className="flex-1"
              >
                Copy to Clipboard
              </Button>
              <Button
                onClick={() => {
                  setShowApiKeyDialog(false);
                  setNewApiKey(null);
                }}
                variant="outline"
              >
                Close
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
