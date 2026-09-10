import { supabase } from "./supabaseClient";
export async function getReadOnly(): Promise<boolean> {
  const { data, error } = await supabase.rpc("is_app_user_read_only");
  if (error) {
    if (error.code === "PGRST202") return false;
    throw error;
  }
  return data === true;
}
