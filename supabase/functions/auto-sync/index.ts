import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Power Automate proxy URL — store in Supabase secrets as POWER_AUTOMATE_URL
const POWER_AUTOMATE_URL = Deno.env.get("POWER_AUTOMATE_URL") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Call Bisan API through Power Automate proxy
async function callBisanApi(url: string): Promise<any> {
  const response = await fetch(POWER_AUTOMATE_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url, method: "GET" }),
  });
  if (!response.ok) throw new Error(`Power Automate error: ${response.status}`);
  return response.json();
}

async function syncContacts(supabase: any): Promise<number> {
  const url =
    "https://gw.bisan.com/api/v2/jalaf/contact?fields=code,nameAR,area,area.name,salesman,streetAddress,taxId,phone&search=enabled:yes AND type <: 009";
  const data = await callBisanApi(url);
  const rows: any[] = data.rows ?? [];
  if (rows.length === 0) return 0;

  const now = new Date().toISOString();
  const contacts = rows.map((r: any) => ({
    code: r.code ?? "",
    name_ar: r.nameAR ?? "",
    area: r.area ?? null,
    area_name: r["area.name"] ?? null,
    salesman: r.salesman ?? null,
    street_address: r.streetAddress ?? null,
    tax_id: r.taxId ?? null,
    phone: r.phone ?? null,
    last_changed: now,
  }));

  // Delete all and re-insert (matches Flutter syncContacts logic)
  await supabase.from("contacts").delete().neq("id", 0);
  const batchSize = 100;
  for (let i = 0; i < contacts.length; i += batchSize) {
    await supabase.from("contacts").insert(contacts.slice(i, i + batchSize));
  }
  return contacts.length;
}

async function syncItems(supabase: any): Promise<number> {
  const url =
    "https://gw.bisan.com/api/v2/jalaf/item?fields=code,nameAR,brand,brand.nameAR,itemCategory,itemCategory.nameAR,name,unitList.unit,unitList.packVolume,partNumber,unit,warranty&search=enabled:yes AND brand>:001 AND brand<:905";
  const data = await callBisanApi(url);
  const rows: any[] = data.rows ?? [];
  if (rows.length === 0) return 0;

  const items = rows.map((r: any) => ({
    code: r.code ?? "",
    name_ar: r.nameAR ?? "",
    name_en: r.name ?? null,
    brand_code: r.brand ?? null,
    brand_name_ar: r["brand.nameAR"] ?? null,
    item_category_code: r.itemCategory ?? null,
    item_category_name_ar: r["itemCategory.nameAR"] ?? null,
    unit_list: (r.unitList ?? []).map((u: any) => ({
      unit: u.unit,
      pack_volume: u.packVolume,
    })),
    part_number: r.partNumber ?? null,
    unit: r.unit ?? null,
    warranty: r.warranty ?? null,
  }));

  const batchSize = 100;
  for (let i = 0; i < items.length; i += batchSize) {
    await supabase
      .from("items")
      .upsert(items.slice(i, i + batchSize), { onConflict: "code" });
  }
  return items.length;
}

async function syncWarehouses(supabase: any): Promise<number> {
  const url =
    "https://gw.bisan.com/api/v2/jalaf/warehouse?fields=code,nameAR&search=enabled:yes";
  const data = await callBisanApi(url);
  const rows: any[] = data.rows ?? [];
  if (rows.length === 0) return 0;

  const warehouses = rows.map((r: any) => ({
    code: r.code ?? "",
    name_ar: r.nameAR ?? "",
  }));

  const batchSize = 100;
  for (let i = 0; i < warehouses.length; i += batchSize) {
    await supabase
      .from("warehouses")
      .upsert(warehouses.slice(i, i + batchSize), { onConflict: "code" });
  }
  return warehouses.length;
}

async function syncFuelContacts(supabase: any): Promise<number> {
  const url =
    "https://gw.bisan.com/api/v2/jalaf/contact?fields=code,nameAR&search=type:049";
  const data = await callBisanApi(url);
  const rows: any[] = data.rows ?? [];
  if (rows.length === 0) return 0;

  const contacts = rows.map((r: any) => ({
    code: r.code ?? "",
    name: r.nameAR ?? "",
  }));

  await supabase.from("fuel_contacts").delete().neq("id", 0);
  await supabase.from("fuel_contacts").insert(contacts);
  return contacts.length;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const result = {
    contacts: 0,
    items: 0,
    warehouses: 0,
    fuel_contacts: 0,
    status: "success",
    error: null as string | null,
    synced_at: new Date().toISOString(),
  };

  try {
    result.contacts = await syncContacts(supabase);
    result.items = await syncItems(supabase);
    result.warehouses = await syncWarehouses(supabase);
    result.fuel_contacts = await syncFuelContacts(supabase);
  } catch (e: any) {
    result.status = "error";
    result.error = e.message ?? String(e);
  }

  // Log the result to sync_logs table
  await supabase.from("sync_logs").insert({
    synced_at: result.synced_at,
    contacts_count: result.contacts,
    items_count: result.items,
    warehouses_count: result.warehouses,
    fuel_contacts_count: result.fuel_contacts,
    status: result.status,
    error_message: result.error,
  });

  return new Response(JSON.stringify(result), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status: result.status === "success" ? 200 : 500,
  });
});
