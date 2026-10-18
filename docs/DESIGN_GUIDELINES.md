# Guía de diseño — Challenge Dynasty

Referencia rápida para cualquier sesión de IA (o persona) que toque la UI de este repo. Combina la identidad de marca DINASTY con una lista de chequeo de interfaz tomada de las [Web Interface Guidelines de Vercel](https://github.com/vercel-labs/web-interface-guidelines). No reemplaza esas fuentes: es el resumen aplicado a este código.

## Marca (resumen — ver skill `dinasty-brand` para el detalle completo)

- Paleta del lado jugador: negro `#0A0A0C` / superficie `#161616` / dorado `#D4AF37` / blanco. Nada de cian ni navy nuevo sin revisar primero. Ojo: el lado club/negocio usa a propósito un acento azul propio, `#6FA3D8` (ver `components/business/BusinessHeader.tsx` y `app/negocio/page.tsx`) — no es un residuo, es su identidad sobria, distinta del dorado de jugador. No lo cambies a dorado sin que Luis lo pida; antes de "corregir" un color revisa si se repite en otros archivos de la misma cara (jugador vs. negocio) antes de asumir que es un error.
- Tipografía: Bebas Neue (títulos, mayúsculas) + Inter (texto). Bebas Neue se carga con `@fontsource`, nunca con `next/font/google`.
- Challenge Dynasty (cara del jugador) = estilo videojuego competitivo: rareza, brillo, nivel, cartas coleccionables. La cara de club/negocio es sobria.
- "By Padelito" va SIEMPRE en Challenge Dynasty. Nunca se quita.
- El verde `#00E676` ya se usa en varios componentes (`DynastyCard`, `CardStakePanel`, historial) como color de estado "activo / ganado / confirmado". Es intencional y consistente — no es un error de paleta, es el color de estado del sistema. No cambiarlo sin que Luis lo pida.

## Checklist de interfaz (lo que de verdad se repite en este repo)

1. **Iconos decorativos** (`lucide-react` junto a texto que ya dice lo mismo: `ShieldCheck`, `Trophy`, `Swords`, etc.) → siempre `aria-hidden="true"`. El ícono es decoración, el texto ya lo explica.
2. **Emoji usado como icono** (`card.sportIcon ?? '🏅'`) → `aria-hidden="true"` si el nombre del deporte ya aparece como texto cerca.
3. **Números que cambian o se alinean** (rating, nivel, contadores) → clase `tabular-nums` para que no "bailen" de ancho.
4. **Botón vs. enlace**: botón para una acción en la misma página (cambiar de pestaña, seleccionar una carta); `<Link>` para navegar a otra URL. Ya se respeta en la mayoría del código — revisar antes de copiar un patrón nuevo.
5. **Foco de teclado**: nunca quitar el outline nativo sin poner un remplazo. Si se usa `focus-visible:outline-none`, siempre junto con un anillo dorado (`focus-visible:ring-2 focus-visible:ring-[#D4AF37]`).
6. **Errores después de una acción async** (`stakeCard`, `withdrawCardStake`, formularios) → el mensaje de error necesita `role="alert"` para que el lector de pantalla lo anuncie sin que la persona tenga que ir a buscarlo.
7. **Fechas y números con configuración regional**: varias páginas ya calculan `dateLocale` a partir de `getLocale()` (`locale === 'en' ? 'en-US' : 'es-CO'`) en vez de dejar `'es-CO'` fijo. Si se toca una página con fechas, seguir ese patrón existente en vez de inventar uno nuevo.
8. **`prefers-reduced-motion`**: ya está bien manejado en `app/globals.css` (la animación de "fuego" de las cartas legendarias y la transición del tilt se desactivan). Mantener ese patrón en cualquier animación nueva.

## Cómo se usó esto (ejemplo real — auditoría de Cartas, 2026-10-18)

Se revisaron `components/DynastyCard.tsx`, `components/CardShowcase.tsx`, `components/CardStakePanel.tsx`, `app/cards/page.tsx` y `app/clubs/manage/[id]/page.tsx`. Cambios aplicados (todos aditivos, cero cambios de comportamiento):
- `aria-hidden="true"` en iconos y emoji decorativos.
- `tabular-nums` en rating y nivel de la carta.
- Anillo de foco dorado visible al navegar con teclado.
- `role="alert"` en el mensaje de error del panel de apuesta.
- Fecha del historial de traspasos usando el locale real en vez de `'es-CO'` fijo.
- Un azul residual (`#6FA3D8`) en el enlace "volver a clubes" cambiado a dorado.

Lo que NO se tocó, a propósito: el verde de estado, la paleta de rarezas, y cualquier archivo fuera de Cartas (finanzas, marketplace, etc. tienen el mismo patrón de fecha fija, pero cambiarlo ahí es un barrido más grande que necesita su propia decisión, no algo para meter de paso en esta auditoría).

## Herramientas usadas en esta sesión

- **Vercel web-interface-guidelines**: se usó de verdad — se trajo la guía vigente y se aplicó a código real (ver arriba).
- **awesome-design-md**: este archivo es el equivalente para este repo.
- **Playwright**: disponible en el entorno de nube de Claude para tomar capturas de verificación visual sin tocar producción ni datos reales.
- **GitHub Image-To-Code**: convierte una imagen de diseño en código. No se usó porque no había una imagen/mockup de Luis para convertir en este momento.
- **Taste Skill (Anti-Slop Framework)**: implica cambiar el framework de frontend. No se aplicó sin una decisión específica de Luis — es un cambio grande para una app en producción con ingresos reales.
