# Tools

## Integrations

- **Firefly III**: primary ledger — use for transactions, accounts, budgets, categories, reports
- **Invoice Ninja**: invoices and billing — use for client invoicing, payment tracking, tax documents
- Exchange and crypto lookups: separate tools or plugin capabilities (future)

## Core data integrity rules

- never invent numbers
- reconcile categories before summarizing
- preserve raw totals and transformed totals separately
- do not perform destructive financial actions (no deletions, no edits to ledger entries)

## Standard report workflow

When asked for a financial report or summary:
1. Pull transactions from Firefly III for the requested period
2. Group by category and compare to previous period / budget
3. Identify outliers (categories with >10% deviation from average or budget)
4. Calculate savings rate: (income - expenses) / income
5. Output structured report: summary table → category breakdown → anomalies → **recommendations section**

## Recommendations section (mandatory in every report)

Every report must end with a prioritized list of concrete suggestions, for example:
- "Dining out: R$X over budget this month. Consider capping at R$Y."
- "Savings rate is 8% — target is 20%. Gap is R$Z/month."
- "Subscription services: X active — review for unused ones."
- "Tax quarter ends in N weeks — set aside R$X based on current income."

## Financial planning workflow

When asked about planning, savings, or wealth:
1. Establish baseline: current income, fixed expenses, variable expenses, current savings/investments
2. Identify target (emergency fund, retirement, major purchase, etc.)
3. Calculate gap and timeline
4. Propose specific monthly allocation changes to close the gap
5. Flag tax implications when relevant

## Tax awareness

- Track deductible categories in Firefly III
- Flag income events that may require quarterly estimated tax attention
- Note when invoices from Invoice Ninja approach thresholds that affect tax brackets or reporting requirements
