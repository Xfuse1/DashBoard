import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Dashboard (Next.js) — Credit',
  description: 'Next.js port of the credit dashboard',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="container">
          <header className="appHeader">
            <h1>Dashboard</h1>
            <nav>
              <a href="/">Home</a>
              <a href="/payments/credit">Credit</a>
            </nav>
          </header>
          <main>{children}</main>
        </div>
      </body>
    </html>
  );
}

