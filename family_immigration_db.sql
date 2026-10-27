-- ============================================================================
-- Family-Based Immigration Database Schema & Seed Data
-- پایگاه داده جامع برنامه‌های مهاجرت خانوادگی و الحاق به خانواده
--
-- Target Platform: PostgreSQL 14+ (Compatible with Liara.ir / Cloud DBs)
-- Supported Countries (12 Target Countries):
--   1. United States (USA)
--   2. Canada (CAN)
--   3. Germany (DEU)
--   4. Turkey (TUR)
--   5. Netherlands (NLD)
--   6. United Kingdom (GBR)
--   7. Sweden (SWE)
--   8. Australia (AUS)
--   9. France (FRA)
--   10. Italy (ITA)
--   11. Spain (ESP)
--   12. United Arab Emirates (ARE)
--
-- Features:
--   - UUID Primary Keys with DEFAULT gen_random_uuid() / uuid-ossp
--   - Full-text search tsvector generated column (Persian & English)
--   - GIN indexes on tsvector, JSONB columns, arrays, and trigram text search (pg_trgm)
--   - Auto-updating timestamps with update_updated_at_column() triggers
--   - Iranian-specific applicant notes (third-country routing, sanctions, embassy centers)
--   - Ready-to-query reporting views
-- ============================================================================

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. Drop existing views and tables if recreating
DROP VIEW IF EXISTS v_document_checklist CASCADE;
DROP VIEW IF EXISTS v_iranian_friendly_programs CASCADE;
DROP VIEW IF EXISTS v_family_programs_summary CASCADE;

DROP TABLE IF EXISTS pathway_comparisons CASCADE;
DROP TABLE IF EXISTS program_statistics CASCADE;
DROP TABLE IF EXISTS integration_requirements CASCADE;
DROP TABLE IF EXISTS embassy_application_centers CASCADE;
DROP TABLE IF EXISTS iranian_applicant_notes CASCADE;
DROP TABLE IF EXISTS processing_info CASCADE;
DROP TABLE IF EXISTS required_documents CASCADE;
DROP TABLE IF EXISTS financial_requirements CASCADE;
DROP TABLE IF EXISTS family_visa_programs CASCADE;
DROP TABLE IF EXISTS family_relationship_types CASCADE;
DROP TABLE IF EXISTS countries CASCADE;

-- Drop Custom ENUM Types
DROP TYPE IF EXISTS relationship_category_enum CASCADE;
DROP TYPE IF EXISTS visa_type_enum CASCADE;
DROP TYPE IF EXISTS financial_req_type_enum CASCADE;
DROP TYPE IF EXISTS document_category_enum CASCADE;
DROP TYPE IF EXISTS note_category_enum CASCADE;
DROP TYPE IF EXISTS note_severity_enum CASCADE;
DROP TYPE IF EXISTS center_type_enum CASCADE;
DROP TYPE IF EXISTS integration_type_enum CASCADE;

-- 3. Custom ENUM Types
CREATE TYPE relationship_category_enum AS ENUM (
    'spouse',
    'partner',
    'child',
    'parent',
    'sibling',
    'other'
);

CREATE TYPE visa_type_enum AS ENUM (
    'family_reunification',
    'spouse_partner',
    'dependent_child',
    'parent',
    'sibling',
    'other'
);

CREATE TYPE financial_req_type_enum AS ENUM (
    'min_income',
    'savings',
    'blocked_account',
    'insurance',
    'other'
);

CREATE TYPE document_category_enum AS ENUM (
    'identity',
    'relationship_proof',
    'financial',
    'medical',
    'legal',
    'language',
    'other'
);

CREATE TYPE note_category_enum AS ENUM (
    'embassy',
    'sanctions',
    'additional_documents',
    'workaround',
    'warning',
    'tip'
);

CREATE TYPE note_severity_enum AS ENUM (
    'info',
    'warning',
    'critical'
);

CREATE TYPE center_type_enum AS ENUM (
    'embassy',
    'consulate',
    'vac',
    'online'
);

CREATE TYPE integration_type_enum AS ENUM (
    'language_test',
    'civic_knowledge',
    'income_proof',
    'housing',
    'health_insurance',
    'criminal_record',
    'other'
);

-- 4. Shared Trigger Function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- TABLE 1: countries (کشورها)
-- ============================================================================
CREATE TABLE countries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_en VARCHAR(100) NOT NULL UNIQUE,
    name_fa VARCHAR(100) NOT NULL UNIQUE,
    iso_code VARCHAR(3) NOT NULL UNIQUE,
    flag_emoji VARCHAR(10) NOT NULL,
    region VARCHAR(100) NOT NULL,
    official_language VARCHAR(100) NOT NULL,
    currency_code VARCHAR(5) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_countries_updated_at
BEFORE UPDATE ON countries
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_countries_iso ON countries(iso_code);
CREATE INDEX idx_countries_region ON countries(region);
CREATE INDEX idx_countries_name_trgm ON countries USING gin (name_en gin_trgm_ops, name_fa gin_trgm_ops);

-- ============================================================================
-- TABLE 2: family_relationship_types (انواع نسبت‌های خانوادگی)
-- ============================================================================
CREATE TABLE family_relationship_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_en VARCHAR(100) NOT NULL UNIQUE,
    relationship_fa VARCHAR(100) NOT NULL UNIQUE,
    relationship_category relationship_category_enum NOT NULL,
    max_age_limit INT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_family_relationship_types_updated_at
BEFORE UPDATE ON family_relationship_types
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_fam_rel_category ON family_relationship_types(relationship_category);

-- ============================================================================
-- TABLE 3: family_visa_programs (برنامه‌ها و ویزاهای مهاجرت خانوادگی)
-- ============================================================================
CREATE TABLE family_visa_programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES countries(id) ON DELETE CASCADE,
    program_code VARCHAR(50) NOT NULL UNIQUE,
    program_name_en VARCHAR(255) NOT NULL,
    program_name_fa VARCHAR(255) NOT NULL,
    visa_type visa_type_enum NOT NULL,
    relationship_types_covered JSONB NOT NULL DEFAULT '[]'::jsonb,
    sponsor_requirements JSONB NOT NULL DEFAULT '{}'::jsonb,
    applicant_requirements JSONB NOT NULL DEFAULT '{}'::jsonb,
    max_family_members INT DEFAULT NULL,
    base_processing_time_months INT,
    fast_track_available BOOLEAN NOT NULL DEFAULT false,
    fast_track_months INT,
    official_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    notes TEXT,
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('simple', coalesce(program_name_en, '') || ' ' || coalesce(program_name_fa, '') || ' ' || coalesce(program_code, '') || ' ' || coalesce(notes, ''))
    ) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_family_visa_programs_updated_at
BEFORE UPDATE ON family_visa_programs
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_fvp_country_id ON family_visa_programs(country_id);
CREATE INDEX idx_fvp_visa_type ON family_visa_programs(visa_type);
CREATE INDEX idx_fvp_relationships ON family_visa_programs USING gin (relationship_types_covered);
CREATE INDEX idx_fvp_sponsor_req ON family_visa_programs USING gin (sponsor_requirements);
CREATE INDEX idx_fvp_applicant_req ON family_visa_programs USING gin (applicant_requirements);
CREATE INDEX idx_fvp_search_vector ON family_visa_programs USING gin (search_vector);
CREATE INDEX idx_fvp_name_trgm ON family_visa_programs USING gin (program_name_en gin_trgm_ops, program_name_fa gin_trgm_ops);

-- ============================================================================
-- TABLE 4: financial_requirements (الزامات مالی و تمکن)
-- ============================================================================
CREATE TABLE financial_requirements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES family_visa_programs(id) ON DELETE CASCADE,
    requirement_type financial_req_type_enum NOT NULL,
    amount_local_currency NUMERIC(14, 2),
    amount_usd_approx NUMERIC(14, 2),
    currency_code VARCHAR(5) NOT NULL,
    per_additional_member BOOLEAN NOT NULL DEFAULT false,
    notes_fa TEXT,
    notes_en TEXT,
    valid_from DATE DEFAULT CURRENT_DATE,
    valid_until DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_financial_requirements_updated_at
BEFORE UPDATE ON financial_requirements
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_fin_req_program_id ON financial_requirements(program_id);
CREATE INDEX idx_fin_req_type ON financial_requirements(requirement_type);

-- ============================================================================
-- TABLE 5: required_documents (مدارک و مستندات مورد نیاز)
-- ============================================================================
CREATE TABLE required_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES family_visa_programs(id) ON DELETE CASCADE,
    document_name_en VARCHAR(255) NOT NULL,
    document_name_fa VARCHAR(255) NOT NULL,
    document_category document_category_enum NOT NULL,
    is_mandatory BOOLEAN NOT NULL DEFAULT true,
    apostille_required BOOLEAN NOT NULL DEFAULT false,
    translation_required BOOLEAN NOT NULL DEFAULT true,
    official_translation BOOLEAN NOT NULL DEFAULT true,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_required_documents_updated_at
BEFORE UPDATE ON required_documents
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_req_docs_program_id ON required_documents(program_id);
CREATE INDEX idx_req_docs_category ON required_documents(document_category);
CREATE INDEX idx_req_docs_mandatory ON required_documents(is_mandatory);

