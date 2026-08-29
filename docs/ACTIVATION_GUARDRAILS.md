# Activation Guardrails

The UI must distinguish:
- unavailable
- empty
- authentication required
- entitlement required
- payment setup required

Never render fake products, fake clubs, fake coaches, fake tournaments, or fake plans when the API returns zero rows.

Suggested empty-state copy:
Shop: Próximamente encontrarás productos Dynasty aquí.
Marketplace: Todavía no hay publicaciones en tu zona.
Clubs: Aún no hay clubes registrados.
Coaches: Aún no hay coaches disponibles.
Tournaments: Aún no hay torneos publicados.
Billing: Los planes estarán disponibles próximamente.
