export type CreatePaymentInput = {
  amount: number;
  currency?: string;
  merchantOrderId: string;
  returnUrl?: string;
  webhookUrl?: string;
  description?: string | null;
};

export type CreatePaymentResponse = {
  paymentUrl: string;
  paymentRequestId?: string | null;
};

export async function createHostedPayment(payload: CreatePaymentInput): Promise<CreatePaymentResponse> {
  const res = await fetch('/api/kashier/create-payment', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Create payment failed: ${res.status} ${text}`);
  }
  return res.json();
}

