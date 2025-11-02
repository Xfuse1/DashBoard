Paymob (Accept) integration overview

What we added

- Client service `lib/services/paymob_service.dart` to request a payment key via your backend and build the Paymob card IFrame URL.
- Simple UI `lib/pages/payments/paymob_checkout_page.dart` to enter an amount and open the Paymob card checkout in the browser.
- Button in `lib/pages/payments/payments_page.dart` to open the checkout page.
- Env placeholders in `.env.example` for client configuration.
- A minimal Node backend example in `server/paymob-example/` that exposes `/paymob/payment_key`.

Client configuration (.env)

- `PAYMOB_PUBLIC_KEY`: your Paymob public key (e.g., `egy_pk_test_...`).
- `PAYMOB_IFRAME_ID`: your Paymob IFrame ID for card payments (numeric).
- `PAYMOB_BACKEND_URL`: base URL for your backend (e.g., `http://localhost:8787`).

Backend (server/paymob-example)

- Requires `PAYMOB_API_KEY` (legacy API key string) and `PAYMOB_INTEGRATION_ID` (card integration id) in `.env`.
- Start with Node 18+: `npm i && npm start`.
- POST `/paymob/payment_key` with `{ amount_cents, currency, billing_data }` to receive `{ payment_token }`.

How the flow works

1) Backend authenticates with Paymob using `PAYMOB_API_KEY` to get `auth_token`.
2) Backend creates an order with the intended amount and currency.
3) Backend requests a `payment_key` using the order id, amount, currency, billing details, and `PAYMOB_INTEGRATION_ID`.
4) Flutter app builds the IFrame URL: `https://accept.paymob.com/api/acceptance/iframes/{IFRAME_ID}?payment_token={payment_key}` and launches it in the browser.

Notes

- Never put your `PAYMOB_API_KEY` or `PAYMOB_SECRET_KEY` in the Flutter app. Keep all secret keys on the server only.
- You will also need to handle webhooks on your backend to mark orders as paid, and optionally forward success/failure to Supabase.
- The example covers Card IFrame checkout. Wallets, Kiosk, and other methods require additional (but similar) server flows.

