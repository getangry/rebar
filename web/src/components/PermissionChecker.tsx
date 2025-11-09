import { useState } from 'react';
import { rebarClient } from '../api/rebar';
import Button from './ui/button';
import Badge from './ui/badge';
import { Alert, AlertDescription } from './ui/alert';

interface TraceStep {
  check: string;
  result: boolean;
  details: string;
  policy?: string;
}

interface ExplainResult {
  allow: boolean;
  reason?: string;
  trace?: TraceStep[];
}

export default function PermissionChecker() {
  const [actor, setActor] = useState('user:alice');
  const [permission, setPermission] = useState('viewer');
  const [subject, setSubject] = useState('document:123');
  const [context, setContext] = useState('{}');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<ExplainResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleCheck = async () => {
    setLoading(true);
    setError(null);
    setResult(null);

    try {
      // Parse actor and subject
      const [actorType, actorId] = actor.split(':');
      const [subjectType, subjectId] = subject.split(':');

      // Parse context
      let parsedContext = {};
      try {
        parsedContext = context.trim() ? JSON.parse(context) : {};
      } catch (e) {
        setError('Invalid JSON in context field');
        return;
      }

      // Call explain endpoint for detailed trace
      const explainResult = await rebarClient.explainPermission({
        actor: actorType,
        actor_id: actorId,
        permission,
        subject: subjectType,
        subject_id: subjectId,
        context: parsedContext,
      });

      setResult(explainResult as ExplainResult);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to check permission');
    } finally {
      setLoading(false);
    }
  };

  const getStepIcon = (result: boolean) => {
    return result ? '✓' : '✗';
  };

  const getStepColor = (result: boolean) => {
    return result ? 'text-green-600' : 'text-red-600';
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8">
      <div className="mb-8">
        <h1 className="text-2xl font-semibold text-gray-900">Permission Checker</h1>
        <p className="mt-2 text-sm text-gray-600">
          Test permission checks with context and see detailed evaluation trace
        </p>
      </div>

      {/* Input Form */}
      <div className="bg-white rounded-lg border border-gray-200 p-6 mb-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Test Permission</h2>

        <div className="space-y-4">
          {/* Actor */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Actor
              <span className="text-gray-500 text-xs ml-2">(format: type:id)</span>
            </label>
            <input
              type="text"
              value={actor}
              onChange={(e) => setActor(e.target.value)}
              placeholder="user:alice"
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Permission */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Permission
            </label>
            <input
              type="text"
              value={permission}
              onChange={(e) => setPermission(e.target.value)}
              placeholder="viewer"
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Subject */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Subject
              <span className="text-gray-500 text-xs ml-2">(format: type:id)</span>
            </label>
            <input
              type="text"
              value={subject}
              onChange={(e) => setSubject(e.target.value)}
              placeholder="document:123"
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Context */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Context (JSON)
              <span className="text-gray-500 text-xs ml-2">(optional)</span>
            </label>
            <textarea
              value={context}
              onChange={(e) => setContext(e.target.value)}
              placeholder={`{
  "mfa_verified": true,
  "ip_address": "10.0.1.50",
  "geo_region": "us-east-1"
}`}
              rows={6}
              className="w-full px-3 py-2 border border-gray-300 rounded-md font-mono text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Quick Context Templates */}
          <div className="flex gap-2 flex-wrap">
            <span className="text-xs text-gray-600 mr-2">Quick add:</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setContext('{"mfa_verified": true}')}
            >
              MFA Verified
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setContext('{"ip_address": "10.0.1.50"}')}
            >
              Internal IP
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setContext('{"mfa_verified": true, "ip_address": "10.0.1.50"}')}
            >
              MFA + IP
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setContext('{}')}
            >
              Clear
            </Button>
          </div>

          {/* Submit */}
          <div className="pt-2">
            <Button
              onClick={handleCheck}
              disabled={loading}
              className="w-full"
            >
              {loading ? 'Checking...' : 'Check Permission'}
            </Button>
          </div>
        </div>
      </div>

      {/* Error */}
      {error && (
        <Alert variant="destructive" className="mb-6">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Result */}
      {result && (
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <div className="mb-4">
            <h2 className="text-lg font-semibold text-gray-900 mb-2">Result</h2>
            <div className="flex items-center gap-3">
              {result.allow ? (
                <Badge variant="default" className="bg-green-600">
                  ✓ ALLOW
                </Badge>
              ) : (
                <Badge variant="destructive">
                  ✗ DENY
                </Badge>
              )}
              {result.reason && (
                <span className="text-sm text-gray-600">{result.reason}</span>
              )}
            </div>
          </div>

          {/* Evaluation Trace */}
          {result.trace && result.trace.length > 0 && (
            <div>
              <h3 className="text-md font-semibold text-gray-900 mb-3">Evaluation Trace</h3>
              <div className="space-y-3">
                {result.trace.map((step, idx) => (
                  <div
                    key={idx}
                    className={`border-l-4 pl-4 py-2 ${
                      step.result ? 'border-green-500 bg-green-50' : 'border-red-500 bg-red-50'
                    }`}
                  >
                    <div className="flex items-start gap-2">
                      <span className={`font-semibold ${getStepColor(step.result)}`}>
                        {getStepIcon(step.result)}
                      </span>
                      <div className="flex-1">
                        <div className="font-medium text-gray-900">
                          {step.check.replace(/_/g, ' ').replace(/\b\w/g, (l) => l.toUpperCase())}
                        </div>
                        <div className="text-sm text-gray-700 mt-1">{step.details}</div>
                        {step.policy && (
                          <div className="mt-2 bg-white/50 border border-gray-300 rounded px-3 py-2">
                            <div className="text-xs font-mono text-gray-600">{step.policy}</div>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* No Trace Available */}
          {!result.trace && !result.allow && (
            <div className="mt-4">
              <Alert>
                <AlertDescription>
                  No relationship found. Create a tuple to grant access.
                </AlertDescription>
              </Alert>
            </div>
          )}

          {/* Old-style path (backward compatibility) */}
          {!result.trace && result.allow && (result as any).path && (
            <div className="mt-4">
              <h3 className="text-md font-semibold text-gray-900 mb-2">Permission Path</h3>
              <div className="bg-gray-50 rounded p-3">
                <code className="text-sm text-gray-700">
                  {JSON.stringify((result as any).path, null, 2)}
                </code>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
