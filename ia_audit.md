# Receipto — Information Architecture Audit

_Snapshot of the current app structure (no code changed). 4 bottom-nav tabs + 10 pushed screens._

## Navigation hierarchy

```
Bottom nav (4 tabs): Home · Analytics · Chat · Settings
├─ Home ──────────── FAB / tile → Add/Edit Transaction ──→ Split by Items
├─ Analytics
├─ Chat
└─ Settings
   ├─ Preferences → Manage Categories
   ├─ Planning    → Budgets · Savings Goals · Recurring → Add/Edit Recurring
   │                                          · Subscriptions → Add/Edit Recurring
   ├─ Accounts    → Wallets & Balances
   └─ Data        → Backup & Restore
```

**Reachable only via Settings** (not the tab bar): Manage Categories, Budgets, Savings Goals, Recurring, Subscriptions, Wallets, Backup.

---

## 1. Home (tab)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Home | App bar | Title "Receipto" (no actions) | — |
| Home | Summary card | Month's total spending (or filtered category total) | Display |
| Home | Month navigator | Move between months (next disabled on current month) | ◀ ▶ chevrons |
| Home | Cash-flow strip | Income / Expenses / Net for the month (hidden when a category filter is active) | Display |
| Home | Category filter | "All" + category chips filter the list & summary | Tap chip |
| Home | Transaction list | Paginated ledger (income green, expense gold) | Scroll |
| Home | Edit transaction | Open a transaction | Tap tile |
| Home | Delete transaction | Remove with confirm | Swipe left |
| Home | Load more | Infinite scroll next 30 | Scroll to bottom |
| Home | Add transaction | New transaction | FAB (+) |

## 2. Analytics (tab)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Analytics | Month navigator | Pick the month analysed (next disabled on current month) | ◀ ▶ chevrons |
| Analytics | Cash-flow tiles | Income / Expenses / Net | Display |
| Analytics | Smart Insights | Rule-based anomaly detection (spikes, large txns, duplicates, frequent merchant) — current month only | Display (auto) |
| Analytics | Spending by Category | Horizontal bars + % | Display |
| Analytics | Income vs Expense trend | 6-month bar chart + legend | Display |
| Analytics | Refresh | Reload figures | Pull-to-refresh |

## 3. Chat — AI Financial Advisor (tab)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Chat | Message thread | User/AI bubbles; AI rendered as markdown | Display |
| Chat | Clear chat | Reset conversation | App bar refresh icon |
| Chat | Typing indicator | Shown while awaiting AI | Auto |
| Chat | Send message | Query answered with injected financial data (uses selected provider / Groq model) | Text field + send button |

## 4. Settings (tab)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Settings | AI provider | Gemini / OpenAI / Groq | Segmented button |
| Settings | Groq model | Llama 3.1 8B / GPT OSS 120B | Segmented button (Groq only) |
| Settings | API keys list | Reveal, copy, delete, set-active per key | Icons / tap row |
| Settings | Add API key | Field + prefix validation + save | Save Key button |
| Settings | Privacy notice | On-device key storage note | Display |
| Settings | → Manage Categories | Under **Preferences** | Nav tile |
| Settings | → Budgets | Under **Planning** | Nav tile |
| Settings | → Savings Goals | Under **Planning** | Nav tile |
| Settings | → Recurring Transactions | Under **Planning** | Nav tile |
| Settings | → Subscriptions | Under **Planning** | Nav tile |
| Settings | → Wallets & Balances | Under **Accounts** | Nav tile |
| Settings | → Backup & Restore | Under **Data** | Nav tile |
| Settings | How to get an API key | Gemini/OpenAI/Groq instruction cards | Display |
| Settings | About | App name / version | Display |

## 5. Add/Edit Transaction (pushed from Home)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Add/Edit Transaction | Scan Receipt | OCR + AI parse fills amount/merchant/date | App bar icon (expense only) |
| Add/Edit Transaction | Split by Items | Opens splitter; returns your share into amount | App bar icon (expense only) |
| Add/Edit Transaction | Delete | Remove (edit mode) | App bar icon (edit only) |
| Add/Edit Transaction | Expense/Income toggle | Transaction type | Segmented button |
| Add/Edit Transaction | Amount / Merchant / Date | Core fields | Fields / date picker |
| Add/Edit Transaction | Category | Category chips | Tap chip |
| Add/Edit Transaction | Account | **Accounts double as payment methods** | Tap chip |
| Add/Edit Transaction | Note | Optional | Field |
| Add/Edit Transaction | Save | Persist + move account balance | Button |
| Add/Edit Transaction | Scan source sheet | Camera / Gallery picker | Bottom sheet |

