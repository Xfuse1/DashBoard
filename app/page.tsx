export default function HomePage() {
  return (
    <div style={{ display: 'grid', gap: 16 }}>
      <section className="card">
        <h2>Welcome</h2>
        <p>
          This is a Next.js port that reuses the same data model and env
          variables. Use the Credit page to manage balance, ledger, and Kashier
          payments.
        </p>
        <p>
          Go to <a href="/payments/credit">Credit</a>.
        </p>
      </section>
    </div>
  );
}

