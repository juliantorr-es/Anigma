# Small Business Assistant Product Model

This guide translates current research on small-business work into a product model for Anigma.

`td` remains the source of truth for execution status. This document defines product direction and capability requirements.

## Thesis

Anigma should help small business owners by reducing cognitive analysis overhead:

- remembering what matters
- reconstructing context
- detecting obligations
- prioritizing next actions
- drafting or preparing work with evidence
- keeping business state coherent across scattered tools

The product should not be framed as "AI chat for small business." The stronger framing is:

> A grounded business memory and action system that helps owners know what changed, what matters, what is due, and what to do next.

## Research Signals

### 1. Small business owners are time-constrained and tool-fragmented

Slack/Salesforce research reported that small business owners lose substantial time daily, juggle multiple digital tools, waste time waiting for status updates, search in the wrong places, and repeat messages across platforms.

Implication for Anigma:

- the product should reduce context switching
- the assistant should unify business context across sources
- "what changed?" and "what needs my attention?" are primary jobs

### 2. Digital adoption support needs low barriers and tailored guidance

The UK SME Digital Adoption Taskforce recommended an AI-powered support tool that can provide diagnostics, guidance, and signposting to specialized support. It specifically emphasized low barriers to entry for SMEs with limited technical expertise and sector-specific/localized guidance.

Implication for Anigma:

- onboarding should diagnose the user's business context before asking them to configure a system
- guidance should be sector-aware when possible
- the product should explain why an action matters, not only expose features

### 3. Compliance, recordkeeping, and obligations are major burdens

The U.S. Chamber's Small Business Index reported that many small businesses spend too much time on compliance, with taxes, recordkeeping, payroll, licensing/permits, cybersecurity, data protection, and privacy as major time sinks.

Implication for Anigma:

- obligation detection and recordkeeping support should be first-class
- the assistant should preserve evidence and provenance for business-sensitive answers
- the product should help owners prepare, track, and find supporting records rather than pretend to replace professionals

### 4. Digital tools help, but adoption barriers remain

The SBA Office of Advocacy report on U.S. SME access and use of digital tools highlights both the value of digital technologies and the barriers SMEs face adopting them.

Implication for Anigma:

- the product should integrate with tools owners already use rather than require a new operating model immediately
- connectors and imports are not optional; they are how the product earns relevance
- the first experience should work with partial data and clearly state what it does not know

### 5. Odoo shows the value of an integrated business graph

Odoo's open-source/community model is useful because it treats business operations as connected apps rather than isolated tools. Its documentation exposes the shape of that graph: contacts, CRM, sales, invoicing, accounting, bank transactions, reconciliation, inventory, purchasing, projects, point of sale, and reporting.

The important lesson for Anigma is not to become a full ERP clone. The lesson is that bookkeeping becomes much more useful when it is connected to the rest of business context.

Odoo's accounting model also reinforces several accounting-specific foundations:

- double-entry bookkeeping
- chart of accounts
- journals
- accounts receivable and payable
- customer invoices and vendor bills
- bank synchronization and bank reconciliation
- payment matching
- tax and fiscal localization
- reporting

Implication for Anigma:

- bookkeeping should be a first-class capability area, not a peripheral export
- every financial claim should be evidence-backed and traceable to source records
- the assistant should help prepare, classify, reconcile, and explain bookkeeping state, but should be cautious about final legal/tax/accounting conclusions
- the product should eventually connect business events to accounting consequences

## Product Job

For a small business owner, Anigma's job is:

> Turn scattered business context into grounded awareness, next actions, and reviewable execution.

That breaks into four outcomes:

1. Know what is happening.
2. Know what matters.
3. Know what to do next.
4. Act safely with evidence.

## Core Small Business Capabilities

Anigma should eventually cover the core operating domains a small business owner has to navigate:

- CRM
- sales
- invoicing
- accounting
- bank reconciliation
- inventory or assets
- projects/jobs
- reporting

These are product capabilities, not immediate backend tasks. They should be built on the backend foundation rather than bypassing it.

### 1. Business Object Memory

Anigma needs business-specific memory objects, not only generic personal context.

Core objects:

- customers
- leads
- vendors
- projects/jobs
- invoices and estimates
- contracts and agreements
- licenses, permits, and renewals
- employees or contractors
- assets and inventory, where relevant
- recurring obligations

These should be evidence-backed entities linked to source documents, emails, calendar events, notes, and transactions.

### 1.5 Business Operating Domains

The Odoo-style lesson is that these domains become more valuable when connected.

#### CRM

Purpose:

- remember customers, leads, conversations, promises, preferences, risks, and next actions

Minimum capabilities:

- customer/vendor/contact memory
- communication timeline
- lead and opportunity status
- relationship notes with evidence
- follow-up detection

#### Sales

Purpose:

- help the owner turn inquiries into quotes, jobs, and paid work

Minimum capabilities:

- quote/estimate memory
- proposal follow-up tracking
- sales-stage awareness
- customer-specific pricing/context recall
- suggested next action for open opportunities

#### Invoicing

Purpose:

- help the owner bill accurately and follow up without losing context

Minimum capabilities:

