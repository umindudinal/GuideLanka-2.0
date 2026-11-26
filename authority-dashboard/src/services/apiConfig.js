export const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL || 
  (import.meta.env.DEV ? 'http://localhost:5000' : 'https://guidelanka-20-backend.vercel.app')
).replace(/\/$/, '');