-- ============================================================================
-- TABLE 6: processing_info (مراحل و زمان‌بندی بررسی پرونده)
-- ============================================================================
CREATE TABLE processing_info (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES family_visa_programs(id) ON DELETE CASCADE,
    stage_name_en VARCHAR(255) NOT NULL,
    stage_name_fa VARCHAR(255) NOT NULL,
    typical_duration_weeks INT,
    min_duration_weeks INT,
    max_duration_weeks INT,
    stage_order INT NOT NULL DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_processing_info_updated_at
BEFORE UPDATE ON processing_info
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_proc_info_program_id ON processing_info(program_id);
CREATE INDEX idx_proc_info_stage_order ON processing_info(program_id, stage_order);

-- ============================================================================
-- TABLE 7: iranian_applicant_notes (نکات ویژه، تحریم‌ها و توصیه‌ها برای متقاضیان ایرانی)
-- ============================================================================
CREATE TABLE iranian_applicant_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES family_visa_programs(id) ON DELETE CASCADE,
    note_category note_category_enum NOT NULL,
    title_fa VARCHAR(255) NOT NULL,
    content_fa TEXT NOT NULL,
    intermediate_countries TEXT[] DEFAULT '{}',
    last_verified DATE DEFAULT CURRENT_DATE,
    severity note_severity_enum NOT NULL DEFAULT 'info',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_iranian_applicant_notes_updated_at
BEFORE UPDATE ON iranian_applicant_notes
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_iran_notes_program_id ON iranian_applicant_notes(program_id);
CREATE INDEX idx_iran_notes_severity ON iranian_applicant_notes(severity);
CREATE INDEX idx_iran_notes_category ON iranian_applicant_notes(note_category);
CREATE INDEX idx_iran_notes_intermediate ON iranian_applicant_notes USING gin (intermediate_countries);

-- ============================================================================
-- TABLE 8: embassy_application_centers (سفارت‌ها و مراکز ثبت درخواست برای ایرانیان)
-- ============================================================================
CREATE TABLE embassy_application_centers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES countries(id) ON DELETE CASCADE,
    city_name VARCHAR(100) NOT NULL,
    country_of_location VARCHAR(100) NOT NULL,
    center_type center_type_enum NOT NULL,
    address TEXT,
    phone VARCHAR(100),
    website TEXT,
    accepts_iranians BOOLEAN NOT NULL DEFAULT true,
    appointment_wait_weeks INT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_embassy_centers_updated_at
BEFORE UPDATE ON embassy_application_centers
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_emb_centers_country_id ON embassy_application_centers(country_id);
CREATE INDEX idx_emb_centers_accepts_iranians ON embassy_application_centers(accepts_iranians);
CREATE INDEX idx_emb_centers_location ON embassy_application_centers(country_of_location, city_name);

-- ============================================================================
-- TABLE 9: integration_requirements (الزامات ادغام، زبان و اسکان)
-- ============================================================================
CREATE TABLE integration_requirements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES family_visa_programs(id) ON DELETE CASCADE,
    requirement_name_en VARCHAR(255) NOT NULL,
    requirement_name_fa VARCHAR(255) NOT NULL,
    requirement_type integration_type_enum NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_pre_arrival BOOLEAN NOT NULL DEFAULT false,
    is_post_arrival BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_integration_reqs_updated_at
BEFORE UPDATE ON integration_requirements
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_integ_reqs_program_id ON integration_requirements(program_id);
CREATE INDEX idx_integ_reqs_type ON integration_requirements(requirement_type);
CREATE INDEX idx_integ_details ON integration_requirements USING gin (details);

-- ============================================================================
-- TABLE 10: program_statistics (آمار صدور ویزا و پذیرش متقاضیان ایرانی و جهانی)
-- ============================================================================
CREATE TABLE program_statistics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES family_visa_programs(id) ON DELETE CASCADE,
    stat_year INT NOT NULL,
    stat_period VARCHAR(20) DEFAULT 'annual',
    total_applications INT,
    total_approvals INT,
    approval_rate_pct NUMERIC(5,2),
    iranian_applications INT,
    iranian_approvals INT,
    avg_processing_months NUMERIC(4,1),
    source TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_approval_rate CHECK (approval_rate_pct >= 0 AND approval_rate_pct <= 100)
);

CREATE TRIGGER trg_program_statistics_updated_at
BEFORE UPDATE ON program_statistics
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_prog_stats_program_id ON program_statistics(program_id);
CREATE INDEX idx_prog_stats_year ON program_statistics(stat_year);

-- ============================================================================
-- TABLE 11: pathway_comparisons (مسیرهای اقامت دائم و شهروندی پس از ویزا)
-- ============================================================================
CREATE TABLE pathway_comparisons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES countries(id) ON DELETE CASCADE,
    from_visa_type VARCHAR(100) NOT NULL,
    to_pr_possible BOOLEAN NOT NULL DEFAULT true,
    to_citizenship_possible BOOLEAN NOT NULL DEFAULT true,
    min_years_to_pr NUMERIC(4,1),
    min_years_to_citizenship NUMERIC(4,1),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_pathway_comparisons_updated_at
BEFORE UPDATE ON pathway_comparisons
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_pathways_country_id ON pathway_comparisons(country_id);


-- ============================================================================
-- VIEWS FOR REPORTING & FRONTEND CONSUMPTION
-- ============================================================================

-- View 1: v_family_programs_summary
CREATE OR REPLACE VIEW v_family_programs_summary AS
SELECT 
    fvp.id AS program_id,
    fvp.program_code,
    fvp.program_name_en,
    fvp.program_name_fa,
    fvp.visa_type,
    c.id AS country_id,
    c.name_en AS country_name_en,
    c.name_fa AS country_name_fa,
    c.flag_emoji,
    c.region,
    fvp.base_processing_time_months,
    fvp.fast_track_available,
    fvp.fast_track_months,
    fvp.is_active,
    fvp.official_url,
    COALESCE(fin.min_income_amount_usd, 0) AS min_income_amount_usd,
    COALESCE(fin.min_savings_amount_usd, 0) AS min_savings_amount_usd,
    COALESCE(notes_summary.total_notes_count, 0) AS total_iranian_notes_count,
    COALESCE(notes_summary.critical_notes_count, 0) AS critical_notes_count,
    COALESCE(docs_summary.total_docs_count, 0) AS total_required_docs_count,
    COALESCE(docs_summary.mandatory_docs_count, 0) AS mandatory_docs_count
FROM family_visa_programs fvp
JOIN countries c ON fvp.country_id = c.id
LEFT JOIN (
    SELECT 
        program_id,
        MAX(CASE WHEN requirement_type = 'min_income' THEN amount_usd_approx ELSE NULL END) AS min_income_amount_usd,
        MAX(CASE WHEN requirement_type IN ('savings', 'blocked_account') THEN amount_usd_approx ELSE NULL END) AS min_savings_amount_usd
    FROM financial_requirements
    GROUP BY program_id
) fin ON fvp.id = fin.program_id
LEFT JOIN (
    SELECT 
        program_id,
        COUNT(*) AS total_notes_count,
        COUNT(CASE WHEN severity = 'critical' THEN 1 END) AS critical_notes_count
    FROM iranian_applicant_notes
    GROUP BY program_id
) notes_summary ON fvp.id = notes_summary.program_id
LEFT JOIN (
    SELECT 
        program_id,
        COUNT(*) AS total_docs_count,
        COUNT(CASE WHEN is_mandatory = true THEN 1 END) AS mandatory_docs_count
    FROM required_documents
    GROUP BY program_id
) docs_summary ON fvp.id = docs_summary.program_id;

-- View 2: v_iranian_friendly_programs
CREATE OR REPLACE VIEW v_iranian_friendly_programs AS
SELECT 
    fvp.id AS program_id,
    fvp.program_code,
    fvp.program_name_en,
    fvp.program_name_fa,
    fvp.visa_type,
    c.name_en AS country_name_en,
    c.name_fa AS country_name_fa,
    c.flag_emoji,
    fvp.base_processing_time_months,
    emb.accepted_embassies_count,
    emb.centers_list,
    COALESCE(crit_notes.has_critical_issue, false) AS has_critical_warning
FROM family_visa_programs fvp
JOIN countries c ON fvp.country_id = c.id
LEFT JOIN (
    SELECT 
        country_id,
        COUNT(*) AS accepted_embassies_count,
        STRING_AGG(city_name || ' (' || country_of_location || ')', ', ') AS centers_list
    FROM embassy_application_centers
    WHERE accepts_iranians = true
    GROUP BY country_id
) emb ON c.id = emb.country_id
LEFT JOIN (
    SELECT 
        program_id,
        true AS has_critical_issue
    FROM iranian_applicant_notes
    WHERE severity = 'critical'
    GROUP BY program_id
) crit_notes ON fvp.id = crit_notes.program_id
WHERE fvp.is_active = true
  AND (crit_notes.has_critical_issue IS NULL OR crit_notes.has_critical_issue = false)
  AND emb.accepted_embassies_count > 0;

-- View 3: v_document_checklist
CREATE OR REPLACE VIEW v_document_checklist AS
SELECT 
    c.name_en AS country_name_en,
    c.name_fa AS country_name_fa,
    c.flag_emoji,
    fvp.program_code,
    fvp.program_name_en,
    fvp.program_name_fa,
    rd.id AS document_id,
    rd.document_name_en,
    rd.document_name_fa,
    rd.document_category,
    rd.is_mandatory,
    rd.apostille_required,
    rd.translation_required,
    rd.official_translation,
    rd.notes AS document_notes
FROM required_documents rd
JOIN family_visa_programs fvp ON rd.program_id = fvp.id
JOIN countries c ON fvp.country_id = c.id
WHERE rd.is_mandatory = true
ORDER BY c.name_en, fvp.program_code, rd.document_category;


-- ============================================================================
-- SEED DATA / داده‌های پایه
-- ============================================================================

-- 1. Insert Countries (12 Target Countries)
INSERT INTO countries (name_en, name_fa, iso_code, flag_emoji, region, official_language, currency_code) VALUES
('United States', 'ایالات متحده آمریکا', 'USA', '🇺🇸', 'North America', 'English', 'USD'),
('Canada', 'کانادا', 'CAN', '🇨🇦', 'North America', 'English / French', 'CAD'),
('Germany', 'آلمان', 'DEU', '🇩🇪', 'Europe (EU/Schengen)', 'German', 'EUR'),
('Turkey', 'ترکیه', 'TUR', '🇹🇷', 'Eurasia', 'Turkish', 'TRY'),
('Netherlands', 'هلند', 'NLD', '🇳🇱', 'Europe (EU/Schengen)', 'Dutch', 'EUR'),
('United Kingdom', 'انگلستان (بریتانیا)', 'GBR', '🇬🇧', 'Europe', 'English', 'GBP'),
('Sweden', 'سوئد', 'SWE', '🇸🇪', 'Europe (EU/Schengen)', 'Swedish', 'SEK'),
('Australia', 'استرالیا', 'AUS', '🇦🇺', 'Oceania', 'English', 'AUD'),
('France', 'فرانسه', 'FRA', '🇫🇷', 'Europe (EU/Schengen)', 'French', 'EUR'),
('Italy', 'ایتالیا', 'ITA', '🇮🇹', 'Europe (EU/Schengen)', 'Italian', 'EUR'),
('Spain', 'اسپانیا', 'ESP', '🇪🇸', 'Europe (EU/Schengen)', 'Spanish', 'EUR'),
('United Arab Emirates', 'امارات متحده عربی', 'ARE', '🇦🇪', 'Middle East (GCC)', 'Arabic / English', 'AED');

-- 2. Insert Relationship Types
INSERT INTO family_relationship_types (relationship_en, relationship_fa, relationship_category, max_age_limit, notes) VALUES
('Spouse (Legally Married)', 'همسر رسمی و قانونی', 'spouse', NULL, 'ازدواج ثبت‌شده قانونی بر اساس قوانین محل وقوع عقد'),
('Civil / Common-law Partner', 'شریک زندگی و هم‌باش قانونی', 'partner', NULL, 'اثبات زندگی مشترک مستمر حداقل ۱ تا ۲ سال بسته به کشور مقصد'),
('Minor Dependent Child', 'فرزند وابسته و صغیر', 'child', 18, 'فرزند زیر ۱۸ سال متقاضی یا همسر'),
('Adult Dependent Child (Student/Disabled)', 'فرزند بزرگسال وابسته (دانشجو یا دارای معلولیت)', 'child', 21, 'فرزندان وابسته مالی، دانشجوی تمام وقت یا دارای شرایط خاص پزشکی'),
('Elderly Dependent Parent', 'والدین وابسته و سالخورده', 'parent', NULL, 'پدر یا مادر تحت تکفل کامل مالی و مراقبتی اسپانسر'),
('Grandparent', 'پدربزرگ و مادربزرگ', 'parent', NULL, 'تحت تکفل در برنامه‌های خاص نظیر کانادا PGP'),
('Fiancé / Fiancée', 'نامزد رسمی', 'partner', NULL, 'ویژه ویزاهای نامزدی مانند K-1 آمریکا قبل از ثبت ازدواج'),
('Sibling (Brother / Sister)', 'خواهر یا برادر', 'sibling', NULL, 'متقاضی در ویزاهای اولویت خانوادگی نظیر F4 آمریکا');

