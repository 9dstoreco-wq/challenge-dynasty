# DYNASTY AI CORE — CONTRACT V9

## Purpose

One intelligence layer, multiple role-specific copilots.

## Core context

AI should be able to consume permitted, role-scoped data from:
- profile
- sports
- challenges
- matches
- results
- rankings
- tournaments
- bookings
- organizations
- coaches
- commerce
- billing entitlements
- analytics

## Role-aware surfaces

PLAYER
- Coach AI
- Fitness Intelligence
- Tournament Prep
- Product Recommendations

COACH
- Coach AI
- Coach Business Copilot
- Student Insights

CLUB
- Club Intelligence
- Marketing Intelligence
- Finance Intelligence
- Operations Intelligence
- Executive Copilot

ORGANIZER
- Tournament Intelligence
- Promotion Intelligence

SELLER
- Commerce Intelligence
- Seller Copilot

## Safety / permissions

AI must never bypass the underlying RLS/authorization layer.

The AI layer may only retrieve data already authorized for the current subject.

Sensitive financial or personal data must remain scoped to authorized owners/roles.

## Product rule

The same user should have one coherent Dynasty identity and one shared athletic context, while each product surface exposes only the capabilities allowed by the user's role and entitlements.