## 6. Split by Items (pushed from Add Transaction)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Split by Items | Intro | Scan receipt / add items manually | Buttons |
| Split by Items | Rescan | Re-scan a receipt | App bar icon |
| Split by Items | Item rows | Name, unit price, "You had" qty | Fields + stepper |
| Split by Items | Add item | New manual row | Button |
| Split by Items | Charges | Service charge % + SST % (auto-filled by OCR/AI) | Fields |
| Split by Items | Summary | My items, service, SST, My share | Display |
| Split by Items | Use my share | Return share to transaction | Button |

## 7. Manage Categories (Settings → Preferences)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Manage Categories | Category list | All categories ("Others" protected) | Display |
| Manage Categories | Delete category | Remove (except Others) | Row delete icon |
| Manage Categories | Add category | Name + emoji | Add button → dialog |

## 8. Budgets (Settings → Planning)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Budgets | Over-budget banner | Lists categories over limit | Display (conditional) |
| Budgets | Category rows | Spent / limit + progress bar (red if over) | Display |
| Budgets | Set/edit/remove budget | Monthly limit per category | Tap row → dialog |

## 9. Savings Goals (Settings → Planning)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Savings Goals | Goal cards | Progress, saved/target, %, remaining/target date | Display |
| Savings Goals | Add / Withdraw | Adjust saved amount | Buttons → dialog |
| Savings Goals | Delete goal | Remove | Card delete icon |
| Savings Goals | Add goal | Name, target, optional date | FAB → dialog |
| Savings Goals | Empty state | Prompt when no goals | Display |

## 10. Recurring Transactions (Settings → Planning)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Recurring | List | Merchant, frequency, next date, amount, subscription badge | Display |
| Recurring | Active toggle | Pause/resume | Switch |
| Recurring | Edit | Open template | Tap card |
| Recurring | Add | New template | FAB → Add/Edit Recurring |
| Recurring | Auto-post | Due items materialise into transactions | On app launch (auto) |
| Recurring | Empty state | Prompt when none | Display |

## 11. Add/Edit Recurring (from Recurring / Subscriptions)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Add/Edit Recurring | Expense/Income toggle | Type | Segmented |
| Add/Edit Recurring | Amount / Merchant | Core fields | Fields |
| Add/Edit Recurring | Frequency | Weekly / Monthly | Segmented |
| Add/Edit Recurring | Next date | First/next occurrence | Date picker |
| Add/Edit Recurring | Category / Account | Chips | Tap chip |
| Add/Edit Recurring | Track as subscription | Show in Subscriptions | Switch |
| Add/Edit Recurring | Note / Save / Delete | | Fields / buttons |

## 12. Subscriptions (Settings → Planning)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Subscriptions | Monthly cost card | Total monthly + ~yearly | Display |
| Subscriptions | Subscription cards | Renewal date + amount | Tap → edit |
| Subscriptions | Add subscription | Opens recurring form (subscription preset) | FAB |
| Subscriptions | Empty state | Prompt when none | Display |

## 13. Wallets & Balances (Settings → Accounts)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Wallets | Net worth card | Sum of all account balances | Display |
| Wallets | Account cards | Name, type, live balance | Display |
| Wallets | Edit/delete account | Name, type, opening balance | Tap card → dialog |
| Wallets | Add account | New account | FAB → dialog |
| Wallets | Transfer | Move money between accounts | App bar icon → dialog |
| Wallets | Recent transfers | Last transfers (delete each) | Display / delete icon |

## 14. Backup & Restore (Settings → Data)

| Screen | Feature | Description | Trigger |
|---|---|---|---|
| Backup | Info card | Explains Drive-only backup | Display |
| Backup | Auto-backup toggle | Every 24h + last-run status | Switch |
| Backup | Last backup card | Timestamp of last manual backup | Display |
| Backup | Backup now | Upload JSON to Google Drive | Button |
| Backup | Restore | Pick a Drive backup → confirm → replace data | Button → sheet → dialog |
| Backup | Signed-in account | Shows Google account + sign out | Display / Sign out |

---

## Observations for the IA discussion

- **Backup covers transactions only** — budgets, goals, recurring, splits, accounts/transfers, and categories are not backed up.
- **Everything under Planning / Accounts / Data lives inside Settings** — 7 feature screens are two taps deep behind the Settings tab, which is heavy for "Settings."
- **Wallets/net worth and Budgets & Goals aren't surfaced on Home or Analytics** — they're only reachable through Settings, unlike the BudgetBakers layout referenced (which had Accounts and Budgets/Goals as top-level tabs).
- **Split records aren't persisted** — Split by Items is a calculator that feeds the transaction amount; there is no standalone list.
- **Manage Categories sits under "Preferences"** while Accounts moved out to their own section — categories could arguably sit alongside them.
