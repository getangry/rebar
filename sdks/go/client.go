// Package rebar provides a Go SDK for Rebar ReBAC authorization service.
//
// Example usage:
//
//	client := rebar.NewClient(rebar.Config{
//		BaseURL:   "http://localhost:3000",
//		ServiceID: "my-app",
//		Tenant:    "default",
//	})
//
//	allowed, err := client.Check(ctx, rebar.CheckRequest{
//		Actor:      "user",
//		ActorID:    "alice",
//		Permission: "can_edit",
//		Subject:    "doc",
//		SubjectID:  "doc-123",
//	})
package rebar

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

// Config holds the configuration for the Rebar client
type Config struct {
	BaseURL   string
	ServiceID string
	Tenant    string
	Timeout   time.Duration
	HTTPClient *http.Client
}

// Client is the Rebar API client
type Client struct {
	baseURL    string
	serviceID  string
	tenant     string
	httpClient *http.Client
}

// CheckRequest represents a permission check request
type CheckRequest struct {
	Actor      string `json:"actor"`
	ActorID    string `json:"actor_id"`
	Permission string `json:"permission"`
	Subject    string `json:"subject"`
	SubjectID  string `json:"subject_id"`
}

// CheckResponse represents a permission check response
type CheckResponse struct {
	Allow bool `json:"allow"`
}

// ExplainResponse represents an explanation response
type ExplainResponse struct {
	Allow bool          `json:"allow"`
	Path  []interface{} `json:"path,omitempty"`
}

// RelTuple represents a relationship tuple
type RelTuple struct {
	Subject  string  `json:"subject"`
	ID       string  `json:"id"`
	Relation string  `json:"relation"`
	Actor    string  `json:"actor"`
	ActorID  string  `json:"actor_id"`
	ActorRel *string `json:"actor_rel,omitempty"`
}

// Permission represents a permission
type Permission struct {
	Permission string  `json:"permission"`
	Type       string  `json:"type"` // "direct", "group", "inherited"
	Via        *string `json:"via,omitempty"`
}

// ResourcePermissions represents permissions for a resource
type ResourcePermissions struct {
	Resource     string       `json:"resource"`
	ResourceType string       `json:"resource_type"`
	ResourceID   string       `json:"resource_id"`
	Permissions  []Permission `json:"permissions"`
	Actions      []string     `json:"actions"`
}

// ActorPermissionsResponse represents actor permissions
type ActorPermissionsResponse struct {
	Actor            string                `json:"actor"`
	TotalPermissions int                   `json:"total_permissions"`
	DirectCount      int                   `json:"direct_count"`
	GroupCount       int                   `json:"group_count"`
	InheritedCount   int                   `json:"inherited_count"`
	GroupMemberships []string              `json:"group_memberships"`
	Resources        []ResourcePermissions `json:"resources"`
}

// GroupMembership represents a group membership
type GroupMembership struct {
	Group   string `json:"group"`
	GroupID string `json:"group_id"`
	Role    string `json:"role"`
}

// ActorGroupsResponse represents actor group memberships
type ActorGroupsResponse struct {
	Actor       string            `json:"actor"`
	Memberships []GroupMembership `json:"memberships"`
}

// AuditLog represents an audit log entry
type AuditLog struct {
	ID          int     `json:"id"`
	TenantID    string  `json:"tenant_id"`
	Action      string  `json:"action"`
	Subject     string  `json:"subject"`
	SubjectID   string  `json:"subject_id"`
	Relation    string  `json:"relation"`
	Actor       string  `json:"actor"`
	ActorID     string  `json:"actor_id"`
	ActorRel    *string `json:"actor_rel,omitempty"`
	Reason      *string `json:"reason,omitempty"`
	PerformedBy *string `json:"performed_by,omitempty"`
	CreatedAt   string  `json:"created_at"`
}

// AuditLogsResponse represents paginated audit logs
type AuditLogsResponse struct {
	Logs    []AuditLog `json:"logs"`
	Total   int        `json:"total"`
	Page    int        `json:"page"`
	PerPage int        `json:"per_page"`
}

// Error types
type Error struct {
	StatusCode int
	Message    string
}

func (e *Error) Error() string {
	return fmt.Sprintf("rebar: HTTP %d: %s", e.StatusCode, e.Message)
}

// NewClient creates a new Rebar client
func NewClient(config Config) *Client {
	httpClient := config.HTTPClient
	if httpClient == nil {
		timeout := config.Timeout
		if timeout == 0 {
			timeout = 10 * time.Second
		}
		httpClient = &http.Client{Timeout: timeout}
	}

	tenant := config.Tenant
	if tenant == "" {
		tenant = "default"
	}

	return &Client{
		baseURL:    config.BaseURL,
		serviceID:  config.ServiceID,
		tenant:     tenant,
		httpClient: httpClient,
	}
}

// Check checks if an actor has a specific permission on a subject
func (c *Client) Check(ctx context.Context, req CheckRequest) (bool, error) {
	var resp CheckResponse
	err := c.post(ctx, "/api/auth/check", req, &resp)
	if err != nil {
		return false, err
	}
	return resp.Allow, nil
}

