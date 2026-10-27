import { Pool } from 'pg';

const connectionString = process.env.DATABASE_URL;
const sslMode = (process.env.PGSSLMODE || '').toLowerCase();
const useSsl = sslMode === 'require' || sslMode === 'verify-ca' || sslMode === 'verify-full' || process.env.DATABASE_SSL === 'true' || Boolean(connectionString && /\.liara\.ir/i.test(connectionString));
const rejectUnauthorized = sslMode === 'verify-ca' || sslMode === 'verify-full';

// Pool connects lazily; an unset DATABASE_URL does not prevent the app from starting.
export const pool = new Pool({
  ...(connectionString ? { connectionString } : {}),
  ...(useSsl ? { ssl: { rejectUnauthorized } } : {}),
  max: Number(process.env.PGPOOL_MAX || 10),
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
});

pool.on('error', (error) => console.error('Unexpected PostgreSQL pool error:', error.message));

export async function checkDatabase(): Promise<boolean> {
  if (!connectionString) return false;
  try { await pool.query('SELECT 1'); return true; }
  catch (error) { console.error('PostgreSQL healthcheck failed:', error instanceof Error ? error.message : error); return false; }
}
