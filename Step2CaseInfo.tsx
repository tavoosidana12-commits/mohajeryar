"use client";
import type { WizardData } from '@/types/wizard';

const conditional: Record<string, [string, string, string][]> = {
  study: [['education','آخرین مدرک تحصیلی','مثلاً کارشناسی'],['field','رشتهٔ تحصیلی','مثلاً مهندسی کامپیوتر']],
  work: [['job','عنوان شغلی','مثلاً برنامه‌نویس'],['experience','سابقهٔ کار (سال)','مثلاً ۵']],
  investment: [['capital','بودجهٔ تقریبی','مثلاً ۱۰۰ هزار دلار'],['business','سابقهٔ کسب‌وکار','توضیح کوتاه']],
  family: [['relative','نسبت عضو خانواده','مثلاً همسر یا والد'],['country','کشور محل اقامت عضو خانواده','مثلاً کانادا']],
  talent: [['field','حوزهٔ تخصص','مثلاً هنر یا ورزش'],['achievement','دستاوردهای مهم','توضیح کوتاه']],
  startup: [['idea','حوزهٔ ایدهٔ کسب‌وکار','توضیح کوتاه'],['funding','بودجهٔ اولیه','مبلغ تقریبی']],
  visit: [['purpose','هدف سفر','مثلاً گردشگری'],['duration','مدت اقامت','مثلاً دو هفته']],
  other: [['interest','مسیر موردنظر','توضیح کوتاه'],['notes','توضیحات بیشتر','اختیاری']],
};
const languageOptions = ['IELTS', 'TOEFL', 'سایر'];

export default function Step2CaseInfo({data,update,errors}:{data:WizardData;update:(v:Partial<WizardData>)=>void;errors:Record<string,string>}) {
  const fields = [
    ['applicant_name_fa','نام و نام خانوادگی فارسی','مثلاً سارا احمدی','text'],
    ['city_country_en','شهر و کشور محل سکونت','مثلاً Tehran, Iran','text'],
  ];
  const languageScore = data.languageScore ?? data.details?.language ?? '';
  const change = (key:string,value:string) => update({details:{...data.details,[key]:value}});
  const showLanguage = data.group === 'study' || data.group === 'work';
  return <section>
    <h2>اطلاعات متقاضی و شرایط پرونده</h2>
    <div className="fields">
      {fields.map(([key,label,placeholder,type]) => <div className="field" key={key}>
        <label htmlFor={key}>{label}</label>
        <input id={key} type={type} placeholder={placeholder} className={['city_country_en'].includes(key)?'ltr':''}
          value={(data as Record<string,any>)[key]||''} onChange={e=>update({[key]:e.target.value})}/>
        {errors[key]&&<small className="error">{errors[key]}</small>}
      </div>)}
      <div className="field"><label htmlFor="age">سن</label><input id="age" type="number" min="16" max="100" placeholder="مثلاً ۲۸" value={data.age||''} onChange={e=>update({age:e.target.value})}/>{errors.age&&<small className="error">{errors.age}</small>}</div>
      <div className="field"><label htmlFor="marital_status">وضعیت تأهل</label><select id="marital_status" value={data.marital_status||''} onChange={e=>update({marital_status:e.target.value})}><option value="">انتخاب کنید</option><option>مجرد</option><option>متأهل</option><option>سایر</option></select>{errors.marital_status&&<small className="error">{errors.marital_status}</small>}</div>
    </div>
    <h3>اطلاعات تکمیلی مسیر {data.group&&({study:'تحصیلی',work:'کاری',investment:'سرمایه‌گذاری',family:'خانوادگی',talent:'استعداد ویژه',startup:'استارتاپ',visit:'توریستی',other:'انتخابی'} as Record<string,string>)[data.group]}</h3>
    <div className="fields">
      {(conditional[data.group||'other']||conditional.other).map(([key,label,placeholder])=><div className="field" key={key}><label htmlFor={key}>{label}</label><input id={key} value={data.details?.[key]||''} placeholder={placeholder} onChange={e=>change(key,e.target.value)}/></div>)}
      {showLanguage&&<>
        <fieldset className="field" style={{border:0,padding:0,margin:0}}>
          <legend>آزمون‌های زبان (امکان انتخاب چند مورد)</legend>
          {languageOptions.map(option=><label key={option} style={{display:'inline-flex',alignItems:'center',gap:6,marginInlineEnd:16}}><input type="checkbox" checked={(data.languageTests||[]).includes(option)} onChange={e=>{const selected=data.languageTests||[];update({languageTests:e.target.checked?[...selected,option]:selected.filter(item=>item!==option)});}}/>{option}</label>)}
        </fieldset>
        <div className="field"><label htmlFor="languageScore">نمره یا سطح زبان</label><input id="languageScore" value={languageScore} placeholder="مثلاً IELTS 6.5 یا سطح B2" onChange={e=>update({languageScore:e.target.value})}/></div>
      </>}
    </div>
  </section>;
}