-- ============================================================================
-- 3. Insert Family Visa Programs for all 12 Countries
-- ============================================================================

-- USA
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'US_IR1_CR1', 'IR-1 / CR-1 Spouse of U.S. Citizen Immigrant Visa', 'ویزای اقامت دائم همسر شهروند آمریکا (IR-1 / CR-1)', 'spouse_partner',
'["spouse"]'::jsonb,
'{"citizenship": "US Citizen only", "form": "I-130 + I-864", "min_income_poverty_guideline": "125% HHS Federal Poverty Guidelines", "domicile": "Must maintain U.S. domicile"}'::jsonb,
'{"min_age": 18, "medical_exam": "Required by CDC approved panel physician", "background_check": "Police clearance from all lived countries > 6 months after age 16", "ds260": "Required"}'::jsonb,
1, 14, false, 'https://travel.state.gov/content/travel/en/us-visas/immigrate/family-immigration.html',
'CR-1 برای ازدواج‌های زیر ۲ سال با گرین‌کارت مشروط ۲ ساله؛ IR-1 برای ازدواج‌های بیش از ۲ سال با گرین‌کارت دائمی ۱۰ ساله صادر می‌شود.'
FROM countries WHERE iso_code = 'USA';

INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'US_F2A', 'F2A Spouses and Unmarried Children of Permanent Residents', 'ویزای F2A همسر و فرزندان مجرد مقیم دائم آمریکا (دارنده گرین‌کارت)', 'family_reunification',
'["spouse", "child"]'::jsonb,
'{"citizenship": "Lawful Permanent Resident (Green Card Holder)", "form": "I-130 + I-864", "min_income_poverty_guideline": "125% HHS"}'::jsonb,
'{"unmarried": true, "child_max_age": 21, "medical_exam": true, "visa_bulletin": "Subject to priority date backlogs in Visa Bulletin"}'::jsonb,
5, 30, false, 'https://travel.state.gov/content/travel/en/us-visas/immigrate/family-immigration.html',
'مشمول محدودیت سهمیه سالانه و ویزا بولتن وزارت امور خارجه آمریکا (Visa Bulletin Priority Date).'
FROM countries WHERE iso_code = 'USA';

INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'US_K1', 'K-1 Nonimmigrant Visa for Fiancé(e) of U.S. Citizen', 'ویزای نامزدی K-1 آمریکا ویژه شهروندان ایالات متحده', 'spouse_partner',
'["partner"]'::jsonb,
'{"citizenship": "US Citizen only", "form": "I-129F", "met_in_person": "Must have met in person within 2 years before filing", "intent_to_marry": "Marriage within 90 days of US entry required"}'::jsonb,
'{"unmarried": true, "eligible_to_marry": true, "ds160": "Required", "medical_exam": true}'::jsonb,
1, 10, false, 'https://travel.state.gov/content/travel/en/us-visas/immigrate/family-immigration/fiancee-visa.html',
'متقاضی پس از ورود به آمریکا موظف است ظرف ۹۰ روز ازدواج رسمی ثبت کرده و برای گرین‌کارت (I-485 AOS) اقدام کند.'
FROM countries WHERE iso_code = 'USA';

-- Canada
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'CA_SPOUSAL', 'Canada Spousal and Common-Law Partner Sponsorship', 'اسپانسرشیپ همسر و شریک زندگی کانادا (داخل و خارج خاک)', 'spouse_partner',
'["spouse", "partner", "child"]'::jsonb,
'{"status": "Canadian Citizen or PR", "min_age": 18, "undertaking_years": 3, "financial_mico_exempt": "No Minimum Necessary Income required unless dependent child has dependent children"}'::jsonb,
'{"min_age": 18, "relationship_proof": "Genuine and not entered primarily for immigration", "biometrics": true, "medical": true, "police_clearance": true}'::jsonb,
4, 12, false, 'https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/family-sponsorship/spouse-partner-children.html',
'تعهد اسپانسر ۳ ساله بدون قید و شرط است. امکان دریافت Open Work Permit برای پرونده‌های داخل کانادا وجود دارد.'
FROM countries WHERE iso_code = 'CAN';

INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'CA_PGP', 'Canada Parents and Grandparents Sponsorship Program (PGP)', 'برنامه اسپانسرشیپ اقامت دائم والدین و پدربزرگ/مادربزرگ کانادا', 'parent',
'["parent"]'::jsonb,
'{"status": "Canadian Citizen or PR", "undertaking_years": 20, "mni_income_proof": "Minimum Necessary Income (MNI) + 30% for 3 consecutive tax years (NOA)", "intake": "Lottery/Expression of Interest system"}'::jsonb,
'{"medical_admissibility": "No excessive demand on healthcare", "police_certificates": true, "biometrics": true}'::jsonb,
2, 36, false, 'https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/family-sponsorship/parents-grandparents.html',
'تعهد مالی طولانی ۲۰ ساله در تمام استان‌ها (در کبک ۱۰ ساله). برای دوران انتظار طولانی، ویزای سوپر ویزا (Super Visa) جایگزین مناسبی است.'
FROM countries WHERE iso_code = 'CAN';

-- Germany
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'DE_FAMILY_27_36', 'Family Reunification Visa under §§27-36 AufenthG', 'ویزای الحاق به خانواده آلمان طبق مواد ۲۷ تا ۳۶ قانون اقامت AufenthG', 'family_reunification',
'["spouse", "child", "parent"]'::jsonb,
'{"residence_permit": "German citizen, EU Blue Card, ICT card, Settlement permit, or skilled worker permit", "living_space_sqm": "Minimum 12 sqm per adult / 10 sqm per child", "sufficient_income": "No claim on public social welfare (SGB II)"}'::jsonb,
'{"language_german_level": "A1 Goethe/Telc (exempt for EU Blue Card spouses & degree holders)", "health_insurance": "Full incoming/statutory health coverage", "valid_passport": true}'::jsonb,
4, 9, true, 'https://www.make-it-in-germany.com/en/visa-residence/types/family-reunification',
'برای دارندگان بلوکارت اروپا و نیروی متخصص جدید، همسر از ارائه مدرک زبان A1 معاف است و ویزای الحاق به صورت همزمان صادر می‌شود.'
FROM countries WHERE iso_code = 'DEU';

INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'DE_SPOUSE', 'German Citizen Spouse Visa (§28 AufenthG)', 'ویزای الحاق همسر به شهروند آلمانی (ماده ۲۸ قانون اقامت)', 'spouse_partner',
'["spouse"]'::jsonb,
'{"citizenship": "German Citizen", "residence_in_germany": "Habitual residence in Germany", "income_requirement": "Generally exempt from strict livelihood test"}'::jsonb,
'{"language_level": "A1 German certificate", "marriage_certificate": "Official certified & legalized marriage cert", "biometrics": true}'::jsonb,
1, 6, false, 'https://www.auswaertiges-amt.de/en/visa-service',
'همسر شهروند آلمان طبق ماده ۲۸ معمولاً از شرط اثبات تمکن مالی شدید معاف است، اما مدرک زبان A1 الزامی است.'
FROM countries WHERE iso_code = 'DEU';

-- Turkey
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'TR_FAMILY_RES', 'Turkey Family Residence Permit (Aile İkamet İzni)', 'اجازه اقامت خانوادگی ترکیه (ایقامت خانوادگی)', 'family_reunification',
'["spouse", "child"]'::jsonb,
'{"sponsor_status": "Turkish citizen, Blue Card holder, or Foreigner with valid Turkish work/residence permit for >= 1 year", "min_income": "Total income not less than minimum wage and at least 1/3 min wage per member", "housing": "Adequate living conditions", "health_insurance": "Comprehensive health insurance covering all family members"}'::jsonb,
'{"valid_passport": "Passport valid for at least 60 days beyond requested permit", "police_clearance": "No criminal record affecting public order in Turkey", "legal_entry": "Valid visa or visa exemption entry"}'::jsonb,
5, 3, false, 'https://en.goc.gov.tr/residence-permits',
'حداکثر اعتبار اجازه اقامت خانوادگی تا ۳ سال در هر بار تمدید است و نباید از مدت اقامت اسپانسر بیشتر باشد.'
FROM countries WHERE iso_code = 'TUR';

INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'TR_SPOUSE', 'Turkey Spouse of Turkish Citizen Residence & Citizenship Pathway', 'اقامت و مسیر شهروندی همسر تبعه ترکیه', 'spouse_partner',
'["spouse"]'::jsonb,
'{"sponsor_status": "Turkish Citizen (T.C. Vatandaşı)", "marriage_registered": "Marriage registered in Turkish Civil Registry (Nüfus)"}'::jsonb,
'{"cohabitation": "Must live together in marital unity for at least 3 years", "security_investigation": "Clean security background with Police & MIT"}'::jsonb,
1, 3, false, 'https://www.nvi.gov.tr/',
'پس از ۳ سال زندگی مشترک واقعی با تبعه ترکیه، متقاضی می‌تواند مستقیماً برای اخذ پاسپورت و تابعیت ترکیه اقدام کند.'
FROM countries WHERE iso_code = 'TUR';

-- Netherlands
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'NL_MVV_TEV', 'Netherlands Family Reunification MVV / TEV Procedure (IND)', 'الحاق خانواده هلند از طریق رویه ورودی MVV / TEV اداره مهاجرت IND', 'family_reunification',
'["spouse", "partner", "child"]'::jsonb,
'{"sponsor_status": "Dutch Citizen or Foreigner with valid non-temporary residence permit", "min_income": "100% of Statutory Minimum Wage (WML) including holiday allowance, sustained for at least 1 year", "min_age": 21}'::jsonb,
'{"min_age": 21, "civic_exam_abroad": "Basic Civic Integration Examination (Basisexamen Inburgering Buitenland) A1 level", "tb_test": "Tuberculosis testing after arrival if required"}'::jsonb,
4, 6, false, 'https://ind.nl/en/residence-permits/family-and-partner',
'متقاضی باید قبل از ورود، آزمون ادغام مدنی و زبان هلندی A1 را در سفارت هلند (معمولاً آنکارا، ایروان یا دبی) با موفقیت بگذراند.'
FROM countries WHERE iso_code = 'NLD';

