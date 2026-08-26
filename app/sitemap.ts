import type { MetadataRoute } from 'next'
export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.NEXT_PUBLIC_SITE_URL || 'https://challenge-dynasty.com'
  return ['/','/players','/ranking','/arena','/sports','/competitions','/season','/missions','/rewards','/partners','/clubs','/tricks','/search'].map((path)=>({url:`${base}${path}`,changeFrequency:'daily',priority:path==='/'?1:0.6}))
}
