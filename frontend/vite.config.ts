import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import * as path from "node:path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      'react-icons': path.resolve(__dirname, 'node_modules/react-icons')
    }
  }
})
