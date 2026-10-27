import { pool } from '@/lib/db';
import { COUNTRIES, GROUPS, OFFICIAL_DIRECTORIES } from '@/lib/constants';

let migrationPromise: Promise<void> | undefined;

type OfficialSeed = { requirements: string[]; minScore: number | null; processingTime: string | null; strategy: string[] };

// Conservative curated facts: exact eligibility, scores and processing times vary by
// program and are not published uniformly. These seeds direct users to source material
// rather than inventing a route-specific rule.
function curatedFacts(country: string, groupTitle: string, url: string): OfficialSeed {
  const requirements = [
    `بررسی شرایط همان برنامه/زیرشاخه در منبع رسمی ${country}؛ این راهنمای عمومی، شرط پذیرش یا ویزا تعیین نمی‌کند.`,
    'الزامات، مدارک، هزینه‌ها و امکان اقدام باید پیش از ارسال از صفحهٔ رسمی همان برنامه کنترل شوند.',
    'حدنصاب زبان، تمکن، سابقه یا امتیاز فقط در صورت تصریح صفحهٔ رسمیِ برنامه قابل اعلام است.'
  ];
  return {
    requirements,
    minScore: null,
    processingTime: null,
    strategy: [
      `برای مسیر «${groupTitle}»، ابتدا دستهٔ رسمی متناسب را در منبع درج‌شده شناسایی کنید: ${url}`,
      'مدارک و معیارها را از چک‌لیست رسمیِ جاری استخراج کنید؛ این seed عمداً امتیاز یا زمان پردازشِ تأییدنشده ندارد.',
      'پیش از اقدام، تاریخ به‌روزرسانی و صلاحیت مرجع/ارزیاب معرفی‌شده در همان منبع را بررسی کنید.'
    ]
  };
}

async function performMigration(): Promise<void> {
  if (!process.env.DATABASE_URL) {
    console.warn('DATABASE_URL is not configured; official-data migration skipped.');
    return;
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT pg_advisory_xact_lock(hashtext('mohajeryar:autoMigrate:v1'))");
    await client.query(`CREATE TABLE IF NOT EXISTS migration_groups (
      id text PRIMARY KEY, title text NOT NULL, description text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now()
    )`);
    await client.query(`CREATE TABLE IF NOT EXISTS countries (
      name text PRIMARY KEY, created_at timestamptz NOT NULL DEFAULT now()
    )`);
    await client.query(`CREATE TABLE IF NOT EXISTS migration_modules (
      id bigserial PRIMARY KEY, country text NOT NULL REFERENCES countries(name) ON DELETE CASCADE,
      group_id text NOT NULL REFERENCES migration_groups(id) ON DELETE CASCADE,
      requirements jsonb NOT NULL DEFAULT '[]'::jsonb, min_score numeric NULL,
      processing_time text NULL, official_source_url text NOT NULL,
      strategy_advice jsonb NOT NULL DEFAULT '[]'::jsonb, updated_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE(country, group_id)
    )`);
    for (const group of GROUPS) {
      await client.query(`INSERT INTO migration_groups(id,title,description) VALUES($1,$2,$3)
        ON CONFLICT(id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description`, [group.id,group.title,group.description]);
    }
    for (const country of COUNTRIES) {
      await client.query('INSERT INTO countries(name) VALUES($1) ON CONFLICT(name) DO NOTHING', [country]);
    }
    for (const [country, links] of Object.entries(OFFICIAL_DIRECTORIES)) {
      const primary = links.find((link) => link.kind === 'portal') || links[0];
      if (!primary) continue;
      for (const group of GROUPS) {
        const facts = curatedFacts(country, group.title, primary.url);
        await client.query(`INSERT INTO migration_modules(country,group_id,requirements,min_score,processing_time,official_source_url,strategy_advice)
          VALUES($1,$2,$3::jsonb,$4,$5,$6,$7::jsonb)
          ON CONFLICT(country,group_id) DO UPDATE SET requirements=EXCLUDED.requirements,
          min_score=EXCLUDED.min_score, processing_time=EXCLUDED.processing_time,
          official_source_url=EXCLUDED.official_source_url, strategy_advice=EXCLUDED.strategy_advice, updated_at=now()`,
          [country,group.id,JSON.stringify(facts.requirements),facts.minScore,facts.processingTime,primary.url,JSON.stringify(facts.strategy)]);
      }
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw error;
  } finally { client.release(); }
}

export function autoMigrate(): Promise<void> {
  if (!migrationPromise) migrationPromise = performMigration().catch((error) => {
    migrationPromise = undefined; // a later request may retry after DB becomes available
    throw error;
  });
  return migrationPromise;
}
