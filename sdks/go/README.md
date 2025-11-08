# Rebar SDK - Go

Official Go SDK for Rebar ReBAC authorization service.

## Installation

```bash
go get github.com/getangry/rebar/sdk/go
```

## Usage

### Basic Setup

```go
package main

import (
	"context"
	"fmt"
	"log"

	rebar "github.com/getangry/rebar/sdk/go"
)

func main() {
	client := rebar.NewClient(rebar.Config{
		BaseURL:   "http://localhost:3000",
		ServiceID: "my-app",
		Tenant:    "default",
	})

	ctx := context.Background()

	// Check permission
	allowed, err := client.Check(ctx, rebar.CheckRequest{
		Actor:      "user",
		ActorID:    "alice",
		Permission: "can_edit",
		Subject:    "doc",
		SubjectID:  "doc-123",
	})
	if err != nil {
		log.Fatal(err)
	}

	if allowed {
		fmt.Println("Alice can edit doc-123")
	}
}
```

### Check Permissions

```go
allowed, err := client.Check(ctx, rebar.CheckRequest{
	Actor:      "user",
	ActorID:    "alice",
	Permission: "can_edit",
	Subject:    "doc",
	SubjectID:  "doc-123",
})
if err != nil {
	log.Fatal(err)
}

if allowed {
	fmt.Println("Permission granted")
}
```

### Get Explanation

```go
result, err := client.Explain(ctx, rebar.CheckRequest{
	Actor:      "user",
	ActorID:    "alice",
	Permission: "viewer",
	Subject:    "document",
	SubjectID:  "doc-123",
})
if err != nil {
	log.Fatal(err)
}

fmt.Printf("Allowed: %v\n", result.Allow)
fmt.Printf("Path: %v\n", result.Path)
```

### Manage Relationships

```go
// Grant permission
err := client.CreateTuple(ctx, rebar.RelTuple{
	Subject:  "doc",
	ID:       "doc-123",
	Relation: "editor",
	Actor:    "user",
	ActorID:  "alice",
})
if err != nil {
	log.Fatal(err)
}

// Revoke permission
err = client.DeleteTuple(ctx, rebar.RelTuple{
	Subject:  "doc",
	ID:       "doc-123",
	Relation: "editor",
	Actor:    "user",
	ActorID:  "alice",
})
if err != nil {
	log.Fatal(err)
}

// Batch create
tuples := []rebar.RelTuple{
	{Subject: "doc", ID: "doc-1", Relation: "viewer", Actor: "user", ActorID: "alice"},
	{Subject: "doc", ID: "doc-2", Relation: "editor", Actor: "user", ActorID: "bob"},
}
err = client.BatchCreateTuples(ctx, tuples)
if err != nil {
	log.Fatal(err)
}
```

### Get Actor Permissions

```go
permissions, err := client.ActorPermissions(ctx, "user", "alice")
if err != nil {
	log.Fatal(err)
}

fmt.Printf("Total permissions: %d\n", permissions.TotalPermissions)
fmt.Printf("Direct: %d\n", permissions.DirectCount)
fmt.Printf("Group: %d\n", permissions.GroupCount)
fmt.Printf("Inherited: %d\n", permissions.InheritedCount)

for _, resource := range permissions.Resources {
	fmt.Printf("\n%s:\n", resource.Resource)
	fmt.Printf("  Actions: %v\n", resource.Actions)
}
```

### Get Group Memberships

```go
groups, err := client.ActorGroups(ctx, "user", "alice")
if err != nil {
	log.Fatal(err)
}

for _, membership := range groups.Memberships {
	fmt.Printf("%s as %s\n", membership.Group, membership.Role)
}
```

### Audit Logs

```go
logs, err := client.AuditLogs(ctx, rebar.AuditLogsParams{
	Page:    1,
	PerPage: 50,
	Subject: "doc:123",
	Action:  "create",
})
if err != nil {
	log.Fatal(err)
}

for _, log := range logs.Logs {
	fmt.Printf("%s: %s:%s by %s\n",
		log.Action, log.Subject, log.SubjectID, *log.PerformedBy)
}
```

### HTTP Server Integration

