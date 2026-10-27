import { z } from 'zod';
export const groupSchema=z.object({group:z.string({required_error:'لطفاً یک مسیر را انتخاب کنید.'}).min(1,'لطفاً یک مسیر را انتخاب کنید.')});
export const infoSchema=z.object({applicant_name_fa:z.string().trim().min(2,'نام فارسی را وارد کنید.'),city_country_en:z.string().trim().min(2,'شهر و کشور محل سکونت را وارد کنید.'),age:z.string().min(1,'سن را انتخاب کنید.'),marital_status:z.string().min(1,'وضعیت تأهل را انتخاب کنید.')});
export const countriesSchema=z.object({countries:z.array(z.string()).length(3,'دقیقاً سه کشور را انتخاب کنید.')});
