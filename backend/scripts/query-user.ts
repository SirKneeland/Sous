import { createClient } from '@supabase/supabase-js';
const sb = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);
sb.from('users').select('id, email, is_byok_eligible').eq('email', 'john.kneeland+sandbox@gmail.com').then(({ data, error }) => {
  if (error) { console.error('ERROR:', error); process.exit(1); }
  console.log(JSON.stringify(data, null, 2));
});
