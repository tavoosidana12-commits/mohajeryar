import { NextResponse } from 'next/server';
import { randomUUID } from 'node:crypto';
import type { WizardData, AssessmentReport } from '@/types/wizard';
import { autoMigrate } from '@/lib/autoMigrate';
import { pool } from '@/lib/db';
import { OFFICIAL_DIRECTORIES } from '@/lib/constants';

type OfficialModule = { country: string; group_id: string; requirements: string[]; min_score: number | null; processing_time: string | null; official_source_url: string; strategy_advice: string[] };
async function getOfficialContext(data: WizardData): Promise<{ modules: OfficialModule[]; links: {title:string;url:string;kind:string}[] }> {
  const selected = Array.from(new Set((data.countries || []).filter((c): c is string => typeof c === 'string' && Boolean(OFFICIAL_DIRECTORIES[c]))));
  const links = selected.flatMap((country) => OFFICIAL_DIRECTORIES[country] || []);
  if (!process.env.DATABASE_URL || !selected.length || !data.group) return { modules: [], links };
  try {
    await autoMigrate();
    const result = await pool.query(`SELECT country, group_id, requirements, min_score, processing_time, official_source_url, strategy_advice
      FROM migration_modules WHERE country = ANY($1::text[]) AND group_id = $2 ORDER BY country`, [selected, data.group]);
    return { modules: result.rows as OfficialModule[], links };
  } catch (error) {
    console.error('Official migration data unavailable:', error instanceof Error ? error.message : error);
    return { modules: [], links };
  }
}

export const runtime = 'nodejs';
const preview = (d: WizardData): AssessmentReport => {
  const countries = d.countries || [];
  const age = Number(d.age || 0);
  const routeFields: Record<string,string[]> = {
    study:['education','field'],work:['job','experience'],investment:['capital','business'],family:['relative','country'],talent:['field','achievement'],startup:['idea','funding'],visit:['purpose','duration'],other:['interest','notes']
  };
  const required = routeFields[d.group || 'other'] || routeFields.other;
  const provided = required.filter((key) => Boolean(d.details?.[key]?.trim())).length;
  const items = [
    { label:'امتیاز پایه', points:50 },
    { label:'سن ۱۸ تا ۳۵ سال', points: age >= 18 && age <= 35 ? 10 : age >= 36 && age <= 45 ? 5 : 0 },
    { label:'تناسب مسیر و اطلاعات تکمیلی', points: Math.round((provided / required.length) * 15) },
    { label:'اطلاعات زبان', points: (d.languageTests?.length && d.languageScore?.trim()) ? 10 : (d.languageTests?.length || d.languageScore?.trim()) ? 5 : 0 },
    { label:'تکمیل اطلاعات پایه', points: (d.applicant_name_fa?.trim() && d.city_country_en?.trim() && d.marital_status && d.age) ? 15 : 0 }
  ];
  const score = Math.min(100, items.reduce((sum, item) => sum + item.points, 0));
  const calculation = items.map((item) => `${item.label}: ${item.points}%`);
  const countryAssessments = countries.map((country) => ({ country, chance: score, calculation }));
  return { type:'free_report', chance:score, countryAssessments, summary:'این شاخص با جمع امتیازهای مشخص‌شده در تفکیک هر کشور محاسبه شده است؛ عدد ارائه‌شده احتمال واقعی پذیرش یا تضمین نتیجه نیست.', strengths:['مسیر و مقصدهای انتخابی مشخص شده‌اند','محاسبه بر اساس اطلاعات ثبت‌شده و فرمول شفاف انجام شده است'], weaknesses:['امتیاز آمادگی جایگزین ارزیابی رسمی کشور مقصد نیست','الزامات و نتیجه واقعی به بررسی مدارک و شرایط روز وابسته است'], pathways: countries.map(c => `${c}: بررسی مسیر ${d.group === 'study' ? 'تحصیلی' : d.group === 'work' ? 'کاری' : 'متناسب با شرایط'} در منبع رسمی`) };
};
async function ai(d: WizardData, official: unknown) {
  const key = process.env.LIARA_AI_API_KEY;
  if (!key) return null;
  try {
    const r = await fetch(process.env.LIARA_AI_ENDPOINT || 'https://api.liara.ir/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json',Authorization:`Bearer ${key}`}, body:JSON.stringify({model:process.env.LIARA_AI_MODEL || 'openai/gpt-4o-mini',temperature:.2,messages:[{role:'system',content:'پیش‌نمایش فارسی کوتاه تولید کن. تنها summary را برگردان. فقط از facts رسمی داده‌شده استفاده کن؛ اطلاعات ناموجود مانند حدنصاب یا زمان را حدس نزن و تصریح کن که باید در منبع رسمی بررسی شود.'},{role:'user',content:JSON.stringify({applicant:d,official_facts:official})}]}) });
    if (!r.ok) return null; const j = await r.json(); return j?.choices?.[0]?.message?.content || null;
  } catch { return null; }
}
export async function POST(request: Request) {
  try {
    const body = await request.json() as WizardData & {bot_check?:string};
    if (body.bot_check) return NextResponse.json({success:false,error:'درخواست نامعتبر است.'},{status:400});
    const official = await getOfficialContext(body);
    const report = preview(body); const text = await ai(body, official.modules);
    if (text) report.summary = text;
    return NextResponse.json({success:true,order_id:`AI-${randomUUID()}`,report},{status:201});
  } catch { return NextResponse.json({success:false,error:'بدنهٔ درخواست نامعتبر است.'},{status:400}); }
}
