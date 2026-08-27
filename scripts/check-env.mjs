const required = ['NEXT_PUBLIC_SUPABASE_URL','NEXT_PUBLIC_SUPABASE_ANON_KEY'];
const missing = required.filter((k) => !process.env[k]);
if (missing.length) {
  console.error('Missing environment variables:', missing.join(', '));
  console.error('Configure them in Vercel Production/Preview or .env.local before build/runtime validation.');
  process.exit(1);
}
console.log('Environment check: PASS');
