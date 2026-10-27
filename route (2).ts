import { NextResponse } from 'next/server';
import type { AssessmentReport, WizardData } from '@/types/wizard';
import { autoMigrate } from '@/lib/autoMigrate';
import { pool } from '@/lib/db';
import { OFFICIAL_DIRECTORIES } from '@/lib/constants';

type OfficialModule = {
  country: string;
  group_id: string;
  requirements: string[];
  min_score: number | null;
  processing_time: string | null;
  official_source_url: string;
  strategy_advice: string[];
};

type ReportLink = { title: string; url: string; kind: string };

async function getOfficialContext(data: WizardData): Promise<{ modules: OfficialModule[]; links: ReportLink[] }> {
  const selected = Array.from(
    new Set((data.countries || []).filter((c): c is string => typeof c === 'string' && Boolean(OFFICIAL_DIRECTORIES[c])))
  );
  const links = selected.flatMap((country) => OFFICIAL_DIRECTORIES[country] || []);
  if (!process.env.DATABASE_URL || !selected.length || !data.group) return { modules: [], links };

  try {
    await autoMigrate();
    const result = await pool.query(
      `SELECT country, group_id, requirements, min_score, processing_time, official_source_url, strategy_advice
       FROM migration_modules
       WHERE country = ANY($1::text[]) AND group_id = $2
       ORDER BY country`,
      [selected, data.group]
    );
    return { modules: result.rows as OfficialModule[], links };
  } catch (error) {
    console.error('Official migration data unavailable:', error instanceof Error ? error.message : error);
    return { modules: [], links };
  }
}

export const runtime = 'nodejs';

const fallback = (links: ReportLink[]): AssessmentReport => ({
  type: 'paid_report',
  chance: 72,
  summary: 'گزارش کامل بر اساس اطلاعات اولیه تهیه شده است؛ شرایط رسمی را پیش از اقدام بررسی کنید.',
  strengths: ['هدف مشخص', 'قابلیت تطبیق مسیر با سوابق'],
  weaknesses: ['نیاز به بررسی جزئیات مدارک', 'الزامات ممکن است تغییر کند'],
  pathways: ['بررسی مسیر مناسب در پورتال رسمی'],
  steps: [
    'تکمیل رزومه و جمع‌آوری مدارک هویتی و تحصیلی',
    'بررسی شرط زبان، تمکن و سابقه در صفحه رسمی مسیر',
    'انجام ارزیابی مدرک یا مهارت در صورت نیاز',
    'ساخت حساب در پورتال رسمی و تکمیل فرم‌ها',
    'بازبینی مدارک و پیگیری وضعیت درخواست از مسیر رسمی'
  ],
  checklist: [
    'پاسپورت معتبر',
    'ترجمه رسمی مدارک و سوابق',
    'مدرک زبان معتبر در صورت الزام',
    'مدارک تمکن مالی و سابقه کاری',
    'آخرین چک‌لیست اداره مهاجرت'
  ],
  timeline: [
    'زمان‌بندی رسمی در داده تأییدشده این بسته موجود نیست؛ زمان جاری را از پورتال رسمی کشور انتخابی بررسی کنید.'
  ],
  officialLinks: links
});

async function ai(data: WizardData, official: unknown) {
  const key = process.env.LIARA_AI_API_KEY;
  if (!key) return null;
  try {
    const response = await fetch(process.env.LIARA_AI_ENDPOINT || 'https://api.liara.ir/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
      body: JSON.stringify({
        model: process.env.LIARA_AI_MODEL || 'openai/gpt-4o-mini',
        temperature: 0.2,
        messages: [
          {
            role: 'system',
            content: 'گزارش کامل فارسی را به‌صورت JSON با فیلدهای summary, strengths, weaknesses, pathways, steps, checklist, timeline تولید کن. فقط بر facts رسمی ارائه‌شده تکیه کن؛ هرگز شرط، حدنصاب یا زمان ناموجود را جعل نکن و برای موارد نامعلوم ارجاع به منبع رسمی بده.'
          },
          { role: 'user', content: JSON.stringify({ applicant: data, official_facts: official }) }
        ]
      })
    });
    if (!response.ok) return null;
    const json = await response.json();
    return json?.choices?.[0]?.message?.content || null;
  } catch {
    return null;
  }
}

/**
 * فعلاً پرداخت غیرفعال است. این endpoint مستقیماً گزارش کامل را تولید می‌کند
 * و برای سازگاری با نسخه قبلی، order_id و payment_ref ارسالی را نادیده می‌گیرد.
 */
export async function POST(request: Request) {
  try {
    const body = await request.json() as { order_id?: string; data?: WizardData };
    const data = body.data || {};
    const official = await getOfficialContext(data);
    const report = fallback(official.links);
    report.countryModules = official.modules.map((module) => ({
      country: module.country, requirements: Array.isArray(module.requirements) ? module.requirements : [],
      min_score: module.min_score, processing_time: module.processing_time,
      official_source_url: module.official_source_url,
      strategy_advice: Array.isArray(module.strategy_advice) ? module.strategy_advice : []
    }));
    const text = await ai(data, official.modules);

    if (text) {
      try {
        const parsed = JSON.parse(text);
        Object.assign(report, parsed, { type: 'paid_report', officialLinks: official.links, countryModules: report.countryModules });
      } catch {
        // Keep the safe deterministic fallback when the model returns malformed JSON.
      }
    }

    return NextResponse.json({
      success: true,
      unlocked: true,
      payment_required: false,
      order_id: body.order_id || null,
      report
    });
  } catch {
    return NextResponse.json({ success: false, error: 'درخواست نامعتبر است.' }, { status: 400 });
  }
}