```go
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"

	rebar "github.com/getangry/rebar/sdk/go"
)

var rebarClient *rebar.Client

func init() {
	rebarClient = rebar.NewClient(rebar.Config{
		BaseURL:   os.Getenv("REBAR_URL"),
		ServiceID: "my-app",
		Tenant:    "default",
	})
}

func documentHandler(w http.ResponseWriter, r *http.Request) {
	docID := r.URL.Query().Get("id")
	userID := getUserIDFromRequest(r) // Your auth logic

	// Check permission
	allowed, err := rebarClient.Check(r.Context(), rebar.CheckRequest{
		Actor:      "user",
		ActorID:    userID,
		Permission: "can_view",
		Subject:    "doc",
		SubjectID:  docID,
	})
	if err != nil {
		http.Error(w, "Authorization check failed", http.StatusInternalServerError)
		return
	}

	if !allowed {
		http.Error(w, "Permission denied", http.StatusForbidden)
		return
	}

	// Serve document
	doc := getDocument(docID)
	json.NewEncoder(w).Encode(doc)
}

func main() {
	http.HandleFunc("/document", documentHandler)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
```

### Middleware

```go
package middleware

import (
	"context"
	"net/http"

	rebar "github.com/getangry/rebar/sdk/go"
)

type contextKey string

const rebarClientKey contextKey = "rebar-client"

func RebarMiddleware(client *rebar.Client) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := context.WithValue(r.Context(), rebarClientKey, client)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func GetRebarClient(ctx context.Context) *rebar.Client {
	return ctx.Value(rebarClientKey).(*rebar.Client)
}

// Authorization middleware
func RequirePermission(permission, subjectType string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			client := GetRebarClient(r.Context())
			userID := getUserIDFromContext(r.Context())
			subjectID := getSubjectIDFromRequest(r)

			allowed, err := client.Check(r.Context(), rebar.CheckRequest{
				Actor:      "user",
				ActorID:    userID,
				Permission: permission,
				Subject:    subjectType,
				SubjectID:  subjectID,
			})
			if err != nil {
				http.Error(w, "Authorization failed", http.StatusInternalServerError)
				return
			}

			if !allowed {
				http.Error(w, "Permission denied", http.StatusForbidden)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
```

### Multi-Tenant Support

```go
// Change tenant dynamically
client.SetTenant("tenant-123")

// All subsequent requests use the new tenant
allowed, err := client.Check(ctx, ...)
```

### Error Handling

```go
import (
	rebar "github.com/getangry/rebar/sdk/go"
)

allowed, err := client.Check(ctx, rebar.CheckRequest{...})
if err != nil {
	if rebarErr, ok := err.(*rebar.Error); ok {
		switch rebarErr.StatusCode {
		case 401:
			log.Println("Authentication failed:", rebarErr.Message)
		case 403:
			log.Println("Access denied:", rebarErr.Message)
		case 404:
			log.Println("Resource not found:", rebarErr.Message)
		default:
			log.Printf("API error %d: %s", rebarErr.StatusCode, rebarErr.Message)
		}
	} else {
		log.Println("Request failed:", err)
	}
	return
}
```

### Custom HTTP Client

```go
import (
	"net/http"
	"time"

	rebar "github.com/getangry/rebar/sdk/go"
)

httpClient := &http.Client{
	Timeout: 30 * time.Second,
	Transport: &http.Transport{
		MaxIdleConns:        100,
		MaxIdleConnsPerHost: 10,
	},
}

client := rebar.NewClient(rebar.Config{
	BaseURL:    "http://localhost:3000",
	ServiceID:  "my-app",
	Tenant:     "default",
	HTTPClient: httpClient,
})
```

## API Reference

### `NewClient(config Config) *Client`

Creates a new Rebar client.

**Config fields:**
- `BaseURL` (string): Base URL of Rebar API
- `ServiceID` (string): Your service identifier
- `Tenant` (string): Tenant ID (default: "default")
- `Timeout` (time.Duration): Request timeout (default: 10s)
- `HTTPClient` (*http.Client): Custom HTTP client (optional)

### Methods

- `Check(ctx, CheckRequest) (bool, error)`
- `Explain(ctx, CheckRequest) (*ExplainResponse, error)`
- `CreateTuple(ctx, RelTuple) error`
- `DeleteTuple(ctx, RelTuple) error`
- `BatchCreateTuples(ctx, []RelTuple) error`
- `BatchDeleteTuples(ctx, []RelTuple) error`
- `ActorPermissions(ctx, actorType, actorID) (*ActorPermissionsResponse, error)`
- `ActorGroups(ctx, actorType, actorID) (*ActorGroupsResponse, error)`
- `AuditLogs(ctx, AuditLogsParams) (*AuditLogsResponse, error)`
- `Schema(ctx) (map[string]interface{}, error)`
- `SetTenant(tenant string)`

## Development

```bash
go test ./...
go fmt ./...
go vet ./...
```

## License

MIT
