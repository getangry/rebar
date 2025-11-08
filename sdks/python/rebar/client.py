import requests
from typing import Optional, Dict, List, Any
from dataclasses import dataclass


class RebarError(Exception):
    """Base exception for Rebar SDK"""
    pass


class APIError(RebarError):
    """Generic API error"""
    pass


class UnauthorizedError(APIError):
    """401 Unauthorized"""
    pass


class ForbiddenError(APIError):
    """403 Forbidden"""
    pass


class NotFoundError(APIError):
    """404 Not Found"""
    pass


@dataclass
class CheckRequest:
    """Request to check a permission"""
    actor: str
    actor_id: str
    permission: str
    subject: str
    subject_id: str


@dataclass
class RelTuple:
    """Relationship tuple"""
    subject: str
    id: str
    relation: str
    actor: str
    actor_id: str
    actor_rel: Optional[str] = None


class RebarClient:
    """
    Client for interacting with Rebar ReBAC authorization API.

    Args:
        base_url: Base URL of the Rebar API
        service_id: Your service identifier
        tenant: Tenant ID (default: "default")
        timeout: Request timeout in seconds (default: 10)

    Example:
        >>> client = RebarClient(
        ...     base_url='http://localhost:3000',
        ...     service_id='my-app',
        ...     tenant='default'
        ... )
        >>> allowed = client.check(
        ...     actor='user',
        ...     actor_id='alice',
        ...     permission='can_edit',
        ...     subject='doc',
        ...     subject_id='doc-123'
        ... )
    """

    def __init__(
        self,
        base_url: str,
        service_id: str,
        tenant: str = "default",
        timeout: int = 10
    ):
        self.base_url = base_url.rstrip('/')
        self.service_id = service_id
        self.tenant = tenant
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'X-Service-Id': service_id,
            'X-Tenant': tenant
        })

    def check(
        self,
        actor: str,
        actor_id: str,
        permission: str,
        subject: str,
        subject_id: str
    ) -> bool:
        """
        Check if an actor has a specific permission on a subject.

        Args:
            actor: Actor type (e.g., "user")
            actor_id: Actor identifier
            permission: Permission to check
            subject: Subject type (e.g., "doc")
            subject_id: Subject identifier

        Returns:
            True if allowed, False otherwise

        Raises:
            APIError: If the API returns an error
        """
        response = self._post('/api/auth/check', {
            'actor': actor,
            'actor_id': actor_id,
            'permission': permission,
            'subject': subject,
            'subject_id': subject_id
        })
        return response.get('allow', False)

    def explain(
        self,
        actor: str,
        actor_id: str,
        permission: str,
        subject: str,
        subject_id: str
    ) -> Dict[str, Any]:
        """
        Check permission and get explanation path.

        Returns:
            Dict with 'allow' and optional 'path' keys
        """
        return self._post('/api/auth/explain', {
            'actor': actor,
            'actor_id': actor_id,
            'permission': permission,
            'subject': subject,
            'subject_id': subject_id
        })

    def create_tuple(
        self,
        subject: str,
        id: str,
        relation: str,
        actor: str,
        actor_id: str,
        actor_rel: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Create a relationship tuple.

        Args:
            subject: Subject type
            id: Subject identifier
            relation: Relation name
            actor: Actor type
            actor_id: Actor identifier
            actor_rel: Optional actor relation

        Example:
            >>> client.create_tuple(
            ...     subject='doc',
            ...     id='doc-123',
            ...     relation='editor',
            ...     actor='user',
            ...     actor_id='alice'
            ... )
        """
        return self._post('/api/tuples', {
            'subject': subject,
            'id': id,
            'relation': relation,
            'actor': actor,
            'actor_id': actor_id,
            'actor_rel': actor_rel
        })

    def delete_tuple(
        self,
        subject: str,
        id: str,
        relation: str,
        actor: str,
        actor_id: str,
        actor_rel: Optional[str] = None
    ) -> Dict[str, Any]:
        """Delete a relationship tuple."""
        return self._delete('/api/tuples', {
            'subject': subject,
            'id': id,
            'relation': relation,
            'actor': actor,
            'actor_id': actor_id,
            'actor_rel': actor_rel
        })

    def batch_create_tuples(self, tuples: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Batch create relationship tuples.

        Args:
            tuples: List of tuple dictionaries

        Example:
            >>> client.batch_create_tuples([
            ...     {'subject': 'doc', 'id': 'doc-1', 'relation': 'viewer',
            ...      'actor': 'user', 'actor_id': 'alice'},
            ...     {'subject': 'doc', 'id': 'doc-2', 'relation': 'editor',
            ...      'actor': 'user', 'actor_id': 'bob'}
            ... ])
        """
        return self._post('/api/tuples/batch', {'tuples': tuples})

    def batch_delete_tuples(self, tuples: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Batch delete relationship tuples."""
        return self._delete('/api/tuples/batch', {'tuples': tuples})

    def actor_permissions(self, actor_type: str, actor_id: str) -> Dict[str, Any]:
        """
        Get all permissions for an actor.

        Args:
            actor_type: Actor type (e.g., "user")
            actor_id: Actor identifier

        Returns:
            Dict with permissions, resources, and actions

        Example:
            >>> permissions = client.actor_permissions('user', 'alice')
            >>> print(f"Total: {permissions['total_permissions']}")
            >>> for resource in permissions['resources']:
            ...     print(f"{resource['resource']}: {resource['actions']}")
        """
        return self._get(f'/api/actors/{actor_type}/{actor_id}/permissions')

    def actor_groups(self, actor_type: str, actor_id: str) -> Dict[str, Any]:
        """
        Get all groups an actor is a member of.

        Returns:
            Dict with group memberships
        """
        return self._get(f'/api/actors/{actor_type}/{actor_id}/groups')

    def audit_logs(
        self,
        page: int = 1,
        per_page: int = 50,
        subject: Optional[str] = None,
        actor: Optional[str] = None,
        action: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Get audit logs with optional filtering.

        Args:
            page: Page number
            per_page: Results per page
            subject: Filter by subject
            actor: Filter by actor
            action: Filter by action

        Returns:
            Dict with logs and pagination info
        """
        params = {'page': page, 'per_page': per_page}
        if subject:
            params['subject'] = subject
        if actor:
            params['actor'] = actor
        if action:
            params['action'] = action

        return self._get('/api/audit_logs', params=params)

    def schema(self) -> Dict[str, Any]:
        """Get schema information."""
        return self._get('/api/schema')

    def set_tenant(self, tenant: str) -> None:
        """Change tenant for subsequent requests."""
        self.tenant = tenant
        self.session.headers.update({'X-Tenant': tenant})

    def _get(self, path: str, params: Optional[Dict] = None) -> Dict[str, Any]:
        """Make GET request."""
        url = f'{self.base_url}{path}'
        response = self.session.get(url, params=params, timeout=self.timeout)
        return self._handle_response(response)

    def _post(self, path: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Make POST request."""
        url = f'{self.base_url}{path}'
        response = self.session.post(url, json=data, timeout=self.timeout)
        return self._handle_response(response)

    def _delete(self, path: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Make DELETE request."""
        url = f'{self.base_url}{path}'
        response = self.session.delete(url, json=data, timeout=self.timeout)
        return self._handle_response(response)

    def _handle_response(self, response: requests.Response) -> Dict[str, Any]:
        """Handle API response and raise appropriate errors."""
        if response.status_code == 401:
            raise UnauthorizedError(self._error_message(response))
        elif response.status_code == 403:
            raise ForbiddenError(self._error_message(response))
        elif response.status_code == 404:
            raise NotFoundError(self._error_message(response))
        elif not response.ok:
            raise APIError(self._error_message(response))

        return response.json()

    def _error_message(self, response: requests.Response) -> str:
        """Extract error message from response."""
        try:
            error_data = response.json()
            return error_data.get('error') or error_data.get('message') or 'Unknown error'
        except Exception:
            return f'HTTP {response.status_code}: {response.reason}'
