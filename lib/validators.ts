// Validaciones compartidas que deben correr en el servidor (nunca confiar solo en el formulario).

// Dominios de video permitidos para "pruebas" de trucos (SkillSubmissionForm). Antes el campo
// aceptaba cualquier URL con "https?://" (la validacion basica del navegador para type="url"),
// asi que cualquiera podia mandar un enlace a lo que fuera.
const ALLOWED_VIDEO_HOSTS = [
  'youtube.com',
  'youtu.be',
  'tiktok.com',
  'instagram.com',
  'facebook.com',
  'fb.watch',
  'vimeo.com',
]

export function isAllowedVideoUrl(raw: string): boolean {
  let u: URL
  try {
    u = new URL(raw)
  } catch {
    return false
  }
  if (u.protocol !== 'https:') return false
  const host = u.hostname.toLowerCase()
  return ALLOWED_VIDEO_HOSTS.some((allowed) => host === allowed || host.endsWith(`.${allowed}`))
}

// Username: 3-20 caracteres, empieza con letra, solo letras/numeros/guion bajo de ahi en adelante.
const USERNAME_FORMAT = /^[a-z][a-z0-9_]{2,19}$/

// Nombres que no se pueden dejar tomar como username porque se prestan a confusion/suplantacion
// (rutas propias de la app, roles, o palabras ofensivas obvias en el contexto del producto).
const RESERVED_USERNAMES = new Set([
  'admin', 'administrator', 'root', 'support', 'help', 'moderator', 'mod',
  'system', 'null', 'undefined', 'api', 'login', 'logout', 'register',
  'settings', 'onboarding', 'dynasty', 'challenge', 'challengedynasty',
  'official', 'staff', 'team', 'dynastyteam', 'security', 'webmaster',
  'superadmin', 'owner', 'test', 'anonymous', 'me', 'you', 'everyone',
])

export function isValidUsernameFormat(username: string): boolean {
  return USERNAME_FORMAT.test(username)
}

export function isReservedUsername(username: string): boolean {
  return RESERVED_USERNAMES.has(username.toLowerCase())
}