-- UK
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'UK_FLRM', 'UK Spouse / Partner Visa (Appendix FM / FLR(M))', 'ویزای همسر و شریک زندگی بریتانیا (پیوست FM و فرم FLR(M))', 'spouse_partner',
'["spouse", "partner"]'::jsonb,
'{"sponsor_status": "British citizen, Irish citizen, Settled status (ILR), or refugee status", "min_income_threshold": "£29,000 gross per year (standard requirement under revised 2024 rules)", "cash_savings_alternative": "£88,500 if relying purely on savings", "adequate_accommodation": "Property must not be overcrowded"}'::jsonb,
'{"min_age": 18, "english_language": "CEFR Level A1 (entry) or A2 (extension) SELT approved test", "tb_certificate": "TB test from approved clinic in Tehran (IOM)", "genuine_relationship": "Substantial proof of relationship"}'::jsonb,
2, 8, true, 'https://www.gov.uk/uk-family-visa/partner-spouse',
'آستانه درآمد مالی از سال ۲۰۲۴ به ۲۹،۰۰۰ پوند افزایش یافته است. امکان استفاده از سرویس بررسی سریع (Super Priority / Priority Visa) با پرداخت هزینه مازاد وجود دارد.'
FROM countries WHERE iso_code = 'GBR';

INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'UK_FAMILY', 'UK Family Visa for Dependent Child / Adult Dependent Relative', 'ویزای الحاق فرزندان و وابستگان سالخورده به بریتانیا', 'dependent_child',
'["child", "parent", "other"]'::jsonb,
'{"sponsor_status": "British citizen or person with settled status in the UK", "sole_responsibility": "Sponsor must demonstrate sole responsibility for child or exceptional compassionate dependency for adult relative"}'::jsonb,
'{"age_limit": "Under 18 at date of application for child; Elderly adult relatives must need high level personal care not available in home country", "tb_certificate": true}'::jsonb,
3, 12, false, 'https://www.gov.uk/uk-family-visa',
'ویزای Adult Dependent Relative (ADR) بریتانیا از نظر پذیرش یکی از سخت‌گیرانه‌ترین ویزاهای مهاجرتی دنیاست و نیاز به اثبات عدم امکان مراقبت در ایران دارد.'
FROM countries WHERE iso_code = 'GBR';

-- Sweden
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'SE_FAMILY', 'Sweden Residence Permit for Family Members (Uppehållstillstånd)', 'اجازه اقامت سوئد برای پیوستن به اعضای خانواده (مهاجرت‌ورکت)', 'family_reunification',
'["spouse", "partner", "child"]'::jsonb,
'{"sponsor_status": "Swedish citizen, permanent resident, or holder of eligible temporary work/doctoral permit", "maintenance_requirement": "Försörjningskrav - income to support self and family after rent", "housing_standard": "Adequate size: 2 rooms + kitchen for 2 adults + 1 room per child"}'::jsonb,
'{"min_age": 21, "interview": "Mandatory in-person interview at designated Swedish Embassy (e.g. Tehran or Ankara)", "relationship_proof": "Documentation of cohabitation or marital status"}'::jsonb,
4, 12, false, 'https://www.migrationsverket.se/English/Private-individuals/Moving-to-someone-in-Sweden.html',
'شرط مسکن و استاندارد متراژ سوئد بسیار دقیق است. مصاحبه پرونده‌های الحاق خانواده به صورت حضوری در سفارت سوئد در تهران انجام می‌شود.'
FROM countries WHERE iso_code = 'SWE';

-- Australia
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'AU_PARTNER_820_801', 'Australia Partner Visa (Subclass 820 Temporary / Subclass 801 Permanent)', 'ویزای پارتنر استرالیا ساب‌کلاس ۸۲۰ (موقت) و ۸۰۱ (دائم)', 'spouse_partner',
'["spouse", "partner"]'::jsonb,
'{"sponsor_status": "Australian citizen, Australian PR, or eligible New Zealand citizen", "sponsorship_limitations": "Max 2 sponsorships per lifetime with 5-year gap", "character_check": "Australian AFP and international police checks for sponsor"}'::jsonb,
'{"relationship_pillars": "Proof across 4 pillars: Financial, Nature of household, Social context, Nature of commitment", "health_exam": "Strict Bupa/eMedical clearance", "police_clearance": "Character requirements Form 80"}'::jsonb,
3, 24, false, 'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-listing/partner-onshore',
'یک پروسه دو مرحله‌ای است؛ ابتدا اقامت موقت ۸۲۰ صادر شده و ۲ سال بعد از تشکیل پرونده، ارزیابی اقامت دائم ۸۰۱ انجام می‌شود.'
FROM countries WHERE iso_code = 'AUS';

INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'AU_PARENT_103_143', 'Australia Contributory Parent Visa (Subclass 143) / Non-Contributory (103)', 'ویزای والدین استرالیا ساب‌کلاس ۱۴۳ (حمایتی پولی) و ۱۰۳ (عادی)', 'parent',
'["parent"]'::jsonb,
'{"sponsor_status": "Settled Australian citizen or permanent resident", "balance_of_family_test": "At least half of sponsor children must live permanently in Australia", "assurance_of_support": "AoS bond placed with Centrelink for 10 years"}'::jsonb,
'{"health_check": "Must meet stringent public interest criteria PIC 4005/4007", "police_clearance": true}'::jsonb,
2, 180, false, 'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-listing/contributory-parent-143',
'ویزای عادی ۱۰۳ دارای صف انتظار تا ۳۰ سال است؛ ویزای حمایتی ۱۴۳ با پرداخت وجه کمکی دولتی (~۴۷،۰۰۰ دلار استرالیا برای هر والد) بررسی می‌شود.'
FROM countries WHERE iso_code = 'AUS';

-- France
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'FR_REGROUPEMENT', 'France Regroupement Familial (Family Reunification via OFII)', 'الحاق به خانواده فرانسه از طریق اداره مهاجرت و ادغام OFII', 'family_reunification',
'["spouse", "child"]'::jsonb,
'{"sponsor_status": "Regular foreigner residing in France for at least 18 months with valid Titre de Séjour", "min_resources": "SMIC net monthly earnings over last 12 months", "housing_criteria": "Adequate living area certified by city council inspection"}'::jsonb,
'{"min_age": 18, "medical_check": "OFII medical check upon entry", "integration_contract": "Signing Contrat d''Intégration Républicaine (CIR)"}'::jsonb,
4, 12, false, 'https://www.service-public.fr/particuliers/vosdroits/F11166',
'پرونده در پرفکتور و اداره آفئی (OFII) فرانسه بررسی و بازرسی حضوری مسکن انجام می‌شود.'
FROM countries WHERE iso_code = 'FRA';

INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'FR_SPOUSE_LONG_STAY', 'France Long-Stay Visa for Spouse of French National (VLS-TS Conjoint)', 'ویزای بلندمدت همسر تبعه فرانسوی (VLS-TS Conjoint de Français)', 'spouse_partner',
'["spouse"]'::jsonb,
'{"sponsor_status": "French Citizen", "marriage_transcription": "Marriage recorded in French civil status registry (Livret de Famille)"}'::jsonb,
'{"min_age": 18, "community_of_life": "Genuine shared marital life", "vls_validation": "Online validation with OFII within 3 months of arrival"}'::jsonb,
1, 4, false, 'https://france-visas.gouv.fr/en/web/france-visas/',
'پس از ورود به فرانسه، ویزای VLS-TS به صورت آنلاین در سامانه ANEF اعتبار اقامتی پیدا می‌کند و معاف از شرط تمکن مالی SMIC است.'
FROM countries WHERE iso_code = 'FRA';

-- Italy
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'IT_RICONGIUNGIMENTO', 'Italy Family Reunification Nulla Osta (Ricongiungimento Familiare)', 'ویزای الحاق به خانواده ایتالیا (نولا اوستا از اداره مهاجرت اسپورتلو اونیکو)', 'family_reunification',
'["spouse", "child", "parent"]'::jsonb,
'{"sponsor_status": "Foreign national with valid Italian Permesso di Soggiorno (at least 1 year validity)", "min_annual_income": "Annual Social Allowance (Assegno Sociale) + 50% for each family member", "housing_suitability": "Idoneità Alloggiativa certificate issued by local municipality"}'::jsonb,
'{"nulla_osta_code": "Prefettura Sportello Unico approval", "apostille_legalization": "Documents legalized with Dichiarazione di Valore / Italian Embassy legalization", "valid_passport": true}'::jsonb,
5, 9, false, 'https://vistoperitalia.esteri.it/home/en',
'ابتدا اسپانسر در ایتالیا نولا اوستا را از پرفتورا اخذ می‌کند، سپس اعضای خانواده به مرکز ویزامتریک در تهران یا سفارت ایتالیا مراجعه می‌کنند.'
FROM countries WHERE iso_code = 'ITA';

-- Spain
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'ES_REAGRUPACION', 'Spain Temporary Residence for Family Reunification (Reagrupación Familiar)', 'ویزای الحاق به خانواده اسپانیا (اقامت موقت پیوستن به خانواده)', 'family_reunification',
'["spouse", "partner", "child", "parent"]'::jsonb,
'{"sponsor_status": "Legally resident foreigner who has renewed initial residence (at least 1 year lawful residence)", "min_economic_means": "150% IPREM monthly for 1 relative + 50% IPREM for each additional", "housing_report": "Informe de vivienda adecuada from Autonomous Community"}'::jsonb,
'{"criminal_record": "Clean police check for last 5 years authenticated & translated into Spanish", "medical_certificate": "Medical certificate under International Health Regulations 2005"}'::jsonb,
4, 9, false, 'https://www.inclusion.gob.es/web/migraciones/w/autorizacion-de-residencia-temporal-por-reagrupacion-familiar',
'پس از صدور مجوز اولیه توسط اداره اتباع خارجی اسپانیا (Extranjería)، متقاضی ظرف ۲ ماه به کنسولگری اسپانیا در تهران یا BLS مراجعه می‌کند.'
FROM countries WHERE iso_code = 'ESP';

INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'ES_RESIDENCE_FAMILY', 'Spain EU Citizen Family Member Card (Tarjeta de Residencia de Familiar de Comunitario)', 'کارت اقامت خانوادگی شهروندان اتحادیه اروپا در اسپانیا (تارختا کومونیتاریا)', 'other',
'["spouse", "partner", "child", "parent"]'::jsonb,
'{"sponsor_status": "Spanish or EU/EEA Citizen residing or moving to Spain", "registration": "Sponsor registered in Central Foreigners Register"}'::jsonb,
'{"relationship_proof": "Marriage cert (Certificado de matrimonio), Pareja de hecho, or birth cert", "health_insurance": "Public or private Spanish comprehensive insurance"}'::jsonb,
4, 6, true, 'https://www.inclusion.gob.es/web/migraciones',
'اقامت ۵ ساله صادر می‌شود و به محض صدور مجوز، دارنده اجازه کار کامل در سراسر اسپانیا خواهد داشت.'
FROM countries WHERE iso_code = 'ESP';