- invoice draft preparation
- invoice status tracking
- overdue invoice detection
- invoice/customer/payment linkage
- follow-up email drafting with evidence

#### Accounting

Purpose:

- keep financial records explainable, reviewable, and accountant-friendly

Minimum capabilities:

- expense classification
- income/expense evidence links
- chart-of-accounts/category mapping
- audit trail for classifications
- accountant packet preparation

#### Bank Reconciliation

Purpose:

- connect bank activity to invoices, bills, expenses, payments, and write-offs

Minimum capabilities:

- bank transaction import
- candidate match suggestions
- unmatched transaction queue
- reconciliation explanations
- tolerance/fee/rounding handling
- user/accountant approval state

#### Inventory Or Assets

Purpose:

- help businesses that sell products or manage physical assets avoid blind spots

Minimum capabilities:

- item/asset records
- purchase/sale linkage
- low-stock or reorder signals
- supplier/vendor linkage
- document/receipt support

This should be optional by business type.

#### Projects And Jobs

Purpose:

- track work commitments, deliverables, blockers, and customer-facing status

Minimum capabilities:

- project/job memory
- task and milestone tracking
- blockers and waiting-on states
- customer communications linked to the job
- document and invoice linkage

#### Reporting

Purpose:

- help the owner understand the business without manually assembling reports

Minimum capabilities:

- daily and weekly brief
- cash-flow attention report
- overdue invoice report
- customer/job status report
- bookkeeping review report
- risk and obligation report

Reports should cite source data and expose uncertainty.

### 2. Obligation And Follow-Up Detection

This is likely one of the highest-value capabilities.

The system should detect:

- promises made in email or notes
- due dates
- customer follow-ups
- unpaid or overdue invoices
- quote/estimate follow-ups
- contract renewal dates
- license or permit reminders
- waiting-on relationships
- documents requiring review or signature

Each obligation should have:

- source evidence
- owner
- due date or uncertainty marker
- status
- suggested next action
- freshness/confidence state

### 2.5 Bookkeeping And Financial Memory

Anigma should be capable of serious bookkeeping assistance.

The minimum bookkeeping model should include:

- customers and vendors
- invoices and estimates
- vendor bills and expenses
- payments
- bank transactions
- accounts/categories
- reconciliation status
- tax-relevant records
- receipts and supporting documents
- cash-flow signals

The target is not autonomous accounting authority. The target is a grounded financial workbench that helps the owner and their accountant understand what happened, what is unmatched, what needs review, and what records support each claim.

Bookkeeping capabilities should include:

- classify receipts and expenses with evidence
- match payments to invoices or bills
- detect duplicate bills or suspicious duplicates
- flag unreconciled bank transactions
- summarize overdue invoices
- surface missing receipts or weak support
- prepare accountant-facing packets
- explain why a transaction was categorized a certain way
- preserve review state and corrections as learning signals

Every bookkeeping action should distinguish:

- source facts
- suggested classification
- confidence level
- missing evidence
- user/accountant approval state
- audit trail

### 3. Daily And Weekly Business Briefs

The product should produce short, grounded briefings:

- what changed since yesterday or last week
- who is waiting on the owner
- what the owner is waiting on
- money or invoice risks
- upcoming deadlines
- stale opportunities
- documents needing attention
- operational anomalies

This should be a brief, not a dashboard dump.

### 4. Grounded Decision Support

Small business owners need prioritization.

Anigma should answer:

- "What should I do first today?"
- "Which customer needs attention?"
- "Which job is at risk?"
- "Which invoices should I chase?"
- "What changed with this customer?"
- "What should I prepare before this meeting?"

Answers must cite evidence and distinguish:

- directly found facts
- inferred priorities
- stale evidence
- missing context
- recommended verification

### 5. Reviewable Execution

The assistant should eventually prepare work, but the owner should remain in control.

Examples:

- draft customer replies
- prepare follow-up emails
- summarize invoices or estimates
- create task lists
- organize documents
- classify receipts
- prepare meeting briefs
- generate status updates
- prepare bookkeeping review queues
- draft invoice follow-ups
- assemble accountant-ready document packets

Execution should be:

- reviewable
- reversible when practical
- source-backed
- logged
- permission-aware
- auditable

### 6. Connector-First Context Acquisition

The small-business product is only useful if it connects to where business life already happens.

Priority connector classes:

- email
- calendar
- local files
- cloud drives
- PDFs and scans
- accounting or invoicing exports
- payment processor exports
- bank transaction exports or read-only bank feeds
- CRM-lite CSVs or spreadsheets
- website/contact-form exports

The first version can rely on file imports and CSV/PDF exports, but the roadmap should preserve connector depth as a strategic requirement.

### 7. Business Risk Feed

Anigma should surface risks without requiring the owner to ask.

Example signals:

- customer promised response has no follow-up
- invoice is overdue
- contract term changed
- repeated vendor issue appears
- renewal deadline is near
- customer request conflicts with prior agreement
- stale source is being used for a current answer

Risk feed items should be concise and evidence-backed.

## Relationship To Existing Architecture

The current backend work already supports the foundation:

