"use client";

import { useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { createHostedPayment } from "@/lib/kashier";

type LedgerRow = {
  date: Date;
  type: string;
  amount: number;
  balanceAfter: number;
  reference: string;
  method: string;
  notes?: string;
  receipt?: string | null;
};

const RECEIPT_BUCKET = "receipts";

function sanitizeFileName(name: string) {
  return name.replace(/[^A-Za-z0-9._-]/g, "_");
}

function fmtDate(d?: Date) {
  if (!d) return "-";
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function methodPillClass(m: string) {
  if (m === "card") return "pill card";
  if (m === "bank") return "pill bank";
  if (m === "wallet") return "pill wallet";
  if (m === "promo") return "pill promo";
  return "pill";
}

export default function CreditPage() {
  // Balances
  const [balance, setBalance] = useState(250);
  const [reserved] = useState(30);
  const [creditLimit] = useState<number | null>(500);

  // Filters
  const [from, setFrom] = useState<string | "">("");
  const [to, setTo] = useState<string | "">("");
  const [type, setType] = useState("All");
  const [method, setMethod] = useState("All");
  const [search, setSearch] = useState("");

  // Pagination
  const [page, setPage] = useState(0);
  const pageSize = 8;

  const [rows, setRows] = useState<LedgerRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [topUpOpen, setTopUpOpen] = useState(false);
  const [kashierOpen, setKashierOpen] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  // Load initial mock rows and then try Supabase
  useEffect(() => {
    const mocks: LedgerRow[] = Array.from({ length: 12 }, (_, i) => {
      const d = new Date();
      d.setDate(d.getDate() - i * 3);
      const t = i % 3 === 0 ? "Top-up" : i % 3 === 1 ? "Spend" : "Promo";
      const amount = t === "Spend" ? -((i + 1) * 7) : (i + 1) * 10;
      return {
        date: d,
        type: t,
        amount,
        balanceAfter: 250 + i * 2,
        reference: `REF-${1000 + i}`,
        method: t === "Top-up" ? "card" : "wallet",
        notes: t === "Promo" ? "Promo: SAVE10" : "",
        receipt: t === "Top-up" ? `https://example.com/receipt/${1000 + i}` : null,
      };
    });
    setRows(mocks);
    void fetchFromSupabase();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function fetchFromSupabase() {
    try {
      if (!supabase) return; // env not set, keep mock
      const { data, error } = await supabase
        .from("credit_ledger")
        .select()
        .order("created_at", { ascending: false })
        .limit(500);
      if (error || !data) return;
      const mapped: LedgerRow[] = data.map((r: any) => {
        const d = r.date || r.created_at || r.timestamp;
        const dt = typeof d === "string" ? new Date(d) : new Date(Number(d) || Date.now());
        const amount = typeof r.amount === "number" ? r.amount : parseFloat(String(r.amount ?? 0)) || 0;
        const balanceAfter =
          typeof r.balance_after === "number"
            ? r.balance_after
            : parseFloat(String(r.balance_after ?? r.balanceAfter ?? 0)) || 0;
        return {
          date: dt,
          type: r.type ?? r.kind ?? "Adjustment",
          amount,
          balanceAfter,
          reference: r.reference ?? r.invoice ?? "",
          method: r.method ?? r.source ?? "card",
          notes: r.notes ?? r.note ?? "",
          receipt: r.receipt ?? r.receipt_url ?? null,
        };
      });
      setRows(mapped);
    } catch {
      // ignore
    } finally {
      setLoading(false);
    }
  }

  const filtered = useMemo(() => {
    const fromDate = from ? new Date(from + "T00:00:00") : undefined;
    const toDate = to ? new Date(to + "T23:59:59") : undefined;
    return rows.filter((r) => {
      if (type !== "All" && r.type !== type) return false;
      if (method !== "All" && r.method !== method) return false;
      if (fromDate && r.date < fromDate) return false;
      if (toDate && r.date > toDate) return false;
      if (search && !String(r.reference || "").includes(search)) return false;
      return true;
    });
  }, [rows, type, method, from, to, search]);

  const pageItems = useMemo(() => filtered.slice(page * pageSize, page * pageSize + pageSize), [filtered, page]);
  useEffect(() => setPage(0), [type, method, from, to, search]);

  const available = balance - reserved;
  const usageThisPeriod = rows.filter((e) => e.type === "Spend").reduce((p, e) => p + Math.abs(e.amount), 0);
  const lifetimeAdded = rows
    .filter((e) => e.type === "Top-up" || e.type === "Promo")
    .reduce((p, e) => p + e.amount, 0);
  const utilizationPct = creditLimit ? Math.min(999, (balance / creditLimit) * 100) : 0;

  return (
    <div style={{ display: "grid", gap: 12 }}>
      {message && (
        <div className="card" role="status" aria-live="polite">
          {message}
        </div>
      )}

      {/* Balance header */}
      <section className="card">
        <div className="row" style={{ justifyContent: "space-between" }}>
          <div>
            <div className="muted">Credit Balance</div>
            <h3 className="value">${balance.toFixed(2)}</h3>
            <div className="muted">
              Reserved: ${reserved.toFixed(2)} • Available: ${available.toFixed(2)}
            </div>
          </div>
          <div style={{ textAlign: "right" }}>
            {creditLimit !== null && <div className="muted">Limit: ${creditLimit.toFixed(2)}</div>}
            {creditLimit !== null && <div className="muted">{utilizationPct.toFixed(1)}% used</div>}
            <div className="toolbar" style={{ marginTop: 8 }}>
              <button className="accent" onClick={() => setTopUpOpen(true)}>Top up</button>
              <button className="accent" onClick={() => setKashierOpen(true)}>Add Money</button>
              <button className="outline" onClick={() => redeemPromo(setRows, setBalance)}>Redeem</button>
            </div>
          </div>
        </div>
      </section>

      {/* Summary */}
      <section className="summary">
        <div className="card">
          <div className="muted">Usage</div>
          <h3 className="value">This period spend: ${usageThisPeriod.toFixed(2)}</h3>
          <div className="muted">Lifetime added: ${lifetimeAdded.toFixed(2)}</div>
        </div>
        <div className="card">
          <div className="muted">Credit rules</div>
          <div>Currency: {process.env.NEXT_PUBLIC_KASHIER_CURRENCY || "USD"}</div>
          <div>Promos expire after 30 days (demo)</div>
          <div>Top-ups refundable within 7 days (demo)</div>
        </div>
        <div className="card">
          <div className="muted">Tips</div>
          <div>Use filters to narrow results</div>
        </div>
      </section>

      {/* Filters */}
      <section className="card">
        <div className="filters">
          <div className="field">
            <label>From</label>
            <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
          </div>
          <div className="field">
            <label>To</label>
            <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
          </div>
          <div className="field">
            <label>Type</label>
            <select value={type} onChange={(e) => setType(e.target.value)}>
              {["All", "Top-up", "Spend", "Refund", "Promo", "Adjustment", "Transfer"].map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>Method</label>
            <select value={method} onChange={(e) => setMethod(e.target.value)}>
              {["All", "card", "bank", "wallet", "promo"].map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>
          <div className="field" style={{ gridColumn: "span 6" }}>
            <label>Search by reference</label>
            <input placeholder="REF-..." value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <div className="field" style={{ alignSelf: "end" }}>
            <button className="outline" onClick={() => { setFrom(""); setTo(""); setType("All"); setMethod("All"); setSearch(""); setPage(0); }}>Clear</button>
          </div>
        </div>
      </section>

      {/* Table */}
      <section className="card">
        <div className="tableWrap">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Type</th>
                <th>Amount</th>
                <th>Balance after</th>
                <th>Reference</th>
                <th>Method</th>
                <th>Notes</th>
                <th>Receipt</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={8}>Loading...</td>
                </tr>
              ) : pageItems.length === 0 ? (
                <tr>
                  <td colSpan={8}>No records for selected filters</td>
                </tr>
              ) : (
                pageItems.map((r, idx) => (
                  <tr key={idx}>
                    <td>{fmtDate(r.date)}</td>
                    <td>{r.type}</td>
                    <td>{r.amount >= 0 ? `+$${r.amount.toFixed(2)}` : `-$${Math.abs(r.amount).toFixed(2)}`}</td>
                    <td>${r.balanceAfter.toFixed(2)}</td>
                    <td>{r.reference}</td>
                    <td>
                      <span className={methodPillClass(r.method)}>{r.method}</span>
                    </td>
                    <td>{r.notes || ""}</td>
                    <td>
                      {r.receipt ? (
                        <a href={r.receipt} target="_blank" rel="noreferrer">View</a>
                      ) : (
                        "-"
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        <div className="pagination">
          <span>
            Showing {filtered.length === 0 ? 0 : page * pageSize + 1}-{page * pageSize + pageItems.length} of {filtered.length}
          </span>
          <button className="outline" disabled={page <= 0} onClick={() => setPage((p) => Math.max(0, p - 1))}>
            Prev
          </button>
          <button
            className="outline"
            disabled={(page + 1) * pageSize >= filtered.length}
            onClick={() => setPage((p) => p + 1)}
          >
            Next
          </button>
        </div>
      </section>

      {topUpOpen && (
        <TopUpDialog
          onClose={() => setTopUpOpen(false)}
          onSaved={async (entry) => {
            setTopUpOpen(false);
            const newBalance = balance + entry.amount;
            setBalance(newBalance);
            setRows((r) => [
              { ...entry, date: new Date(entry.date), balanceAfter: newBalance },
              ...r,
            ]);
            setMessage("Top-up saved");
            setTimeout(() => setMessage(null), 2500);
          }}
        />
      )}

      {kashierOpen && (
        <KashierDialog
          onClose={() => setKashierOpen(false)}
          onCreate={async (amount, description) => {
            try {
              const merchantOrderId = `KASH-${Date.now() % 1_000_000}`;
              const webhook = process.env.NEXT_PUBLIC_KASHIER_WEBHOOK_URL;
              const returnUrl = process.env.NEXT_PUBLIC_KASHIER_RETURN_URL;
              const resp = await createHostedPayment({ amount, merchantOrderId, returnUrl: returnUrl || undefined, webhookUrl: webhook || undefined, description: description || undefined });
              window.open(resp.paymentUrl, "_blank");
              setMessage("Opened payment page");
            } catch (e: any) {
              setMessage(`Payment failed to open: ${e?.message || e}`);
            } finally {
              setTimeout(() => setMessage(null), 3000);
              setKashierOpen(false);
            }
          }}
        />
      )}
    </div>
  );
}

function redeemPromo(
  setRows: React.Dispatch<React.SetStateAction<LedgerRow[]>>,
  setBalance: React.Dispatch<React.SetStateAction<number>>
) {
  const code = window.prompt("Enter promo / voucher code");
  if (!code) return;
  const amt = 10;
  setBalance((b) => b + amt);
  setRows((rows) => [
    {
      date: new Date(),
      type: "Promo",
      amount: amt,
      balanceAfter: (rows[0]?.balanceAfter || 0) + amt,
      reference: `PROMO-${code.toUpperCase()}`,
      method: "promo",
      notes: `Redeemed ${code}`,
      receipt: null,
    },
    ...rows,
  ]);
}

function TopUpDialog({
  onClose,
  onSaved,
}: {
  onClose: () => void;
  onSaved: (entry: {
    date: string;
    type: string;
    amount: number;
    balanceAfter: number;
    reference: string;
    method: string;
    notes?: string;
    receipt?: string | null;
  }) => void;
}) {
  const [amount, setAmount] = useState(0);
  const [method, setMethod] = useState("card");
  const [reference, setReference] = useState("");
  const [notes, setNotes] = useState("");
  const [receiptUrl, setReceiptUrl] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);

  async function uploadReceiptIfAny(): Promise<string | undefined> {
    if (!file) return receiptUrl || undefined;
    if (!supabase) return receiptUrl || undefined;
    try {
      const user = (await supabase.auth.getUser()).data.user;
      if (!user) throw new Error("Sign in required to upload receipts");
      const sanitized = sanitizeFileName(file.name.toLowerCase());
      const path = `receipts/${user.id}/${Date.now()}_${sanitized}`;
      const { error } = await supabase.storage.from(RECEIPT_BUCKET).upload(path, file, {
        cacheControl: "3600",
        upsert: true,
      });
      if (error) {
        // Try update if already exists
        const { error: updErr } = await supabase.storage.from(RECEIPT_BUCKET).update(path, file, {
          cacheControl: "3600",
          upsert: true,
        });
        if (updErr) throw updErr;
      }
      const { data } = supabase.storage.from(RECEIPT_BUCKET).getPublicUrl(path);
      return data.publicUrl;
    } catch {
      return receiptUrl || undefined;
    }
  }

  async function save() {
    if (!amount || amount <= 0) return;
    setSaving(true);
    try {
      const now = new Date();
      const ref = reference.trim() || `TOPUP-${Date.now() % 100000}`;
      const receipt = await uploadReceiptIfAny();

      // attempt to insert into Supabase credit_ledger
      if (supabase) {
        try {
          const insertRow: any = {
            date: now.toISOString(),
            type: "Top-up",
            amount,
            balance_after: amount, // will be ignored in UI; persisted like Flutter
            reference: ref,
            method,
            notes: notes.trim(),
          };
          if (receipt) insertRow.receipt = receipt;
          const user = (await supabase.auth.getUser()).data.user;
          if (user) insertRow.user_id = user.id;
          await supabase.from("credit_ledger").insert(insertRow);
        } catch {
          // ignore
        }
      }

      onSaved({
        date: now.toISOString(),
        type: "Top-up",
        amount,
        balanceAfter: amount, // UI recalculates overall balance separately
        reference: ref,
        method,
        notes: notes.trim(),
        receipt: receipt || undefined,
      });
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="dialogBackdrop" onClick={onClose}>
      <div className="dialog" onClick={(e) => e.stopPropagation()}>
        <header>
          <h3>Add credit (manual)</h3>
        </header>
        <div className="row" style={{ flexWrap: "wrap", gap: 12 }}>
          <div className="field" style={{ width: "48%" }}>
            <label>Amount</label>
            <input
              type="number"
              step="0.01"
              min={0}
              placeholder="0.00"
              value={amount || ""}
              onChange={(e) => setAmount(parseFloat(e.target.value) || 0)}
            />
          </div>
          <div className="field" style={{ width: "48%" }}>
            <label>Method</label>
            <select value={method} onChange={(e) => setMethod(e.target.value)}>
              <option value="card">Card</option>
              <option value="bank">Bank</option>
              <option value="wallet">Wallet</option>
            </select>
          </div>
          <div className="field" style={{ width: "48%" }}>
            <label>Reference (optional)</label>
            <input value={reference} onChange={(e) => setReference(e.target.value)} />
          </div>
          <div className="field" style={{ width: "48%" }}>
            <label>Notes (optional)</label>
            <input value={notes} onChange={(e) => setNotes(e.target.value)} />
          </div>
          <div className="field" style={{ width: "100%" }}>
            <label>Receipt URL (optional)</label>
            <input value={receiptUrl} onChange={(e) => setReceiptUrl(e.target.value)} placeholder="https://..." />
          </div>
          <div className="field" style={{ width: "100%" }}>
            <label>Attach receipt (optional)</label>
            <input type="file" accept="image/*" onChange={(e) => setFile(e.target.files?.[0] || null)} />
          </div>
        </div>
        <footer>
          <button className="outline" onClick={onClose} disabled={saving}>Cancel</button>
          <button className="accent" onClick={save} disabled={saving || !amount}>Save</button>
        </footer>
      </div>
    </div>
  );
}

function KashierDialog({
  onClose,
  onCreate,
}: {
  onClose: () => void;
  onCreate: (amount: number, description: string | null) => Promise<void>;
}) {
  const [amount, setAmount] = useState(0);
  const [description, setDescription] = useState("");
  const [saving, setSaving] = useState(false);

  async function submit() {
    if (!amount || amount <= 0) return;
    setSaving(true);
    try {
      await onCreate(amount, description.trim() || null);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="dialogBackdrop" onClick={onClose}>
      <div className="dialog" onClick={(e) => e.stopPropagation()}>
        <header>
          <h3>Add money (Kashier)</h3>
        </header>
        <div className="row" style={{ flexWrap: "wrap", gap: 12 }}>
          <div className="field" style={{ width: "48%" }}>
            <label>Amount</label>
            <input
              type="number"
              step="0.01"
              min={0}
              placeholder="0.00"
              value={amount || ""}
              onChange={(e) => setAmount(parseFloat(e.target.value) || 0)}
            />
          </div>
          <div className="field" style={{ width: "100%" }}>
            <label>Description (optional)</label>
            <input value={description} onChange={(e) => setDescription(e.target.value)} />
          </div>
          <div className="muted">Currency: {process.env.NEXT_PUBLIC_KASHIER_CURRENCY || "USD"}</div>
        </div>
        <footer>
          <button className="outline" onClick={onClose} disabled={saving}>Cancel</button>
          <button className="accent" onClick={submit} disabled={saving || !amount}>Pay</button>
        </footer>
      </div>
    </div>
  );
}