-- UAE
INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'AE_FAMILY_RESIDENCE', 'UAE Residence Visa for Family & Dependants (GDRFA / ICP)', 'ویزای اقامت خانوادگی و افراد تحت تکفل امارات متحده عربی', 'family_reunification',
'["spouse", "child", "parent"]'::jsonb,
'{"sponsor_status": "Expatriate resident with valid UAE residency & Emirates ID", "min_salary": "AED 4,000 monthly or AED 3,000 + company accommodation for spouse/children; AED 20,000 for parents", "tenancy_contract": "Registered Ejari / Tawtheeq tenancy contract"}'::jsonb,
'{"medical_fitness": "Medical fitness test (Blood test for HIV/Hep + Chest X-Ray for TB) conducted inside UAE", "emirates_id_biometrics": "Biometric registration at ICP center", "attested_certificates": "MOFA UAE attested marriage & birth certificates"}'::jsonb,
6, 2, true, 'https://u.ae/en/information-and-services/visa-and-emirates-id/residence-visas',
'پروسه بسیار سریع و دیجیتال از طریق سامانه GDRFA دبی یا ICP فدرال. ویزای ورود صادر شده و مراحل پزشکی در داخل امارات انجام می‌شود.'
FROM countries WHERE iso_code = 'ARE';

INSERT INTO family_visa_programs (country_id, program_code, program_name_en, program_name_fa, visa_type, relationship_types_covered, sponsor_requirements, applicant_requirements, max_family_members, base_processing_time_months, fast_track_available, official_url, notes)
SELECT id, 'AE_GOLDEN_FAMILY', 'UAE 10-Year Golden Visa Family Sponsorship', 'اسپانسرشیپ ۱۰ ساله خانواده دارنده گلدن ویزای امارات', 'family_reunification',
'["spouse", "child", "parent"]'::jsonb,
'{"sponsor_status": "Holder of valid UAE 10-Year Golden Residency (Investor, Real Estate, Talent, Executive)", "no_age_limit_for_children": "Can sponsor male children up to age 25 or unlimited age for unmarried daughters", "no_limit_on_domestic_helpers": true}'::jsonb,
'{"medical_fitness": "Standard UAE medical fitness exam", "emirates_id": true}'::jsonb,
10, 2, true, 'https://u.ae/en/information-and-services/visa-and-emirates-id/residence-visas/golden-visa',
'در صورت فوت دارنده اصلی گلدن ویزا، اعضای خانواده مجازند تا پایان اعتبار ۱۰ ساله ویزای خود در امارات اقامت داشته باشند.'
FROM countries WHERE iso_code = 'ARE';

-- ============================================================================
-- 4. Insert Financial Requirements (الزامات تمکن و درآمد مالی)
-- ============================================================================
INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 25550.00, 25550.00, 'USD', true,
'حداقل درآمد سالانه اسپانسر بر اساس جدول ۱۲۵ درصد فدرال خط فقر (Form I-864 Poverty Guidelines) برای خانوار ۲ نفره؛ به ازای هر عضو اضافه حدود ۵,۳۸۰ دلار افزوده می‌شود.',
'125% Federal Poverty Line for household of 2; $5,380 for each additional dependent.'
FROM family_visa_programs WHERE program_code = 'US_IR1_CR1';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 25550.00, 25550.00, 'USD', true,
'نیاز به ارائه مدارک مالیاتی W2 و تکس ریترن ۳ سال اخیر یا معرفی کو-اسپانسر (Joint Sponsor) مقیم آمریکا در صورت کسر درآمد.',
'Form I-864 requires 3 years tax transcripts (IRS 1040/W-2) or eligible joint sponsor.'
FROM family_visa_programs WHERE program_code = 'US_F2A';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 20440.00, 20440.00, 'USD', false,
'در مرحله ویزای K-1، اثبات ۱۰۰ درصد خط فقر از طریق فرم I-134 کفایت می‌کند، اما پس از ورود در مرحله گرین‌کارت ۱۲۵ درصد الزامی است.',
'100% HHS Poverty Guidelines for Form I-134 at consular stage; 125% for I-864 adjustment of status.'
FROM family_visa_programs WHERE program_code = 'US_K1';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 0.00, 0.00, 'CAD', false,
'اسپانسرشیپ همسر در کانادا شرط حداقل درآمد MNI ندارد مگر اینکه فرزند تحت تکفل خود دارای فرزند وابسته باشد.',
'Spousal sponsorship is exempt from MNI unless a dependent child has dependent children.'
FROM family_visa_programs WHERE program_code = 'CA_SPOUSAL';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 53000.00, 39000.00, 'CAD', true,
'درآمد سالانه اسپانسر باید در ۳ برگه ارزیابی مالیاتی پیاپی (NOA) از سقف درآمد لازم (MNI + 30%) بیشتر باشد.',
'Minimum Necessary Income (MNI) plus 30% for 3 consecutive tax years as proven by CRA Notice of Assessments.'
FROM family_visa_programs WHERE program_code = 'CA_PGP';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 24000.00, 26000.00, 'EUR', true,
'درآمد خالص اسپانسر باید هزینه‌های زندگی خانوار را طبق جدول Bürgergeld بدون دریافت کمک دولتی پوشش دهد.',
'Net income must sufficiently cover rent, heating, and standard subsistence allowances without public welfare.'
FROM family_visa_programs WHERE program_code = 'DE_FAMILY_27_36';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 17002.00, 530.00, 'TRY', true,
'درآمد ماهانه اسپانسر نباید کمتر از حداقل دستمزد ترکیه (Asgari Ücret) باشد و به ازای هر عضو خانواده حداقل یک سوم حداقل دستمزد باشد.',
'Monthly income of sponsor must not be less than minimum wage and at least 1/3 minimum wage per dependent.'
FROM family_visa_programs WHERE program_code = 'TR_FAMILY_RES';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 2069.96, 2250.00, 'EUR', false,
'حداقل درآمد ماهانه ناخالص اسپانسر طبق استاندارد WML هلند به همراه ۸٪ پاداش تعطیلات (Vakantiegeld).',
'Gross monthly income equal to 100% statutory minimum wage (WML) including 8% holiday allowance.'
FROM family_visa_programs WHERE program_code = 'NL_MVV_TEV';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 29000.00, 37000.00, 'GBP', false,
'آستانه حداقل درآمد سالانه ناخالص اسپانسر انگلستان ۲۹،۰۰۰ پوند است (یا پس‌انداز نقدی ۸۸،۵۰۰ پوند که به مدت ۶ ماه در حساب نگهداری شده باشد).',
'Minimum gross income threshold of £29,000 per year or cash savings of £88,500 held for 6 continuous months.'
FROM family_visa_programs WHERE program_code = 'UK_FLRM';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 10061.00, 950.00, 'SEK', true,
'مبلغ استاندارد درآمد پس از کسر کامل اجاره‌بها و هزینه‌های مسکن برای زوجین (Förbehållsbelopp).',
'Monthly maintenance amount after housing costs: 10,061 SEK for cohabiting couples.'
FROM family_visa_programs WHERE program_code = 'SE_FAMILY';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'other', 8850.00, 5800.00, 'AUD', false,
'هزینه دولتی اداره مهاجرت استرالیا برای ثبت اپلیکیشن پارتنر ویزا ساب‌کلاس ۸۲۰/۸۰۱.',
'Home Affairs standard visa application charge for primary partner applicant.'
FROM family_visa_programs WHERE program_code = 'AU_PARTNER_820_801';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'savings', 47755.00, 31500.00, 'AUD', false,
'قسط دوم وجه دولتی ویزای حمایتی والدین ساب‌کلاس ۱۴۳ (Contributory Parent Visa Second VAC Fee) به ازای هر والد.',
'Second visa application charge per parent for subclass 143 contributory processing.'
FROM family_visa_programs WHERE program_code = 'AU_PARENT_103_143';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 1766.92, 1920.00, 'EUR', false,
'درآمد ناخالص ماهانه اسپانسر باید حداقل معادل حداقل دستمزد فرانسه (SMIC brut mensuel) در ۱۲ ماه اخیر باشد.',
'Average gross monthly resources equal to at least 12-month SMIC.'
FROM family_visa_programs WHERE program_code = 'FR_REGROUPEMENT';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 10453.00, 11400.00, 'EUR', true,
'درآمد سالانه اسپانسر برای الحاق ۱ عضو خانواده باید حداقل ۱.۵ برابر مستمری اجتماعی ایتالیا (Assegno Sociale) باشد.',
'Annual gross income equal to annual Assegno Sociale + 50% for one family member, +100% for two or more.'
FROM family_visa_programs WHERE program_code = 'IT_RICONGIUNGIMENTO';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 900.00, 980.00, 'EUR', true,
'اثبات ماهانه ۱۵۰٪ شاخص درآمدی اسپانیا (IPREM) برای نفر اول و ۵۰٪ IPREM برای هر نفر اضافه.',
'150% IPREM monthly for the first family member reunited + 50% IPREM for each subsequent dependent.'
FROM family_visa_programs WHERE program_code = 'ES_REAGRUPACION';

INSERT INTO financial_requirements (program_id, requirement_type, amount_local_currency, amount_usd_approx, currency_code, per_additional_member, notes_fa, notes_en)
SELECT id, 'min_income', 4000.00, 1090.00, 'AED', false,
'حداقل حقوق ماهانه اسپانسر در امارات طبق قرارداد کار رسمی تصدیق شده (MOHRE) یا ۴،۰۰۰ درهم یا ۳،۰۰۰ درهم به علاوه مسکن رایگان.',
'Minimum salary AED 4,000 or AED 3,000 plus company housing attested by MOHRE contract.'
FROM family_visa_programs WHERE program_code = 'AE_FAMILY_RESIDENCE';

-- ============================================================================
-- 5. Insert Required Documents (مدارک مورد نیاز)
-- ============================================================================
INSERT INTO required_documents (program_id, document_name_en, document_name_fa, document_category, is_mandatory, apostille_required, translation_required, official_translation, notes)
SELECT p.id, d.name_en, d.name_fa, d.cat::document_category_enum, d.mandatory, d.apostille, d.trans, d.off_trans, d.notes
FROM family_visa_programs p
CROSS JOIN (
    VALUES
    ('Valid National Passport', 'گذرنامه بین‌المللی دارای حداقل ۱۲ ماه اعتبار', 'identity', true, false, false, false, 'اسکن تمام صفحات دارای مهر، ویزا و اطلاعات هویتی'),
    ('National Identity Document & Shenasnameh', 'اصل شناسنامه متقاضی و اسپانسر به همراه کارت ملی', 'identity', true, true, true, true, 'ترجمه رسمی با مهر دادگستری و وزارت امور خارجه ایران (تأیید کنسولی سفارت)'),
    ('Official Marriage Certificate (Sanad Ezdevaj)', 'سند ازدواج رسمی (عقدنامه) و رونوشت برابر اصل ثبت اسناد', 'relationship_proof', true, true, true, true, 'کلیه صفحات سند نکاحیه باید ترجمه رسمی شده و شروط ضمن عقد قید گردد'),
    ('Proof of Genuine & Continuing Relationship', 'مستندات اثبات رابطه واقعی (عکس‌های مشترک، پیام‌ها، سفرهای دونفره)', 'relationship_proof', true, false, false, false, 'آلبوم عکس خانوادگی با ذکر تاریخ، بلیت سفرهای مشترک، چت‌های مستمر، حساب مشترک بانکی'),
    ('Police Clearance Certificate (Govahi Su-e Pishineh)', 'گواهی عدم سوءپیشینه کیفری متقاضی', 'legal', true, true, true, true, 'اخذ از دفاتر خدمات الکترونیک انتظامی پلیس +۱۰ و تایید سامانه میخک / دادگستری'),
    ('Medical Examination & Immunization Record', 'معاینات پزشکی، آزمایشات عفونی و کارت بین‌المللی واکسیناسیون', 'medical', true, false, false, false, 'باید توسط پزشک معتمد سفارت (Panel Physician) در تهران یا کشور واسط صادر شود'),
    ('Sponsor Proof of Financial Means / Tax Returns', 'مدارک تمکن مالی، قرارداد کار و اظهارنامه مالیاتی اسپانسر', 'financial', true, false, true, true, 'تکس ریترن سال‌های گذشته، فیش حقوقی ۳ تا ۶ ماه اخیر و صورتحساب بانکی')
) AS d(name_en, name_fa, cat, mandatory, apostille, trans, off_trans, notes);

