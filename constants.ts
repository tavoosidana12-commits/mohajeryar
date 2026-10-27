export const GROUPS = [
 {id:'study',title:'تحصیلی',description:'ادامه تحصیل در دانشگاه‌ها و مراکز آموزشی',icon:'GraduationCap'},
 {id:'work',title:'کاری',description:'پیدا کردن فرصت شغلی و مهاجرت کاری',icon:'BriefcaseBusiness'},
 {id:'investment',title:'سرمایه‌گذاری',description:'مسیرهای سرمایه‌گذاری و کارآفرینی',icon:'ChartNoAxesCombined'},
 {id:'family',title:'خانوادگی',description:'پیوستن به اعضای خانواده در خارج از کشور',icon:'UsersRound'},
 {id:'talent',title:'استعداد ویژه',description:'مسیرهای تخصصی برای افراد توانمند',icon:'Sparkles'},
 {id:'startup',title:'استارتاپ',description:'راه‌اندازی کسب‌وکار نوآورانه',icon:'Rocket'},
 {id:'visit',title:'توریستی و کوتاه‌مدت',description:'سفر، بازدید یا اقامت کوتاه‌مدت',icon:'Plane'},
 {id:'other',title:'سایر مسیرها',description:'هنوز مسیر مناسب خود را انتخاب نکرده‌ام',icon:'Compass'}
] as const;
export const COUNTRIES = ['کانادا','آلمان','استرالیا','انگلستان','آمریکا','فرانسه','هلند','سوئد','ایتالیا','اسپانیا','ترکیه','امارات'];
export type OfficialLink={title:string;url:string;kind:'portal'|'evaluation'|'forms'};
export const OFFICIAL_DIRECTORIES:Record<string,OfficialLink[]>={
 'کانادا':[
  {title:'IRCC — مهاجرت و شهروندی کانادا',url:'https://www.canada.ca/en/services/immigration-citizenship.html',kind:'portal'},
  {title:'حساب امن IRCC و درخواست آنلاین',url:'https://www.canada.ca/en/immigration-refugees-citizenship/services/application/account.html',kind:'portal'},
  {title:'فرم‌ها و راهنماهای IRCC',url:'https://www.canada.ca/en/immigration-refugees-citizenship/services/application/application-forms-guides.html',kind:'forms'}],
 'آلمان':[
  {title:'Make it in Germany — پورتال رسمی',url:'https://www.make-it-in-germany.com/en/',kind:'portal'},
  {title:'Anabin — ارزیابی مدارک دانشگاهی',url:'https://anabin.kmk.org/anabin.html',kind:'evaluation'},
  {title:'Auswärtiges Amt — ویزای ملی',url:'https://www.auswaertiges-amt.de/en/visa-service/visa-navigator',kind:'forms'}],
 'استرالیا':[
  {title:'Department of Home Affairs',url:'https://immi.homeaffairs.gov.au/',kind:'portal'},
  {title:'SkillSelect — ابراز علاقه',url:'https://immi.homeaffairs.gov.au/visas/working-in-australia/skillselect',kind:'portal'},
  {title:'VETASSESS — ارزیابی مهارت',url:'https://www.vetassess.com.au/',kind:'evaluation'}],
 'انگلستان':[
  {title:'GOV.UK — ویزا و مهاجرت',url:'https://www.gov.uk/browse/visas-immigration',kind:'portal'},
  {title:'ثبت درخواست ویزا',url:'https://www.gov.uk/apply-to-come-to-the-uk',kind:'forms'}],
 'ایتالیا':[
  {title:'Visa for Italy — پورتال رسمی',url:'https://vistoperitalia.esteri.it/',kind:'portal'},
  {title:'وزارت امور خارجه ایتالیا',url:'https://www.esteri.it/en/',kind:'portal'}],
 'هلند':[
  {title:'IND — اداره مهاجرت هلند',url:'https://ind.nl/en',kind:'portal'},
  {title:'Netherlands Worldwide — ویزا',url:'https://www.netherlandsworldwide.nl/visa-the-netherlands',kind:'forms'}],
 'آمریکا':[
  {title:'USCIS — خدمات شهروندی و مهاجرت',url:'https://www.uscis.gov/',kind:'portal'},
  {title:'وزارت خارجه آمریکا — ویزا',url:'https://travel.state.gov/content/travel/en/us-visas.html',kind:'forms'}],
 'فرانسه':[{title:'France-Visas — پورتال رسمی',url:'https://france-visas.gouv.fr/en/',kind:'portal'}],
 'سوئد':[{title:'اداره مهاجرت سوئد — درخواست و راهنما',url:'https://www.migrationsverket.se/English.html',kind:'portal'},{title:'فرم‌ها و درخواست‌های اداره مهاجرت سوئد',url:'https://www.migrationsverket.se/English/Private-individuals.html',kind:'forms'}],
 'اسپانیا':[{title:'وزارت امور خارجه اسپانیا — خدمات کنسولی',url:'https://www.exteriores.gob.es/en/ServiciosAlCiudadano/Paginas/Consular/Servicios-consulares.aspx',kind:'portal'},{title:'اطلاعات و فرم‌های ویزای اسپانیا',url:'https://www.exteriores.gob.es/en/ServiciosAlCiudadano/Paginas/Consular/Visados.aspx',kind:'forms'}],
 'ترکیه':[{title:'اداره کل مدیریت مهاجرت ترکیه',url:'https://en.goc.gov.tr/',kind:'portal'},{title:'سامانه رسمی درخواست ویزای ترکیه',url:'https://www.evisa.gov.tr/en/',kind:'forms'}],
 'امارات':[{title:'پورتال رسمی دولت امارات — ویزا و ورود',url:'https://u.ae/en/information-and-services/visa-and-emirates-id',kind:'portal'},{title:'اداره فدرال هویت، شهروندی، گمرک و امنیت بندری',url:'https://icp.gov.ae/en/',kind:'forms'}]
};
