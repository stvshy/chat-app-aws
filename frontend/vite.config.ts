import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import * as path from "node:path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      'react-icons': path.resolve(__dirname, 'node_modules/react-icons')
    }
  },
  server: {
    allowedHosts: [
      'projektchmury-frontend.us-east-1.elasticbeanstalk.com',
      'terraform-frontend-env-rp9w.eba-k6cte6nq.us-east-1.elasticbeanstalk.com'
    ]
  }
})