- personal context memory gives source truth and episodic memory
- profile memory can become customer/vendor/project memory
- grounded-answer gates support trustworthy recommendations
- long-run runtime state supports multi-step business workflows
- observability/logging makes agent actions debuggable
- database consolidation is necessary for reliable business state

The missing product layer is business semantics:

- business entity extraction
- obligation modeling
- follow-up detection
- business brief generation
- reviewable action queue
- small-business evaluation fixtures

## Suggested Capability Stack

### Foundation

- ingest and classify business artifacts
- extract business entities
- model CRM, sales, invoicing, accounting, bank reconciliation, inventory/assets, projects, and reporting domains
- detect obligations and deadlines
- model basic bookkeeping entities and financial evidence
- retrieve evidence with provenance
- generate grounded summaries

### Operating Layer

- daily brief
- weekly review
- customer/job memory
- CRM/contact attention queue
- sales opportunity queue
- follow-up queue
- document attention queue
- invoice/payment attention queue
- bookkeeping review queue
- unmatched transaction queue
- inventory/asset attention queue where applicable
- accountant packet builder

### Execution Layer

- draft messages
- prepare quotes/estimates from evidence
- prepare invoice drafts
- create tasks/reminders
- classify and organize documents
- suggest bookkeeping categorization
- match payments to invoices or bills
- prepare reconciliation explanations
- prepare meeting/client briefs
- prepare owner-facing reports
- propose but do not auto-send sensitive actions

## Evaluation Fixtures

Small-business readiness should be tested with realistic scenarios:

- customer follow-up missed in an email thread
- stale estimate superseded by a newer quote
- unpaid invoice with multiple reminder attempts
- bank transaction that may match one of several invoices
- receipt missing for a categorized expense
- duplicated vendor bill candidate
- owner-corrected bookkeeping classification reused as a learning signal
- license renewal due soon
- conflicting customer instructions across two channels
- tax/recordkeeping artifact needed for a deadline
- meeting brief requiring email, calendar, and document evidence
- "what changed this week?" across customers, invoices, and documents
- draft reply that must cite the correct promise and avoid unsupported claims

These fixtures should test both retrieval and judgment.

## UI Implications

The UI should not start as a blank chatbot.

The primary surface should feel like a calm business command center:

- today
- waiting on me
- waiting on others
- money attention
- customer attention
- document attention
- risks
- ask Anigma

The assistant should be embedded into these surfaces and always show evidence when making business-relevant claims.

## Non-Goals

Do not attempt to become:

- a replacement for legal, tax, or financial professionals
- a generic CRM clone
- an enterprise workflow suite
- an autonomous business operator with unsupervised authority

Bookkeeping non-goal:

- Anigma should not initially try to replace QuickBooks, Xero, Odoo Accounting, or a professional accountant.
- It should first become a trustworthy bookkeeping copilot: classify, match, explain, prepare, reconcile, and escalate with evidence.
- If Anigma eventually owns books directly, it must implement real double-entry, chart-of-accounts, journal, reconciliation, closing, and audit controls rather than informal transaction tagging.

The product should help owners navigate and act, not remove their judgment or accountability.

## Roadmap Implications

This product model should eventually become a dedicated product track after the backend foundation stabilizes.

Recommended future TD themes:

- business entity model
- CRM/contact memory
- sales and opportunity tracking
- invoicing workflow
- obligation and follow-up extraction
- bookkeeping and financial-memory model
- evidence-backed transaction classification
- payment/invoice matching and reconciliation assistance
- inventory/assets model
- projects/jobs model
- owner-facing reporting model
- daily/weekly business brief
- reviewable action queue
- small-business connector pack
- business-risk feed
- small-business evaluation matrix

These should not preempt the current backend foundation work. They should guide the UI/UX and product capability phase once backend truth, memory, and runtime foundations are solid.

## Research References

- SBA Office of Advocacy, "U.S. SME Access and Use of Digital Tools" (February 7, 2023): https://advocacy.sba.gov/2023/02/07/us-sme-access-and-use-of-digital-tools/
- UK SME Digital Adoption Taskforce interim report, AI support-tool recommendation (2025): https://assets.publishing.service.gov.uk/media/688a43c9b223ff124d388902/sme-digital-adoption-taskforce-interim-report.pdf
- Salesforce/Slack, "Small Business Owners Lose 1.5 Hours Daily to Wasted Time" (August 14, 2024): https://www.salesforce.com/news/stories/small-business-productivity-trends-2024/
- U.S. Chamber of Commerce, "Small Businesses Are Spending More Time, Money on Regulatory Compliance" (December 16, 2024): https://www.uschamber.com/small-business/small-businesses-are-spending-more-time-money-on-regulatory-compliance
- Odoo 19 user documentation, application index: https://www.odoo.com/documentation/19.0/applications.html
- Odoo 19 accounting documentation, double-entry/accounting foundations: https://www.odoo.com/documentation/19.0/applications/finance/accounting.html
- Odoo 19 bank reconciliation documentation: https://www.odoo.com/documentation/19.0/applications/finance/accounting/bank/reconciliation.html
- Odoo Community repository: https://github.com/odoo/odoo
