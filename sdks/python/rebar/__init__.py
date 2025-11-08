"""
Rebar ReBAC SDK for Python

Example usage:
    from rebar import RebarClient

    client = RebarClient(
        base_url='http://localhost:3000',
        service_id='my-app',
        tenant='default'
    )

    # Check permission
    allowed = client.check(
        actor='user',
        actor_id='alice',
        permission='can_edit',
        subject='doc',
        subject_id='doc-123'
    )

    # Get actor permissions
    permissions = client.actor_permissions('user', 'alice')
"""

from .client import RebarClient, RebarError, APIError, UnauthorizedError, ForbiddenError, NotFoundError

__version__ = "0.1.0"
__all__ = [
    "RebarClient",
    "RebarError",
    "APIError",
    "UnauthorizedError",
    "ForbiddenError",
    "NotFoundError",
]
