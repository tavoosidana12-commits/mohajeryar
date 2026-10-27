export type GroupId = 'study'|'work'|'investment'|'family'|'talent'|'startup'|'visit'|'other';
export type ReportLink={title:string;url:string;kind:string};
export type CountryModule={country:string;requirements:string[];min_score:number|null;processing_time:string|null;official_source_url:string;strategy_advice:string[]};
export type CountryAssessment={country:string;chance:number;calculation:string[]};
export type AssessmentReport={countryModules?:CountryModule[];countryAssessments?:CountryAssessment[];type:'free_report'|'paid_report';chance:number;summary:string;strengths:string[];weaknesses:string[];pathways:string[];steps?:string[];checklist?:string[];timeline?:string[];officialLinks?:ReportLink[]};
export type WizardData = { group?: GroupId; applicant_name_fa?: string; city_country_en?: string; languageTests?: string[]; languageScore?: string; age?: string; marital_status?: string; details?: Record<string,string>; countries?: string[]; paid_cv?: boolean; paid_sop?: boolean; privacy?: boolean; bot_check?: string };
