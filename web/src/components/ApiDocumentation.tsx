import { useState } from 'react';

export default function ApiDocumentation() {
  const [activeTab, setActiveTab] = useState<'overview' | 'openapi'>('overview');

  return (
    <div className="px-4 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-semibold text-gray-900">API Documentation</h1>
        <p className="mt-2 text-sm text-gray-600">
          Complete API reference for the Rebar authorization service
        </p>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200 mb-8">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab('overview')}
            className={`${
              activeTab === 'overview'
                ? 'border-indigo-600 text-indigo-600'
                : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700'
            } whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium`}
          >
            Quick Start
          </button>
          <button
            onClick={() => setActiveTab('openapi')}
            className={`${
              activeTab === 'openapi'
                ? 'border-indigo-600 text-indigo-600'
                : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700'
            } whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium`}
          >
            OpenAPI Spec
          </button>
        </nav>
      </div>

      {/* Content */}
      {activeTab === 'overview' && (
        <div className="prose max-w-none">
          {/* Authentication */}
          <section className="mb-12">
            <h2 className="text-xl font-semibold text-gray-900 mb-4">Authentication</h2>
            <p className="text-gray-600 mb-4">
              All API requests require two headers for authentication and multi-tenancy support:
            </p>
            <div className="bg-gray-50 rounded-lg p-4 border border-gray-200 mb-4">
              <table className="min-w-full divide-y divide-gray-200">
                <thead>
                  <tr>
                    <th className="text-left text-sm font-semibold text-gray-900 py-2">Header</th>
                    <th className="text-left text-sm font-semibold text-gray-900 py-2">Description</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  <tr>
                    <td className="py-2 text-sm font-mono text-gray-900">X-Service-Id</td>
                    <td className="py-2 text-sm text-gray-600">Service API key (format: rebar_test_* or rebar_live_*)</td>
                  </tr>
                  <tr>
                    <td className="py-2 text-sm font-mono text-gray-900">X-Tenant</td>
                    <td className="py-2 text-sm text-gray-600">Tenant identifier (defaults to "default")</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          {/* Check Permission */}
          <section className="mb-12">
            <h2 className="text-xl font-semibold text-gray-900 mb-4">Check Permission</h2>
            <p className="text-gray-600 mb-4">
              Verify if an actor has a specific permission on a subject. Supports both JSON and tuple formats.
            </p>

            <div className="mb-6">
              <h3 className="text-md font-semibold text-gray-900 mb-2">JSON Format</h3>
              <div className="bg-gray-900 rounded-lg p-4 mb-4">
                <div className="text-sm font-mono text-gray-300 mb-2">POST /api/auth/check</div>
                <pre className="text-sm text-gray-300 overflow-x-auto">
{`curl -X POST http://localhost:3000/api/auth/check \\
  -H "Content-Type: application/json" \\
  -H "X-Service-Id: dev" \\
  -H "X-Tenant: default" \\
  -d '{
    "actor": "user",
    "actor_id": "alice",
    "permission": "view",
    "subject": "document",
    "subject_id": "1"
  }'`}
                </pre>
              </div>
            </div>

            <div className="mb-6">
              <h3 className="text-md font-semibold text-gray-900 mb-2">Tuple Format (Zanzibar-style)</h3>
              <p className="text-sm text-gray-600 mb-2">
                Standard Zanzibar format: <code className="bg-gray-100 px-1 py-0.5 rounded text-gray-900">subject:id#relation@actor:id</code>
              </p>
              <div className="bg-gray-900 rounded-lg p-4 mb-4">
                <div className="text-sm font-mono text-gray-300 mb-2">POST /api/auth/check</div>
                <pre className="text-sm text-gray-300 overflow-x-auto">
{`curl -X POST http://localhost:3000/api/auth/check \\
  -H "Content-Type: application/json" \\
  -H "X-Service-Id: dev" \\
  -H "X-Tenant: default" \\
  -d '{
    "tuple": "document:1#view@user:alice"
  }'`}
                </pre>
              </div>
              <div className="bg-blue-50 border-l-4 border-blue-400 p-4">
                <p className="text-sm text-blue-700">
                  <strong>More examples:</strong>
                </p>
                <ul className="mt-2 text-sm text-blue-600 space-y-1 font-mono">
                  <li>• <code className="text-blue-700">doc:2#member@user:1</code></li>
                  <li>• <code className="text-blue-700">folder:projects#owner@user:bob</code></li>
                  <li>• <code className="text-blue-700">document:report#editor@group:engineering#member</code></li>
                </ul>
              </div>
            </div>

            <div className="bg-gray-50 rounded-lg p-4 border border-gray-200">
              <div className="text-sm font-semibold text-gray-700 mb-2">Response:</div>
              <pre className="text-sm text-gray-900">
{`{
  "allow": true
}`}
              </pre>
            </div>
          </section>

          {/* Explain Permission */}
          <section className="mb-12">
            <h2 className="text-xl font-semibold text-gray-900 mb-4">Explain Permission</h2>
            <p className="text-gray-600 mb-4">
              Get a detailed explanation of why a permission was granted or denied.
            </p>
            <div className="bg-gray-900 rounded-lg p-4 mb-4">
              <div className="text-sm font-mono text-gray-300 mb-2">POST /api/auth/explain</div>
              <pre className="text-sm text-gray-300 overflow-x-auto">
{`curl -X POST http://localhost:3000/api/auth/explain \\
  -H "Content-Type: application/json" \\
  -H "X-Service-Id: dev" \\
  -H "X-Tenant: default" \\
  -d '{
    "actor": "user",
    "actor_id": "alice",
    "permission": "view",
    "subject": "document",
    "subject_id": "1"
  }'`}
              </pre>
            </div>
          </section>

          {/* Create Relationship */}
          <section className="mb-12">
            <h2 className="text-xl font-semibold text-gray-900 mb-4">Create Relationship</h2>
            <p className="text-gray-600 mb-4">
              Create a new relationship tuple between a subject and an actor.
            </p>
            <div className="bg-gray-900 rounded-lg p-4 mb-4">
              <div className="text-sm font-mono text-gray-300 mb-2">POST /api/tuples</div>
              <pre className="text-sm text-gray-300 overflow-x-auto">
{`curl -X POST http://localhost:3000/api/tuples \\
  -H "Content-Type: application/json" \\
  -H "X-Service-Id: dev" \\
  -H "X-Tenant: default" \\
  -d '{
    "subject": "document",
    "id": "1",
    "relation": "owner",
    "actor": "user",
    "actor_id": "alice"
  }'`}
              </pre>
            </div>
          </section>

          {/* Batch Operations */}
          <section className="mb-12">
            <h2 className="text-xl font-semibold text-gray-900 mb-4">Batch Operations</h2>
            <p className="text-gray-600 mb-4">
              Create or delete multiple relationships in a single request.
            </p>
            <div className="bg-gray-900 rounded-lg p-4 mb-4">
              <div className="text-sm font-mono text-gray-300 mb-2">POST /api/tuples/batch</div>
              <pre className="text-sm text-gray-300 overflow-x-auto">
{`curl -X POST http://localhost:3000/api/tuples/batch \\
  -H "Content-Type: application/json" \\
  -H "X-Service-Id: dev" \\
  -H "X-Tenant: default" \\
  -d '{
    "tuples": [
      {
        "subject": "document",
        "id": "1",
        "relation": "viewer",
        "actor": "user",
        "actor_id": "bob"
      },
      {
        "subject": "document",
        "id": "2",
        "relation": "editor",
        "actor": "user",
        "actor_id": "alice"
      }
    ]
  }'`}
              </pre>
            </div>
          </section>

          {/* Actor Permissions */}
          <section className="mb-12">
            <h2 className="text-xl font-semibold text-gray-900 mb-4">Actor Permissions</h2>
            <p className="text-gray-600 mb-4">
              Get all permissions for a specific actor across all resources.
            </p>
            <div className="bg-gray-900 rounded-lg p-4 mb-4">
              <div className="text-sm font-mono text-gray-300 mb-2">GET /api/actors/:actor_type/:actor_id/permissions</div>
              <pre className="text-sm text-gray-300 overflow-x-auto">
{`curl -X GET http://localhost:3000/api/actors/user/alice/permissions \\
  -H "X-Service-Id: dev" \\
  -H "X-Tenant: default"`}
              </pre>
            </div>
          </section>

          {/* SDKs */}
          <section className="mb-12">
            <h2 className="text-xl font-semibold text-gray-900 mb-4">SDKs</h2>
            <p className="text-gray-600 mb-4">
              Official SDKs are available for multiple languages:
            </p>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="border border-gray-200 rounded-lg p-4">
                <h3 className="font-semibold text-gray-900 mb-2">TypeScript/JavaScript</h3>
                <code className="text-sm text-gray-600">npm install @rebar/sdk</code>
              </div>
              <div className="border border-gray-200 rounded-lg p-4">
                <h3 className="font-semibold text-gray-900 mb-2">Ruby</h3>
                <code className="text-sm text-gray-600">gem install rebar-sdk</code>
              </div>
              <div className="border border-gray-200 rounded-lg p-4">
                <h3 className="font-semibold text-gray-900 mb-2">Python</h3>
                <code className="text-sm text-gray-600">pip install rebar-sdk</code>
              </div>
              <div className="border border-gray-200 rounded-lg p-4">
                <h3 className="font-semibold text-gray-900 mb-2">Go</h3>
                <code className="text-sm text-gray-600">go get github.com/getangry/rebar-go</code>
              </div>
            </div>
          </section>
        </div>
      )}

      {activeTab === 'openapi' && (
        <div>
          <div className="mb-6 flex items-center justify-between">
            <p className="text-gray-600">
              Interactive API explorer with complete endpoint documentation and request/response schemas.
            </p>
            <a
              href="/api/openapi/index.html"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
            >
              Open in New Tab
              <svg className="ml-2 h-4 w-4" fill="none" viewBox="0 0 24 24" strokeWidth="1.5" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25" />
              </svg>
            </a>
          </div>
          <div className="border border-gray-200 rounded-lg overflow-hidden" style={{ height: 'calc(100vh - 280px)' }}>
            <iframe
              src="/api/openapi/index.html"
              className="w-full h-full"
              title="OpenAPI Documentation"
            />
          </div>
        </div>
      )}
    </div>
  );
}
