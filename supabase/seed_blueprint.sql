-- CHALLENGE DYNASTY — NON-DESTRUCTIVE ACTIVATION BLUEPRINT
-- Draft only. Do not execute until commercial values are approved.
-- No destructive statements.

-- BILLING:
-- audience_type: PLAYER_PREMIUM, CLUB, COACH, ORGANIZER, SELLER
-- feature keys should be finalized against frontend entitlement checks.
-- Seed plans/features/subscriptions only after pricing and payment provider are approved.

-- DYNASTY SHOP:
-- Seed only approved products into shop_products and shop_product_variants.
-- Use currency_code='COP', published status, explicit inventory tracking and SKU.

-- MARKETPLACE:
-- Create seller profile first, then listings and inventory.
-- Publish only after seller verification and entitlement checks.

-- CLUBS:
-- Organizations with organization_type='club'.
-- Link members via organization_memberships and courts/resources via organization_resources.

-- COACHES:
-- provider_profiles.provider_type='coach'.
-- provider_services may belong to an organization.
-- Decide operational_owner_type and payment_owner_type per service.

-- TOURNAMENTS:
-- tournaments must consistently reference organizer_profile_id + organization_id + sport_id.
-- categories must reference their tournament_id.

-- PRE-SEED CHECKLIST:
-- pricing approved
-- payment provider/webhooks approved
-- entitlements approved
-- first products approved
-- first marketplace seller approved
-- first club/coach/tournament test identities approved
