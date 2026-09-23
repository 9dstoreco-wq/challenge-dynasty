import { notFound } from "next/navigation";
import Sidebar from "@/components/Sidebar";
import BottomNav from "@/components/BottomNav";
import PageHero from "@/components/PageHero";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

interface OrganizationRow {
  id: string;
  name: string;
  organization_type: string | null;
  city: string | null;
  status: string | null;
  owner_id: string | null;
  created_at: string;
}

interface PlatformOverview {
  organizations_total: number;
  organizations_active: number;
  profiles_total: number;
  tournaments_total: number;
  tournament_entries_total: number;
  bookings_total: number;
  shop_orders_total: number;
  marketplace_orders_total: number;
  billing_subscriptions_active: number;
  revenue_paid_cop: number;
  organizations: OrganizationRow[];
}

function formatCOP(value: number): string {
  return new Intl.NumberFormat("es-CO", { style: "currency", currency: "COP", maximumFractionDigits: 0 }).format(
    value
  );
}

export default async function MasterPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) notFound();

  const { data: isAdmin } = await supabase.rpc("is_platform_admin");
  if (!isAdmin) notFound();

  const { data: overview, error } = await supabase.rpc("get_platform_overview");
  const data = (overview ?? null) as PlatformOverview | null;

  return (
    <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
          <PageHero>
            <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">PLATFORM MASTER</div>
            <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">Vista maestra</h1>
            <p className="text-white/50 mt-2">Todo el ecosistema DINASTY, en un solo lugar. Solo visible para ti.</p>
          </PageHero>

          {error || !data ? (
            <div className="mt-8 rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-8 text-center text-white/45">
              No se pudo cargar la vista general{error ? `: ${error.message}` : "."}
            </div>
          ) : (
            <>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-8">
                <StatCard label="Organizaciones" value={data.organizations_total} sub={`${data.organizations_active} activas`} />
                <StatCard label="Usuarios" value={data.profiles_total} />
                <StatCard label="Torneos" value={data.tournaments_total} sub={`${data.tournament_entries_total} inscripciones`} />
                <StatCard label="Reservas" value={data.bookings_total} />
                <StatCard label="Órdenes tienda" value={data.shop_orders_total} />
                <StatCard label="Órdenes marketplace" value={data.marketplace_orders_total} />
                <StatCard label="Suscripciones activas" value={data.billing_subscriptions_active} />
                <StatCard label="Ingresos cobrados" value={formatCOP(data.revenue_paid_cop)} isText />
              </div>

              <div className="mt-10">
                <div className="text-xs text-[#D4AF37] font-black tracking-widest mb-3">ORGANIZACIONES</div>
                {data.organizations.length === 0 ? (
                  <div className="rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-8 text-center text-white/45">
                    Todavía no hay organizaciones registradas.
                  </div>
                ) : (
                  <div className="rounded-3xl border border-white/10 bg-[#161616] overflow-hidden">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="text-left text-white/40 text-xs uppercase tracking-wider">
                          <th className="px-4 py-3">Nombre</th>
                          <th className="px-4 py-3">Tipo</th>
                          <th className="px-4 py-3">Ciudad</th>
                          <th className="px-4 py-3">Estado</th>
                          <th className="px-4 py-3">Creada</th>
                        </tr>
                      </thead>
                      <tbody>
                        {data.organizations.map((org) => (
                          <tr key={org.id} className="border-t border-white/5">
                            <td className="px-4 py-3 font-bold">{org.name}</td>
                            <td className="px-4 py-3 text-white/60">{org.organization_type ?? "—"}</td>
                            <td className="px-4 py-3 text-white/60">{org.city ?? "—"}</td>
                            <td className="px-4 py-3 text-white/60">{org.status ?? "—"}</td>
                            <td className="px-4 py-3 text-white/40">
                              {new Date(org.created_at).toLocaleDateString("es-CO")}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </>
          )}
        </div>
      </main>
      <BottomNav />
    </div>
  );
}

function StatCard({ label, value, sub, isText }: { label: string; value: number | string; sub?: string; isText?: boolean }) {
  return (
    <div className="rounded-3xl border border-white/10 bg-[#161616] p-5">
      <div className="text-xs text-[#D4AF37] font-black tracking-widest">{label}</div>
      <div className={`font-display font-black tracking-wide mt-2 ${isText ? "text-2xl md:text-3xl" : "text-4xl"}`}>
        {value}
      </div>
      {sub ? <div className="text-white/40 text-xs mt-1">{sub}</div> : null}
    </div>
  );
}
