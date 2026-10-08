import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

// Rutas que exigen sesion iniciada. Antes el middleware solo refrescaba la cookie de sesion y
// dejaba pasar cualquier visita -- finanzas y notificaciones quedaban "accesibles" sin iniciar
// sesion (sin fuga real de datos de otros usuarios, porque cada pantalla ya filtra por el usuario
// actual o muestra vacio, pero la ruta en si no redirigia a login).
const PROTECTED_PREFIXES = ['/finance', '/notifications']

function isProtectedPath(pathname: string): boolean {
  return PROTECTED_PREFIXES.some((p) => pathname === p || pathname.startsWith(`${p}/`))
}

// Subdominio de negocio (clubes/dueños de cancha), opcional y apagado por defecto. En cuanto
// Luis tenga un dominio propio y lo conecte en Vercel, basta con configurar la variable de
// entorno NEXT_PUBLIC_CLUBS_HOST (ej: "clubes.challengedynasty.com") -- sin esa variable este
// bloque no hace nada, así que hoy (solo con el dominio gratuito de Vercel) es inofensivo.
const CLUBS_HOST = process.env.NEXT_PUBLIC_CLUBS_HOST

function rewriteForBusinessHost(request: NextRequest): NextResponse | null {
  if (!CLUBS_HOST) return null
  const host = request.headers.get('host') ?? ''
  if (host !== CLUBS_HOST) return null
  const { pathname } = request.nextUrl
  if (pathname === '/' || pathname === '') {
    const url = request.nextUrl.clone()
    url.pathname = '/negocio'
    return NextResponse.rewrite(url)
  }
  return null
}

export async function middleware(request: NextRequest) {
  const businessRewrite = rewriteForBusinessHost(request)
  if (businessRewrite) return businessRewrite

  let response = NextResponse.next({ request })
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return request.cookies.getAll() },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => request.cookies.set(name, value))
          response = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options))
        },
      },
    }
  )
  const { data: { user } } = await supabase.auth.getUser()

  const { pathname, search } = request.nextUrl
  if (isProtectedPath(pathname) && !user) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('next', `${pathname}${search}`)
    return NextResponse.redirect(loginUrl)
  }

  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
}
