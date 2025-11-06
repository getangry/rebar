# Audit Logs UI

A comprehensive audit log viewer built with React and TypeScript for monitoring all relationship tuple changes in Rebar.

## Features

### 📊 Statistics Dashboard
- **Total Events**: Shows the count of all audit log entries
- **Action Breakdown**: Visual breakdown of create, delete, and update operations
- **Service Statistics**: Distribution of events by service ID
- **Collapsible**: Can be hidden to save screen space

### 🔍 Advanced Filtering
Filter audit logs by:
- **Action Type**: Create, Delete, or Update
- **Service ID**: Which service performed the action
- **Subject**: Resource type (e.g., doc, folder, group)
- **Actor**: Entity performing the action (e.g., user, group)
- **Actor ID**: Specific entity identifier (e.g., alice, bob)
- **Date Range**: Filter by timestamp (since a specific date/time)

### 📋 Data Table
- **Sortable Columns**: Click column headers to sort
- **Responsive Design**: Adapts to different screen sizes
- **Color-Coded Actions**: Visual distinction between create (green), delete (red), and update (yellow)
- **Hover Effects**: Row highlighting for better readability
- **Truncated Reasons**: Long reasons are truncated with ellipsis (hover to see full text)

### 📄 Pagination
- **Configurable Page Size**: Default 50 items per page (max 1000)
- **Previous/Next Navigation**: Simple page navigation
- **Page Counter**: Shows current page and result count
- **Disabled State**: Previous/Next buttons disable at boundaries

### 🔬 Detail View Modal
Click "View Details" on any log entry to see:
- **Complete Metadata**: All fields including IP address, user agent
- **Full Tuple Data**: Complete relationship information
- **Before/After States**: State changes (for deletes/updates)
- **Reason**: Full text of the reason field
- **Summary**: Human-readable summary of the action
- **Color-Coded Displays**: Different colors for before (yellow) and after (green) states

### 🎨 UI/UX Features
- **Modern Design**: Clean, professional interface with gradients and shadows
- **Loading States**: Visual feedback during API calls
- **Error Handling**: Clear error messages when something goes wrong
- **Empty States**: Helpful message when no logs are found
- **Monospace Fonts**: For resource IDs and technical data
- **Icon System**: Visual icons for different action types

## Usage

### Starting the Application

```bash
# From the web directory
npm install
npm run dev
```

The application will be available at `http://localhost:5173` (or the port specified by Vite).

### Navigation

The app has two main tabs:
1. **🎮 Demo**: Interactive demo of the Rebar API
2. **🔍 Audit Logs**: Audit log viewer (this feature)

### Filtering Logs

1. Fill in any combination of filter fields
2. Click "Apply Filters" to search
3. Click "Clear" to reset all filters
4. Results update automatically

### Viewing Details

1. Click "View Details" button on any log entry
2. Modal opens with complete information
3. Click "Close" or click outside the modal to dismiss

### Pagination

- Use "Previous" and "Next" buttons to navigate pages
- Page information shows current page and result count
- Buttons are disabled when at the first or last page

## API Integration

The UI connects to these Rebar API endpoints:

- `GET /api/audit_logs` - List logs with filters
- `GET /api/audit_logs/:id` - Get specific log
- `GET /api/audit_logs/stats` - Get statistics

All requests include:
- `X-Service-Id` header (default: "dev")
- `X-Tenant` header (default: "default")

## Component Structure

```
web/src/
├── api/
│   └── rebar.ts          # API client with audit log methods
├── components/
│   ├── AuditLogs.tsx     # Main audit log viewer component
│   └── RebarDemo.tsx     # Demo component
└── App.tsx               # Main app with navigation
```

## TypeScript Interfaces

```typescript
interface AuditLog {
  id: number;
  tenant_id: string;
  service_id: string;
  actor_user_id?: string;
  ip_address?: string;
  action: string;
  resource_type: string;
  tuple: AuditLogTuple;
  before_state?: any;
  after_state?: any;
  reason?: string;
  metadata?: any;
  created_at: string;
  summary: string;
}

interface AuditLogFilters {
  service_id?: string;
  action?: string;
  subject?: string;
  object_id?: string;
  actor?: string;
  actor_id?: string;
  since?: string;
  page?: number;
  per_page?: number;
}
```

## Customization

### Colors
Action colors are defined in the `getActionColor` function:
- Create: `#28a745` (green)
- Delete: `#dc3545` (red)
- Update: `#ffc107` (yellow)
- Default: `#6c757d` (gray)

### Icons
Action icons are defined in the `getActionIcon` function:
- Create: ➕
- Delete: 🗑️
- Update: ✏️
- Default: 📝

### Page Size
Default page size is 50, maximum is 1000. Change in the component:
```typescript
const [perPage, setPerPage] = useState(50);
```

## Best Practices

1. **Use Filters**: Don't load all logs at once - use filters to narrow results
2. **Date Range**: Use the "Since" filter for recent activity
3. **Service ID**: Filter by service for debugging specific services
4. **Actor Tracking**: Use actor filters to audit specific user activity
5. **Regular Monitoring**: Check audit logs regularly for security and compliance

## Troubleshooting

### No Logs Showing
- Check that the backend server is running
- Verify database has been migrated (includes audit_logs table)
- Check browser console for API errors
- Try clearing filters

### Filters Not Working
- Make sure to click "Apply Filters" after changing values
- Check that the filter values match actual data in the database
- Try resetting with "Clear" and starting fresh

### Performance Issues
- Use date range filters to limit results
- Increase page size if you need more results per page
- Consider archiving old logs in production

## Security Considerations

- Audit logs may contain sensitive information
- In production, implement proper access controls
- Consider who should have access to audit logs
- Be aware of IP addresses and user tracking for privacy compliance

## Future Enhancements

Potential improvements:
- Export logs to CSV/JSON
- Advanced search with regex
- Real-time updates (WebSockets)
- Graphical timeline view
- Bulk operations
- Custom date range picker
- Saved filter presets
- Email alerts for specific events
