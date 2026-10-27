"use client";
import { BriefcaseBusiness, ChartNoAxesCombined, Compass, GraduationCap, Plane, Rocket, Shield, Sparkles, UsersRound } from 'lucide-react';
import { GROUPS } from '@/lib/constants';
import type { WizardData } from '@/types/wizard';
const icons=[GraduationCap,BriefcaseBusiness,ChartNoAxesCombined,UsersRound,Sparkles,Rocket,Plane,Compass];
export default function Step1Group({data,update,error}:{data:WizardData;update:(v:Partial<WizardData>)=>void;error?:string}){return <section><h2>کدام مسیر مهاجرتی برای شما مناسب‌تر است؟</h2><p className="hint">یک گزینه را انتخاب کنید. در مرحلهٔ بعد چند سؤال متناسب با انتخاب شما می‌پرسیم.</p><div className="grid">{GROUPS.map((g,i)=>{const Icon=icons[i];return <button type="button" key={g.id} className={'group-card '+(data.group===g.id?'selected':'')} onClick={()=>update({group:g.id})}><Icon size={25}/><strong>{g.title}</strong><small>{g.description}</small></button>})}</div>{error&&<p className="error">{error}</p>}</section>}