// Explain checks permission and returns explanation path
func (c *Client) Explain(ctx context.Context, req CheckRequest) (*ExplainResponse, error) {
	var resp ExplainResponse
	err := c.post(ctx, "/api/auth/explain", req, &resp)
	if err != nil {
		return nil, err
	}
	return &resp, nil
}

// CreateTuple creates a relationship tuple
func (c *Client) CreateTuple(ctx context.Context, tuple RelTuple) error {
	return c.post(ctx, "/api/tuples", tuple, nil)
}

// DeleteTuple deletes a relationship tuple
func (c *Client) DeleteTuple(ctx context.Context, tuple RelTuple) error {
	return c.delete(ctx, "/api/tuples", tuple)
}

// BatchCreateTuples creates multiple relationship tuples
func (c *Client) BatchCreateTuples(ctx context.Context, tuples []RelTuple) error {
	payload := map[string]interface{}{"tuples": tuples}
	return c.post(ctx, "/api/tuples/batch", payload, nil)
}

// BatchDeleteTuples deletes multiple relationship tuples
func (c *Client) BatchDeleteTuples(ctx context.Context, tuples []RelTuple) error {
	payload := map[string]interface{}{"tuples": tuples}
	return c.delete(ctx, "/api/tuples/batch", payload)
}

// ActorPermissions gets all permissions for an actor
func (c *Client) ActorPermissions(ctx context.Context, actorType, actorID string) (*ActorPermissionsResponse, error) {
	var resp ActorPermissionsResponse
	path := fmt.Sprintf("/api/actors/%s/%s/permissions", actorType, actorID)
	err := c.get(ctx, path, nil, &resp)
	if err != nil {
		return nil, err
	}
	return &resp, nil
}

// ActorGroups gets all groups an actor is a member of
func (c *Client) ActorGroups(ctx context.Context, actorType, actorID string) (*ActorGroupsResponse, error) {
	var resp ActorGroupsResponse
	path := fmt.Sprintf("/api/actors/%s/%s/groups", actorType, actorID)
	err := c.get(ctx, path, nil, &resp)
	if err != nil {
		return nil, err
	}
	return &resp, nil
}

// AuditLogsParams holds parameters for querying audit logs
type AuditLogsParams struct {
	Page    int
	PerPage int
	Subject string
	Actor   string
	Action  string
}

// AuditLogs gets audit logs with optional filtering
func (c *Client) AuditLogs(ctx context.Context, params AuditLogsParams) (*AuditLogsResponse, error) {
	query := url.Values{}
	if params.Page > 0 {
		query.Set("page", fmt.Sprintf("%d", params.Page))
	}
	if params.PerPage > 0 {
		query.Set("per_page", fmt.Sprintf("%d", params.PerPage))
	}
	if params.Subject != "" {
		query.Set("subject", params.Subject)
	}
	if params.Actor != "" {
		query.Set("actor", params.Actor)
	}
	if params.Action != "" {
		query.Set("action", params.Action)
	}

	var resp AuditLogsResponse
	err := c.get(ctx, "/api/audit_logs", query, &resp)
	if err != nil {
		return nil, err
	}
	return &resp, nil
}

// Schema gets schema information
func (c *Client) Schema(ctx context.Context) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.get(ctx, "/api/schema", nil, &resp)
	if err != nil {
		return nil, err
	}
	return resp, nil
}

// SetTenant changes the tenant for subsequent requests
func (c *Client) SetTenant(tenant string) {
	c.tenant = tenant
}

// Internal methods

func (c *Client) get(ctx context.Context, path string, query url.Values, result interface{}) error {
	urlStr := c.baseURL + path
	if query != nil && len(query) > 0 {
		urlStr += "?" + query.Encode()
	}

	req, err := http.NewRequestWithContext(ctx, "GET", urlStr, nil)
	if err != nil {
		return err
	}

	return c.doRequest(req, result)
}

func (c *Client) post(ctx context.Context, path string, body interface{}, result interface{}) error {
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+path, bytes.NewBuffer(jsonBody))
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")
	return c.doRequest(req, result)
}

func (c *Client) delete(ctx context.Context, path string, body interface{}) error {
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, "DELETE", c.baseURL+path, bytes.NewBuffer(jsonBody))
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")
	return c.doRequest(req, nil)
}

func (c *Client) doRequest(req *http.Request, result interface{}) error {
	req.Header.Set("X-Service-Id", c.serviceID)
	req.Header.Set("X-Tenant", c.tenant)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		var errResp struct {
			Error   string `json:"error"`
			Message string `json:"message"`
		}
		json.Unmarshal(bodyBytes, &errResp)

		msg := errResp.Error
		if msg == "" {
			msg = errResp.Message
		}
		if msg == "" {
			msg = resp.Status
		}

		return &Error{
			StatusCode: resp.StatusCode,
			Message:    msg,
		}
	}

	if result != nil {
		return json.NewDecoder(resp.Body).Decode(result)
	}

	return nil
}