-- ============================================================================
-- 6. Insert Processing Stages Info (مراحل و زمان‌بندی)
-- ============================================================================
INSERT INTO processing_info (program_id, stage_name_en, stage_name_fa, typical_duration_weeks, min_duration_weeks, max_duration_weeks, stage_order, notes)
SELECT id, 'Petition & Document Submission', 'تشکیل پرونده، ثبت پتیشن و بارگذاری اسناد اولیه', 4, 2, 8, 1, 'ثبت الکترونیکی درخواست در پورتال اداره مهاجرت کشور مقصد'
FROM family_visa_programs;

INSERT INTO processing_info (program_id, stage_name_en, stage_name_fa, typical_duration_weeks, min_duration_weeks, max_duration_weeks, stage_order, notes)
SELECT id, 'Biometrics & In-person Identity Verification', 'انگشت‌نگاری بیومتریک و احراز هویت حضوری', 6, 2, 16, 2, 'مراجعه به سفارت یا مرکز وک (VAC/VFS/VisaMetric) در تهران یا کشورهای همسایه'
FROM family_visa_programs;

INSERT INTO processing_info (program_id, stage_name_en, stage_name_fa, typical_duration_weeks, min_duration_weeks, max_duration_weeks, stage_order, notes)
SELECT id, 'Security Clearance & Background Vetting', 'بررسی‌های امنیتی، سوابق خدمت سربازی و اصالت مدارک', 16, 6, 40, 3, 'طولانی‌ترین مرحله برای متقاضیان ایرانی شامل کلیرنس امنیتی، سوابق دانشگاهی و نظامی'
FROM family_visa_programs;

INSERT INTO processing_info (program_id, stage_name_en, stage_name_fa, typical_duration_weeks, min_duration_weeks, max_duration_weeks, stage_order, notes)
SELECT id, 'Consular Interview & Visa Issuance', 'مصاحبه حضوری در کنسولگری و الصاق لیبل ویزا', 4, 1, 12, 4, 'حضور در مصاحبه نهایی، ارائه اصل مدارک و تحویل پاسپورت جهت ویزا یا صدور COPR'
FROM family_visa_programs;

-- ============================================================================
-- 7. Insert Iranian Applicant Specific Notes (نکات تحریم، سفارت‌های واسط و هشدارهای امنیتی)
-- ============================================================================

-- USA Notes
INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'embassy', 'سفارت‌های اصلی مصاحبه ویزای مهاجرتی آمریکا برای ایرانیان',
'با توجه به تعطیلی سفارت آمریکا در تهران، پرونده‌های مهاجرتی خانوادگی ایرانیان در مرکز ملی ویزا (NVC) به صورت پیش‌فرض به یکی از ۳ پست کنسولی ایروان (ارمنستان)، آنکارا (ترکیه) یا ابوظبی/دبی (امارات) ارجاع داده می‌شود. ایروان به دلیل داشتن افسران و مترجمان مسلط به فارسی و سهولت سفر بدون ویزا برای ایرانیان، مقصد اول بسیاری از خانواده‌هاست.',
ARRAY['Armenia', 'Turkey', 'United Arab Emirates'], CURRENT_DATE, 'info'
FROM family_visa_programs WHERE program_code IN ('US_IR1_CR1', 'US_F2A', 'US_K1');

INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'sanctions', 'تحریم‌های بانکی و نحوه پرداخت فی پتیشن و مدیکال',
'کارت‌های بانکی عضو شتاب در درگاه‌های CEAC / Pay.gov کار نمی‌کنند. پرداخت هزینه‌های NVC ($325) و پتیشن باید توسط اسپانسر مقیم آمریکا از طریق حساب بانکی معتبر آمریکا انجام شود. همچنین هزینه‌های آزمایشات مدیکال در ایروان/آنکارا باید به صورت اسکناس دلار نقد یا لیر/درام پرداخت گردد.',
ARRAY['Armenia', 'Turkey', 'United Arab Emirates'], CURRENT_DATE, 'warning'
FROM family_visa_programs WHERE program_code IN ('US_IR1_CR1', 'US_F2A', 'US_K1');

INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'warning', 'کلیرنس امنیتی (Administrative Processing 221g) و خدمت سربازی',
'متقاضیان ذکور ایرانی که خدمت سربازی را در ارگان‌های خاص گذرانده‌اند یا دارای مدارک دانشگاهی در رشته‌های حساس (فناوری‌های دوگانه TAL) هستند، وارد پروسه کلیرنس امنیتی AP 221g می‌شوند که ممکن است بررسی پرونده را بین ۲ تا ۱۲ ماه طولانی‌تر کند. تکمیل دقیق فرم DS-5535 بسیار حیاتی است.',
ARRAY['Armenia', 'Turkey', 'United Arab Emirates'], CURRENT_DATE, 'warning'
FROM family_visa_programs WHERE program_code IN ('US_IR1_CR1', 'US_F2A', 'US_K1');

-- Canada Notes
INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'embassy', 'مراکز بیومتریک و انگشت‌نگاری (VAC) کانادا برای ایرانیان',
'کلیه مراحل بررسی پرونده‌های اسپانسرشیپ همسر و والدین کانادا به صورت آنلاین در پورتال IRCC انجام می‌شود. متقاضی پس از دریافت نامه Biometric Instruction Letter ظرف ۳۰ روز باید برای انگشت‌نگاری به یکی از مراکز VAC VFS در استانبول، آنکارا، ایروان، دبی، باکو یا اربیل مراجعه نماید.',
ARRAY['Turkey', 'Armenia', 'United Arab Emirates', 'Georgia', 'Azerbaijan'], CURRENT_DATE, 'info'
FROM family_visa_programs WHERE program_code IN ('CA_SPOUSAL', 'CA_PGP');

INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'additional_documents', 'ترجمه رسمی شناسنامه و احراز رابطه واقعی در کانادا',
'شناسنامه ایرانی حتماً باید با تمام توضیحات و تغییرات قانونی ترجمه رسمی شود. اداره مهاجرت کانادا نسبت به ازدواج‌های صوری (Marriages of Convenience) حساسیت بالایی دارد؛ فلذا ارائه ادله کافی اعم از مستندات سفر مشترک، مراسم عقد و مکالمات روزمره الزامی است.',
ARRAY[]::TEXT[], CURRENT_DATE, 'info'
FROM family_visa_programs WHERE program_code = 'CA_SPOUSAL';

-- Germany Notes
INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'embassy', 'سیستم نوبت‌دهی ویزامتریک و سفارت آلمان در تهران',
'درخواست‌های پیوست به خانواده آلمان مستقیماً از طریق کارگزار رسمی سفارت آلمان در تهران (شرکت ویزامتریک VisaMetric) ثبت می‌شود. با توجه به حجم متقاضیان، صف نوبت مصاحبه ممکن است چندین ماه تا بیش از یک سال زمان ببرد. متقاضیان باید بلافاصله پس از ثبت نام در لیست انتظار ثبت‌نام کنند.',
ARRAY['Germany', 'Iran'], CURRENT_DATE, 'warning'
FROM family_visa_programs WHERE program_code IN ('DE_FAMILY_27_36', 'DE_SPOUSE');

INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'workaround', 'تاییدیه مدارک تحصیلی و اسناد در سفارت آلمان (Legalization)',
'به دلیل عدم عضویت ایران در معاهده آپوستیل برای کشور آلمان، کلیه اسناد هویتی و ازدواج باید پس از ترجمه به زبان آلمانی با مهرهای دادگستری و امور خارجه، توسط باجه تایید مدارک ویزامتریک/سفارت آلمان در تهران لگالایز (تصدیق اصالت) شوند.',
ARRAY[]::TEXT[], CURRENT_DATE, 'info'
FROM family_visa_programs WHERE program_code IN ('DE_FAMILY_27_36', 'DE_SPOUSE');

-- UK Notes
INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'embassy', 'مرکز وک VFS تهران و مراکز استانبول/دبی برای ویزای انگلیس',
'سفارت بریتانیا در تهران از طریق مرکز VFS خدمات بیومتریک و تحویل مدارک ارائه می‌دهد. متقاضیان همچنین می‌توانند در صورت تمایل، بیومتریک خود را در شعب ترکیه (استانبول/آنکارا) یا امارات (دبی/ابوظبی) ثبت کنند. در تهران پرداخت هزینه‌های ویزا و بیمه سلامت NHS (£1,035 در سال) فقط از طریق کارت‌های اعتباری بین‌المللی انجام‌پذیر است.',
ARRAY['Turkey', 'United Arab Emirates'], CURRENT_DATE, 'info'
FROM family_visa_programs WHERE program_code IN ('UK_FLRM', 'UK_FAMILY');

INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'additional_documents', 'آزمون سل ریوی (TB Test) در کلینیک مجاز IOM تهران',
'متقاضیان ویزای اقامتی بالای ۶ ماه بریتانیا مقیم ایران موظف به انجام تست توبرکلوز (سل) و دریافت گواهی از کلینیک بین‌المللی سازمان مهاجرت (IOM) در بیمارستان دی یا بیمارستان گاندی تهران هستند.',
ARRAY[]::TEXT[], CURRENT_DATE, 'info'
FROM family_visa_programs WHERE program_code IN ('UK_FLRM', 'UK_FAMILY');

-- Turkey Notes
INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'tip', 'دسترسی مستقیم بدون نیاز به ویزای ورود برای ایرانیان',
'ایرانیان بدون نیاز به دریافت ویزا حق اقامت توریستی ۹۰ روزه در ترکیه دارند و می‌توانند در طول این مدت مستقیماً در سامانه اداره مهاجرت ترکیه (e-ikamet) برای اقامت خانوادگی ثبت نام کرده و در استان محل اقامت راندوو (نوبت مصاحبه) دریافت کنند.',
ARRAY[]::TEXT[], CURRENT_DATE, 'info'
FROM family_visa_programs WHERE program_code IN ('TR_FAMILY_RES', 'TR_SPOUSE');

INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'sanctions', 'مسدودی و محدودیت‌های افتتاح حساب بانکی در ترکیه',
'به دلیل تحریم‌های FATF، افتتاح حساب بانکی برای اتباع ایرانی در بانک‌های دولتی نظیر زراعت بانک یا واقیف بانک نیازمند ارائه کارت کیملیک و شماره مالیاتی معتبر است. صرافی‌های مجاز و تراکنش‌های بانکی رسمی باید برای اثبات گردش مالی استفاده شوند.',
ARRAY[]::TEXT[], CURRENT_DATE, 'warning'
FROM family_visa_programs WHERE program_code IN ('TR_FAMILY_RES', 'TR_SPOUSE');

-- Netherlands Notes
INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'embassy', 'آزمون ادغام مدنی هلند در سفارت هلند در تهران',
'سفارت هلند در تهران آزمون ادغام مدنی خارج از کشور (Basisexamen Inburgering Buitenland) شامل آزمون‌های زبان هلندی، خواندن، صحبت کردن و دانش جامعه هلندی را برگزار می‌کند. قبولی در این آزمون پیش‌شرط صدور مجوز MVV برای همسران ۲۱ سال به بالاست.',
ARRAY['Iran', 'Turkey'], CURRENT_DATE, 'warning'
FROM family_visa_programs WHERE program_code = 'NL_MVV_TEV';

-- Australia Notes
INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'warning', 'بررسی‌های امنیتی طولانی و فرم ۸۰ برای استرالیا',
'تمامی متقاضیان بالای ۱۶ سال ایرانی ملزم به تکمیل دقیق فرم ۸۰ (Form 80) شامل کلیه سوابق سفر، آدرس‌ها، مشاغل و خدمت سربازی هستند. بررسی‌های امنیتی دپارتمان امور داخلی استرالیا (Home Affairs) به طور میانگین ۱۲ تا ۲۴ ماه زمان می‌برد.',
ARRAY[]::TEXT[], CURRENT_DATE, 'warning'
FROM family_visa_programs WHERE program_code IN ('AU_PARTNER_820_801', 'AU_PARENT_103_143');

-- UAE Notes
INSERT INTO iranian_applicant_notes (program_id, note_category, title_fa, content_fa, intermediate_countries, last_verified, severity)
SELECT id, 'tip', 'سرعت بالای پردازش و سهولت تصدیق مدارک در امارات',
'پروسه الحاق خانواده در امارات یکی از سریع‌ترین و روان‌ترین فرآیندها در جهان است. مدارک ازدواج و شناسنامه فقط باید به تایید وزارت امور خارجه ایران و سفارت امارات در تهران یا کنسولگری دبی برسد و پس از تایید آنلاین MOFA امارات ظرف چند روز ویزا صادر می‌شود.',
ARRAY[]::TEXT[], CURRENT_DATE, 'info'
FROM family_visa_programs WHERE program_code IN ('AE_FAMILY_RESIDENCE', 'AE_GOLDEN_FAMILY');

-- ============================================================================
-- 8. Insert Embassy Application Centers (مراکز انگشت‌نگاری و کنسولگری‌ها)
-- ============================================================================
INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Yerevan', 'Armenia', 'embassy', '1 American Ave, Yerevan 0082, Armenia', '+374 10 464700', 'https://am.usembassy.gov/', true, 8, 'مرکز اصلی و محبوب مصاحبه مهاجرتی ایرانیان با حضور افسران فارسی‌زبان'
FROM countries WHERE iso_code = 'USA';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Ankara', 'Turkey', 'embassy', '1480 Sok No:1 Çukurambar, Çankaya, Ankara, Turkey', '+90 312 294 0000', 'https://tr.usembassy.gov/', true, 16, 'کنسولگری فعال برای پرونده‌های مهاجرتی آمریکا با پروازهای منظم از تهران و تبریز'
FROM countries WHERE iso_code = 'USA';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Abu Dhabi', 'United Arab Emirates', 'embassy', 'Embassies District, Plot 38, Sector W59-02, Abu Dhabi, UAE', '+971 2 414 2200', 'https://ae.usembassy.gov/', true, 20, 'کنسولگری معتبر دیگر ویزاهای خانوادگی با ظرفیت رسیدگی بالا'
FROM countries WHERE iso_code = 'USA';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Istanbul', 'Turkey', 'vac', 'Hacıahmet Mah. Kurtuluş Deresi Cad. No:29 Beyoğlu, Istanbul', '+90 212 373 5807', 'https://visa.vfsglobal.com/tur/en/can/', true, 2, 'مرکز رسمی انگشت‌نگاری بیومتریک کانادا VFS Global استانبول'
FROM countries WHERE iso_code = 'CAN';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Yerevan', 'Armenia', 'vac', '10 Vazgen Sargsyan St, Yerevan, Armenia', '+374 60 700300', 'https://visa.vfsglobal.com/arm/en/can/', true, 1, 'مرکز وک کانادا در ایروان با دسترسی زمینی و هوایی سریع برای متقاضیان ایرانی'
FROM countries WHERE iso_code = 'CAN';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Tehran', 'Iran', 'vac', 'تهران، خیابان بهشتی، خیابان خالد اسلامبولی (وزرا)، نبش خیابان ۲۱، ساختمان شیراز، طبقه ۱', '+98 21 8870 0343', 'https://www.visametric.com/iran/Germany/fa', true, 24, 'مرکز رسمی دریافت مدارک ویزامتریک سفارت آلمان در تهران'
FROM countries WHERE iso_code = 'DEU';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Tehran', 'Iran', 'vac', 'تهران، میدان آرژانتین، خیابان الوند، خیابان راشل کوری، پلاک ۱۱، طبقه ۱ مرکز VFS Global', '+98 21 7298 6006', 'https://visa.vfsglobal.com/irn/en/gbr/', true, 4, 'مرکز ثبت بیومتریک و درخواست‌های ویزای بریتانیا در تهران'
FROM countries WHERE iso_code = 'GBR';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Tehran', 'Iran', 'embassy', 'تهران، فرمانیه، خیابان پاسداران، خیابان نسترن، نبش بوستان، پلاک ۲۷', '+98 21 2371 2200', 'https://www.swedenabroad.se/tehran', true, 12, 'سفارت سوئد در تهران - بخش مصاحبه‌های مهاجرت خانوادگی'
FROM countries WHERE iso_code = 'SWE';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Tehran', 'Iran', 'embassy', 'تهران، خیابان دیباجی شمالی، خیابان ارغوان غربی، شماره ۶۰', '+98 21 2366 0000', 'https://iran.embassy.gov.au/', true, 0, 'سفارت استرالیا در تهران (درخواست‌ها عمدتا آنلاین از طریق پورتال ImmiAccount ثبت می‌شود)'
FROM countries WHERE iso_code = 'AUS';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Tehran', 'Iran', 'vac', 'تهران، خیابان شریعتی، بالاتر از پل رومی، جنب مترو قیطریه، مجتمع دیبا، مرکز VFS Global France', '+98 21 7298 6004', 'https://visa.vfsglobal.com/irn/en/fra/', true, 6, 'مرکز انگشت‌نگاری و تحویل اسناد ویزای فرانسه در تهران'
FROM countries WHERE iso_code = 'FRA';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Tehran', 'Iran', 'vac', 'تهران، خیابان بهشتی، خیابان وزرا، نبش خیابان ۲۱، ساختمان شیراز، طبقه ۲ مرکز ویزامتریک ایتالیا', '+98 21 8870 0343', 'https://www.visametric.com/iran/Italy/fa', true, 8, 'مرکز رسمی کارگزاری ویزامتریک جهت تحویل نولا اوستا و اسناد ویزای ایتالیا'
FROM countries WHERE iso_code = 'ITA';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Tehran', 'Iran', 'vac', 'تهران، خیابان پاسداران، خیابان بوستان پنجم، پلاک ۲۳، مرکز کارگزاری BLS Spain', '+98 21 2670 1234', 'https://iran.blsspainvisa.com/', true, 8, 'مرکز رسمی انگشت‌نگاری و ثبت درخواست‌های ویزای اسپانیا در تهران'
FROM countries WHERE iso_code = 'ESP';

INSERT INTO embassy_application_centers (country_id, city_name, country_of_location, center_type, address, phone, website, accepts_iranians, appointment_wait_weeks, notes)
SELECT id, 'Dubai', 'United Arab Emirates', 'online', 'Dubai GDRFA Customer Happiness Centers / Amer Centers across Dubai', '+971 4 313 9999', 'https://gdrfad.gov.ae/', true, 1, 'مراکز خدمات عامر و اقامت دبی جهت صدور فوری ویزای اقامت خانواده'
FROM countries WHERE iso_code = 'ARE';

-- ============================================================================
-- 9. Insert Integration Requirements (الزامات ادغام، آزمون زبان و مسکن)
-- ============================================================================
INSERT INTO integration_requirements (program_id, requirement_name_en, requirement_name_fa, requirement_type, details, is_pre_arrival, is_post_arrival)
SELECT id, 'Goethe/Telc German A1 Certificate', 'مدرک زبان آلمانی سطح A1 گوته یا تلک', 'language_test',
'{"cert_required": "Goethe-Zertifikat A1: Start Deutsch 1 or telc Deutsch A1", "min_passing_score": "60%", "exemptions": "EU Blue Card spouses, university graduates with recognized degrees, or evident low integration need"}'::jsonb,
true, false
FROM family_visa_programs WHERE program_code IN ('DE_FAMILY_27_36', 'DE_SPOUSE');

INSERT INTO integration_requirements (program_id, requirement_name_en, requirement_name_fa, requirement_type, details, is_pre_arrival, is_post_arrival)
SELECT id, 'Dutch Civic Integration Abroad (Basisexamen Inburgering)', 'آزمون ادغام مدنی خارج از کشور هلند', 'civic_knowledge',
'{"exam_components": ["Spoken Dutch (KNS)", "Reading Comprehension (Leesvaardigheid)", "Knowledge of Dutch Society (Kennis van de Nederlandse Samenleving)"], "level": "A1 CEFR", "cost_eur": 150}'::jsonb,
true, false
FROM family_visa_programs WHERE program_code = 'NL_MVV_TEV';

INSERT INTO integration_requirements (program_id, requirement_name_en, requirement_name_fa, requirement_type, details, is_pre_arrival, is_post_arrival)
SELECT id, 'SELT English Language Test A1', 'مدرک زبان انگلیسی معتبر SELT سطح A1', 'language_test',
'{"approved_providers": ["IELTS Life Skills A1", "Pearson PTE Home A1", "LanguageCert International ESOL SELT A1"], "min_score": "Pass"}'::jsonb,
true, false
FROM family_visa_programs WHERE program_code = 'UK_FLRM';

INSERT INTO integration_requirements (program_id, requirement_name_en, requirement_name_fa, requirement_type, details, is_pre_arrival, is_post_arrival)
SELECT id, 'Housing Suitability Certificate (Idoneità Alloggiativa)', 'گواهی تطابق و استاندارد متراژ مسکن شهرداری ایتالیا', 'housing',
'{"issued_by": "Comune / ASL local health authority", "criteria": "Square footage per person, sanitation standard, compliance with municipal building codes"}'::jsonb,
true, false
FROM family_visa_programs WHERE program_code = 'IT_RICONGIUNGIMENTO';

