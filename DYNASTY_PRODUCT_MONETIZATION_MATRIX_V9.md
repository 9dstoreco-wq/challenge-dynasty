# DYNASTY — PRODUCT & MONETIZATION MATRIX V9

## Product pillars

### 1) Challenge Dynasty
Core social / sports network:
- Profiles
- Sports
- Challenges
- Matches / Results
- Rankings
- Tournaments
- Bookings
- Clubs
- Notifications

### 2) Dynasty Coach AI
Premium personal AI coach:
- Daily conversation
- Training plan
- Padel coaching
- Fitness / gym coaching
- Tournament preparation
- Progress tracking
- Video-analysis workflow
- Context from Challenge Dynasty activity

### 3) Dynasty Fitness Intelligence
Shared athlete intelligence:
- Fitness context
- Session planning
- Load / recovery context
- Habit tracking
- Goal progression
- Cross-sport adaptation

### 4) Dynasty Club Intelligence
B2B intelligence for clubs:
- Finance intelligence
- Marketing intelligence
- Occupancy / revenue intelligence
- CRM / retention intelligence
- Coach intelligence
- Tournament intelligence
- Growth recommendations
- Executive / owner copilot

### 5) Dynasty Coach Intelligence
AI copilot for professional coaches:
- Student tracking
- Session planning
- Progress reports
- Schedule support
- Service optimization
- Lead / acquisition recommendations
- Coach business analytics

### 6) Dynasty Tournament Intelligence
- Registration analysis
- Fair Play
- Draw recommendations
- Scheduler
- Change impact
- Rules
- Notifications
- Results / advancement
- Sponsor / promotion intelligence

### 7) Dynasty Commerce Intelligence
- Dynasty Shop
- Marketplace
- Product recommendations
- Seller intelligence
- Promotion recommendations
- Affiliate / partner recommendations

## Commercial principle

Every paid subscription should receive a meaningful intelligence layer.

### Player / Premium
Coach AI + Fitness Intelligence

### Club
Club Intelligence + Marketing + Finance + operations intelligence

### Coach
Coach AI + Coach Intelligence + Fitness Intelligence

### Organizer
Tournament Intelligence + promotion intelligence

### Seller / Marketplace Pro
Commerce Intelligence + seller analytics

### Enterprise
Full Dynasty Intelligence surface, subject to permissions.

## Entitlement namespace

Use the existing `billing_plan_features` / `billing_entitlements` system.

Canonical feature keys:

PLAYER / AI
- ai.coach.basic
- ai.coach.pro
- ai.fitness.basic
- ai.fitness.pro
- ai.video.analysis
- ai.tournament.prep

CLUB
- ai.club.analytics
- ai.club.finance
- ai.club.marketing
- ai.club.crm
- ai.club.forecasting
- ai.club.copilot

COACH
- ai.coach_business.analytics
- ai.coach_business.copilot
- ai.coach_business.student_insights

TOURNAMENT
- ai.tournament.analytics
- ai.tournament.fair_play
- ai.tournament.scheduler
- ai.tournament.promotion

COMMERCE
- ai.commerce.recommendations
- ai.commerce.seller_insights
- ai.commerce.promotion

ENTERPRISE
- ai.enterprise.full

## Important

Prices, plan codes, provider payment references and real commercial catalog values are intentionally NOT invented in this document. Those values require business approval.

The feature namespace above is the contract that frontend and backend can target once the approved plan catalog is seeded.
