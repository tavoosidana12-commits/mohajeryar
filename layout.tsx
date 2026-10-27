import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = {
  title: 'مهاجریار | گزارش اقدام مهاجرتی',
  description: 'گزارش اقدام، چک‌لیست مدارک و پیوندهای رسمی مسیر مهاجرت به تفکیک کشور.',
};
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="fa" dir="rtl"><body>{children}</body></html>;
}
