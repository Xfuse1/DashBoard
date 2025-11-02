import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';

export const dynamic = 'force-dynamic'; // ensure node runtime

function hmacSha256Hex(data: string, key: string) {
  return crypto.createHmac('sha256', key).update(data, 'utf8').digest('hex');
}

export async function POST(req: NextRequest) {
  try {
    const {
      amount,
      currency = process.env.KASHIER_CURRENCY || 'USD',
      merchantOrderId,
      returnUrl,
      webhookUrl,
      description,
    } = (await req.json()) as {
      amount: number;
      currency?: string;
      merchantOrderId: string;
      returnUrl?: string;
      webhookUrl?: string;
      description?: string | null;
    };

    if (!amount || amount <= 0) {
      return NextResponse.json({ error: 'Invalid amount' }, { status: 400 });
    }

    const merchantId = process.env.KASHIER_MERCHANT_ID;
    const paymentApiKey = process.env.KASHIER_PAYMENT_API_KEY || process.env.KASHIER_API_KEY;
    const mode = process.env.KASHIER_MODE || 'test';

    if (!merchantId || !paymentApiKey) {
      return NextResponse.json(
        { error: 'KASHIER_MERCHANT_ID and KASHIER_PAYMENT_API_KEY must be set' },
        { status: 500 }
      );
    }

    const amountStr = Number(amount).toFixed(2);
    const path = `/?payment=${merchantId}.${merchantOrderId}.${amountStr}.${currency}`;
    const hash = hmacSha256Hex(path, paymentApiKey);

    const params: Record<string, string> = {
      merchantId,
      orderId: merchantOrderId,
      amount: amountStr,
      currency,
      hash,
      mode,
    };
    if (returnUrl) params.merchantRedirect = returnUrl;
    if (webhookUrl) params.serverWebhook = webhookUrl;
    if (description) params.description = description;

    const url = new URL('https://payments.kashier.io/');
    for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);

    return NextResponse.json({ paymentUrl: url.toString(), paymentRequestId: null });
  } catch (e: any) {
    return NextResponse.json({ error: e?.message || 'Unknown error' }, { status: 500 });
  }
}

