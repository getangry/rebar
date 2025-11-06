import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
    port: 8080,
    strictPort: true,
    watch: {
      usePolling: true, // Required for Docker on some systems
    },
    proxy: {
      // Proxy API calls to Rails backend
      "/api/tuples": {
        target: "http://api:3000",
        changeOrigin: true,
      },
      "/api/auth": {
        target: "http://api:3000",
        changeOrigin: true,
      },
      "/api/audit_logs": {
        target: "http://api:3000",
        changeOrigin: true,
      },
      "/api/up": {
        target: "http://api:3000",
        changeOrigin: true,
      },
    },
  },
});