INSERT INTO integration_requirements (program_id, requirement_name_en, requirement_name_fa, requirement_type, details, is_pre_arrival, is_post_arrival)
SELECT id, 'Contrat d''Intégration Républicaine (CIR)', 'قرارداد ادغام جمهوری فرانسه در سازمان OFII', 'civic_knowledge',
'{"mandatory_training": "Civic training days covering French history, values of the Republic, and institutional structure", "language_progression": "Target CEFR A2/B1 proficiency"}'::jsonb,
false, true
FROM family_visa_programs WHERE program_code = 'FR_REGROUPEMENT';

INSERT INTO integration_requirements (program_id, requirement_name_en, requirement_name_fa, requirement_type, details, is_pre_arrival, is_post_arrival)
SELECT id, 'UAE Mandatory Medical Fitness & Emirates ID', 'آزمایشات سلامت پزشکی و صدور کارت هویت امارات', 'health_insurance',
'{"blood_screening": ["HIV", "Hepatitis B & C (specific categories)"], "radiology": "Chest X-Ray for active Pulmonary Tuberculosis", "emirates_id": "Mandatory biometric capture for residence card"}'::jsonb,
false, true
FROM family_visa_programs WHERE program_code IN ('AE_FAMILY_RESIDENCE', 'AE_GOLDEN_FAMILY');

-- ============================================================================
-- 10. Insert Program Statistics (آمار واقع‌گرایانه پذیرش)
-- ============================================================================
INSERT INTO program_statistics (program_id, stat_year, stat_period, total_applications, total_approvals, approval_rate_pct, iranian_applications, iranian_approvals, avg_processing_months, source, notes)
SELECT id, 2023, 'annual', 85400, 78200, 91.56, 4120, 3680, 14.5, 'US Department of State / USCIS Immigrant Visa Statistics', 'نرخ قبولی بالا پس از عبور از مرحله کلیرنس امنیتی'
FROM family_visa_programs WHERE program_code = 'US_IR1_CR1';

INSERT INTO program_statistics (program_id, stat_year, stat_period, total_applications, total_approvals, approval_rate_pct, iranian_applications, iranian_approvals, avg_processing_months, source, notes)
SELECT id, 2023, 'annual', 72000, 64500, 89.58, 5200, 4750, 12.0, 'Immigration, Refugees and Citizenship Canada (IRCC) Open Data', 'یکی از پرتقاضاترین برنامه‌ها برای ایرانیان پس از ازدواج با شهروندان یا دارندگان پی‌آر'
FROM family_visa_programs WHERE program_code = 'CA_SPOUSAL';

INSERT INTO program_statistics (program_id, stat_year, stat_period, total_applications, total_approvals, approval_rate_pct, iranian_applications, iranian_approvals, avg_processing_months, source, notes)
SELECT id, 2023, 'annual', 124000, 108000, 87.10, 3800, 3350, 9.2, 'BAMF / Auswärtiges Amt Jahresstatistik', 'رشد درخواست‌های پیوست به دارندگان کارت آبی اروپا در سال‌های اخیر'
FROM family_visa_programs WHERE program_code = 'DE_FAMILY_27_36';

INSERT INTO program_statistics (program_id, stat_year, stat_period, total_applications, total_approvals, approval_rate_pct, iranian_applications, iranian_approvals, avg_processing_months, source, notes)
SELECT id, 2023, 'annual', 210000, 195000, 92.85, 24500, 22800, 2.5, 'Göç İdaresi Başkanlığı Yıllık Raporu', 'بزرگترین جامعه پذیرش اقامت خانوادگی برای متقاضیان ایرانی در منطقه'
FROM family_visa_programs WHERE program_code = 'TR_FAMILY_RES';

INSERT INTO program_statistics (program_id, stat_year, stat_period, total_applications, total_approvals, approval_rate_pct, iranian_applications, iranian_approvals, avg_processing_months, source, notes)
SELECT id, 2023, 'annual', 65000, 58000, 89.23, 1450, 1280, 8.4, 'UK Home Office Immigration Statistics', 'کاهش نسبی به دلیل افزایش آستانه مالی اسپانسر'
FROM family_visa_programs WHERE program_code = 'UK_FLRM';

INSERT INTO program_statistics (program_id, stat_year, stat_period, total_applications, total_approvals, approval_rate_pct, iranian_applications, iranian_approvals, avg_processing_months, source, notes)
SELECT id, 2023, 'annual', 42000, 37500, 89.28, 1600, 1390, 22.0, 'Australian Department of Home Affairs Migration Program Report', 'زمان طولانی بررسی به دلیل ارزیابی موشکافانه شواهد رابطه و کلیرنس'
FROM family_visa_programs WHERE program_code = 'AU_PARTNER_820_801';

INSERT INTO program_statistics (program_id, stat_year, stat_period, total_applications, total_approvals, approval_rate_pct, iranian_applications, iranian_approvals, avg_processing_months, source, notes)
SELECT id, 2023, 'annual', 450000, 442000, 98.22, 38000, 37200, 1.5, 'UAE Federal Authority for Identity & Citizenship (ICP)', 'بالاترین نرخ صدور و کوتاه‌ترین زمان پردازش در میان کشورهای هدف'
FROM family_visa_programs WHERE program_code = 'AE_FAMILY_RESIDENCE';

-- ============================================================================
-- 11. Insert Pathway Comparisons (مقایسه مسیر اقامت دائم و شهروندی)
-- ============================================================================
INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'US IR-1 / CR-1 Spousal Green Card', true, true, 0.0, 3.0,
'متقاضی به محض ورود با ویزای IR-1 یا CR-1 گرین‌کارت دریافت می‌کند. در صورت تداوم ازدواج با شهروند آمریکا، پس از ۳ سال واجد شرایط درخواست تابعیت (N-400) خواهد بود.'
FROM countries WHERE iso_code = 'USA';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'Canada Spousal Sponsorship', true, true, 0.0, 3.0,
'متقاضی به صورت مستقیم اقامت دائم (Permanent Resident) کانادا را کسب می‌کند و پس از ۳ سال حضور فیزیکی (۱۰۹۵ روز) در بازه ۵ ساله می‌تواند پاسپورت کانادایی دریافت کند.'
FROM countries WHERE iso_code = 'CAN';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'Germany Family Reunification AufenthG', true, true, 3.0, 5.0,
'همسر شهروند آلمان پس از ۳ سال و همسر دارندگان اقامت متخصصان پس از ۳ تا ۵ سال واجد شرایط اقامت دائم (Niederlassungserlaubnis) و بر اساس قانون جدید ۲۰۲۴ پس از ۵ سال (در شرایط خاص ۳ سال) واجد شرایط تابعیت آلمان است.'
FROM countries WHERE iso_code = 'DEU';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'Turkey Family Residence / Spouse', true, true, 8.0, 3.0,
'همسر تبعه ترکیه پس از ۳ سال زندگی مشترک می‌تواند تابعیت ترکیه را کسب کند؛ در سایر موارد اقامت دائم ترکیه (Uzun Dönem) پس از ۸ سال اقامت قانونی مستمر امکان‌پذیر است.'
FROM countries WHERE iso_code = 'TUR';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'Netherlands MVV Family Permit', true, true, 5.0, 5.0,
'پس از ۵ سال اقامت مستمر قانونی، قبولی در آزمون ادغام مدنی Inburgeringsexamen و اثبات تمکن، متقاضی می‌تواند برای اقامت دائم یا تابعیت هلند اقدام کند.'
FROM countries WHERE iso_code = 'NLD';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'UK Spouse Visa FLR(M)', true, true, 5.0, 5.0,
'ویزای اولیه به مدت ۳۳ ماه صادر شده و پس از تمدید ۳۰ ماهه (مجموعاً ۵ سال روی مسیر ۵ ساله)، متقاضی اقامت دائم ILR دریافت می‌کند و بلافاصله (در صورت ازدواج با تبعه بریتانیا) می‌تواند برای پاسپورت اقدام کند.'
FROM countries WHERE iso_code = 'GBR';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'Sweden Family Residence Permit', true, true, 4.0, 5.0,
'پس از تمدید مجوز اقامت و داشتن درآمد پایدار، متقاضی می‌تواند اقامت دائم (PUT) را دریافت کرده و پس از ۵ سال اقامت قانونی (در ازدواج با تبعه سوئد ۳ سال) شهروندی سوئد را کسب نماید.'
FROM countries WHERE iso_code = 'SWE';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'Australia Partner Visa 820/801', true, true, 2.0, 4.0,
'ویزای موقت ۸۲۰ پس از ۲ سال به ویزای اقامت دائم ۸۰۱ تبدیل می‌شود. متقاضی پس از گذشت حداقل ۱ سال از تاریخ اقامت دائم و ۴ سال زندگی در استرالیا واجد شرایط سیتیزن‌شیپ است.'
FROM countries WHERE iso_code = 'AUS';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'France Regroupement Familial / Conjoint', true, true, 5.0, 4.0,
'همسر شهروند فرانسه پس از ۴ سال زندگی مشترک و ارائه مدرک زبان فرانسوی B1 می‌تواند اعلام تابعیت (Déclaration de nationalité) کند؛ در سایر موارد پس از ۵ سال کارت اقامت ۱۰ ساله دائم صادر می‌شود.'
FROM countries WHERE iso_code = 'FRA';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'Italy Ricongiungimento Familiare', true, true, 5.0, 2.0,
'همسر تبعه ایتالیا پس از ۲ سال اقامت قانونی در ایتالیا (یا ۳ سال در صورت اقامت خارج از کشور) واجد شرایط تابعیت است. برای سایر اتباع خارجی پس از ۵ سال اقامت دائم (UE Soggiornanti di Lungo Periodo) صادر می‌شود.'
FROM countries WHERE iso_code = 'ITA';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'Spain Reagrupación Familiar', true, true, 5.0, 10.0,
'پس از ۵ سال اقامت موقت، کارت اقامت دائم ۵ ساله اسپانیا (Residencia de larga duración) صادر می‌شود. همسر شهروند اسپانیا تنها پس از ۱ سال اقامت قانونی می‌تواند برای پاسپورت اسپانیایی اقدام کند.'
FROM countries WHERE iso_code = 'ESP';

INSERT INTO pathway_comparisons (country_id, from_visa_type, to_pr_possible, to_citizenship_possible, min_years_to_pr, min_years_to_citizenship, notes)
SELECT id, 'UAE Family / Golden Visa Residence', false, false, NULL, NULL,
'اقامت امارات یک اقامت موقت قابل تمدید دائمی است (۱ تا ۲ سال برای ویزای عادی و ۱۰ سال برای گلدن ویزا). مسیر رسمی دریافت اقامت دائم یا پاسپورت اماراتی از طریق اسپانسرشیپ خانوادگی وجود ندارد اما امکان تمدید نامحدود فراهم است.'
FROM countries WHERE iso_code = 'ARE';

-- ============================================================================
-- END OF DATABASE SCRIPT
-- ============================================================================
