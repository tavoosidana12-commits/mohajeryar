import Image from 'next/image';
import { CheckCircle2, ShieldCheck, Lock, ArrowDown } from 'lucide-react';
export default function Hero() {
  return <section className="hero"><div className="container hero-inner">
    <a className="brand" href="#top" aria-label="مهاجریار"><Image src="/logo.png" alt="لوگوی مهاجریار" width={104} height={104} priority/><span>همراه مطمئن مسیر تازهٔ شما</span></a>
    <span className="eyebrow">یک قدم تا شناخت مسیر مناسب شما</span>
    <h1>مسیر مهاجرت مناسب خودت را <span>پیدا کن</span></h1>
    <p className="hero-copy">با چند پاسخ ساده، اطلاعات اولیه‌ات را ثبت کن تا مسیرهای متناسب با شرایطت را بررسی کنیم. شروع ارزیابی رایگان است.</p>
    <div className="badges"><span className="badge"><CheckCircle2 size={18}/> ارزیابی اولیه رایگان</span><span className="badge"><ShieldCheck size={18}/> اطلاعات محرمانه</span><span className="badge"><Lock size={18}/> ثبت امن اطلاعات</span></div>
    <a className="btn hero-cta" href="#wizard"><span>شروع ارزیابی</span><ArrowDown size={18}/></a>
    <p className="hint hero-hint">این فرم صرفاً برای ارزیابی اولیه است و تضمینی برای دریافت ویزا یا پذیرش ایجاد نمی‌کند.</p>
  </div></section>
}
