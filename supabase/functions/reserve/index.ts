// Deploy with --no-verify-jwt. Keep service role and email credentials ONLY in Edge Function secrets.
import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
const origin = Deno.env.get('SHOP_ORIGIN') || '';
const cors = { 'Access-Control-Allow-Origin': origin, 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' };
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control':'no-store', 'Vary':'Origin' } });
const esc = (s: unknown) => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c] ?? c));
Deno.serve(async req => {
 if (!origin) return json({error:'Checkout setup is incomplete. Contact the PTFA.'},503);
 if (req.headers.get('origin') !== origin) return json({error:'Origin not allowed'},403);
 if (req.method === 'OPTIONS') return new Response(null, {headers:cors});
 if (req.method === 'GET') return json({checkout_configured:Boolean(Deno.env.get('SUPABASE_URL')&&Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')),reservation_email_configured:Boolean(Deno.env.get('RESEND_API_KEY')&&Deno.env.get('EMAIL_FROM')),anti_spam_configured:Boolean(Deno.env.get('TURNSTILE_SECRET_KEY'))});
 if (req.method !== 'POST') return json({error:'POST required'},405);
 try {
  const raw=await req.text();
  if(new TextEncoder().encode(raw).length>16000)return json({error:'Request too large'},413);
  let body;try{body=JSON.parse(raw)}catch{return json({error:'Invalid JSON'},400)}
  if(!body||typeof body!=='object'||Array.isArray(body))return json({error:'Invalid request'},400);
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(body.request_id||''))return json({error:'Invalid checkout reference'},400);
  if(typeof body.name!=='string'||typeof body.child_class!=='string'||typeof body.email!=='string')return json({error:'Invalid contact details'},400);
  // Honeypot and optional Turnstile verification to limit automated fake orders.
  if (body.website) return json({error:'Request rejected'},400);
  const secret = Deno.env.get('TURNSTILE_SECRET_KEY');
  if (secret) {
   const token = String(body.turnstile_token || '');
   if (!token) return json({error:'Please complete the anti-spam check'},400);
   const f = new FormData(); f.set('secret',secret); f.set('response',token);
   const verification = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify',{method:'POST',body:f});
   const result = await verification.json();
   if (!verification.ok || !result.success || result.hostname !== new URL(origin).hostname) return json({error:'Anti-spam check failed'},400);
  }
  const name=String(body.name||'').trim(), childClass=String(body.child_class||'').trim(), email=String(body.email||'').trim();
  if(name.length<2||name.length>120||childClass.length<1||childClass.length>80||email.length>254||!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email))return json({error:'Invalid contact details'},400);
  const lines=body.lines;
  if (!Array.isArray(lines) || lines.length<1 || lines.length>20 || !lines.every((l: any)=>l&&Number.isSafeInteger(l.stock_id)&&l.stock_id>0&&Number.isSafeInteger(l.quantity)&&l.quantity>=1&&l.quantity<=20)) return json({error:'Invalid basket'},400);
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const {data,error}=await db.rpc('reserve_once',{p_request_id:body.request_id,p_name:name,p_class:childClass,p_email:email,p_lines:lines});
  if(error) return json({error:error.message},400);
  if(data.replayed)return json({reservation_id:data.id,total_pence:data.total_pence,email_status:data.email_status});
  const key=Deno.env.get('RESEND_API_KEY'), sender=Deno.env.get('EMAIL_FROM');
  let emailStatus='not_configured';
  if(key&&sender){
   const rows=data.lines.map((l:any)=>`<li>${esc(l.name)} — ${esc(l.size)}, ${esc(l.condition)} × ${l.quantity} (£${(l.price_pence*l.quantity/100).toFixed(2)})</li>`).join('');
   const total=`£${(data.total_pence/100).toFixed(2)}`;
   const paypal='https://www.paypal.com/paypalme/spptfa';
   const messages=[
    {kind:'admin',to:'spsptfa.useduniform@gmail.com',subject:'New uniform reservation',html:`<p>New reservation ${esc(data.id)}</p><p>Parent: ${esc(name)}<br>Child/class: ${esc(childClass)}<br>Email: ${esc(email)}</p><ul>${rows}</ul><p>Total: ${total}</p>`},
    {kind:'parent',to:email,subject:'Your SPS PTFA uniform reservation',html:`<p>Dear ${esc(name)},</p><p>Thank you for reserving uniform.</p><ul>${rows}</ul><p><strong>Total: ${total}</strong></p><p>Please pay within 3 days at <a href="${paypal}">${paypal}</a>, using your name and child's class as the reference. The PTFA will arrange collection.</p><p>SPS PTFA Used Uniform Team</p>`}
   ];
   const outcomes=await Promise.all(messages.map(async m=>{
    try {const r=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json','Idempotency-Key':`reservation-${data.id}-${m.kind}`},signal:AbortSignal.timeout(10000),body:JSON.stringify({from:sender,to:[m.to],subject:m.subject,html:m.html,reply_to:'spsptfa.useduniform@gmail.com'})});return r.ok;} catch{return false;}
   }));
   emailStatus=outcomes.every(Boolean)?'accepted':'failed';
   if(emailStatus==='failed') console.error('Reservation emails failed; reservation id:',data.id);
  }
  const logged=await db.from('reservations').update({email_status:emailStatus}).eq('id',data.id);
  if(logged.error)console.error('Email status update failed for reservation',data.id);
  return json({reservation_id:data.id,total_pence:data.total_pence,email_status:emailStatus});
 }catch(e){console.error(e);return json({error:'Unable to process reservation'},500);}
});
