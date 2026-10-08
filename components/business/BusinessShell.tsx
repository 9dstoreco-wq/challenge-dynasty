import Link from 'next/link'
import { ArrowLeft } from 'lucide-react'

// Fachada sobria para la cara de "negocio" (dueños de club/cancha). A diferencia del resto de la
// app (estetica de videojuego: dorado, glow, Sidebar con Arena/Cartas/Retos), esta fachada usa un
// fondo neutro sin brillos, una barra simple en vez del Sidebar de jugador, y un acento azul en
// vez de dorado. Pensada para vivir luego en un subdominio propio (clubes.tudominio.com) via
// middleware.ts -- hoy se accede por /negocio dentro del mismo dominio de Vercel.
export default function BusinessShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-[#0B0F14] text-white">
      <header className="border-b border-white/10 bg-[#0E1420]">
        <div className="max-w-5xl mx-auto px-4 md:px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <span className="font-semibold text-[15px] tracking-tight">Challenge Dynasty</span>
            <span className="rounded-full border border-[#3B6EA5]/40 bg-[#3B6EA5]/10 px-2.5 py-0.5 text-[11px] font-medium text-[#8FB8E8]">Negocio</span>
          </div>
          <Link href="/" className="flex items-center gap-1.5 text-sm text-white/55 hover:text-white transition">
            <ArrowLeft size={15} /> Volver a la app
          </Link>
        </div>
      </header>
      <main className="max-w-5xl mx-auto px-4 md:px-6 py-8 md:py-10">{children}</main>
    </div>
  )
}
