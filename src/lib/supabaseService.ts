import { createClientComponentClient } from "@supabase/auth-helpers-nextjs";
import { supabase as supabaseClient } from "@/utils/supabase";
import { Database } from "@/types/supabase";

// User Authentication and Profile Management
export const getUserProfile = async (userId: string) => {
  const supabase = createClientComponentClient<Database>();

  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .maybeSingle();

  if (error && error.code !== "PGRST116") throw error;
  return data;
};

export const updateUserProfile = async (userId: string, profileData: any) => {
  const supabase = createClientComponentClient<Database>();

  const { data, error } = await supabase.from("profiles").upsert({
    id: userId,
    ...profileData,
    updated_at: new Date().toISOString(),
  });

  if (error) throw error;
  return data;
};

// Subscription Management
export const getUserSubscription = async (userId: string) => {
  const supabase = createClientComponentClient<Database>();

  const { data, error } = await supabase
    .from("subscriptions")
    .select("*")
    .eq("user_id", userId)
    .eq("status", "active")
    .maybeSingle();

  if (error && error.code !== "PGRST116") throw error;
  return data;
};

export const getBillingHistory = async (userId: string, limit = 10) => {
  const supabase = createClientComponentClient<Database>();

  const { data, error } = await supabase
    .from("billing_history")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error && error.code !== "PGRST116") throw error;
  return data || [];
};

// User Credits Management
export const getUserCredits = async (userId: string) => {
  const supabase = createClientComponentClient<Database>();

  const { data, error } = await supabase
    .from("user_credits")
    .select("*")
    .eq("user_id", userId)
    .single();

  if (error && error.code !== "PGRST116") throw error;
  return data;
};

export const updateUserCredits = async (userId: string, credits: number) => {
  const supabase = createClientComponentClient<Database>();

  // First check if user has credits record
  const { data: existingCredits } = await supabase
    .from("user_credits")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  if (existingCredits) {
    // Update existing record
    const { data, error } = await supabase
      .from("user_credits")
      .update({ credits, updated_at: new Date().toISOString() })
      .eq("user_id", userId)
      .select();

    if (error) throw error;
    return data;
  } else {
    // Create new record
    const { data, error } = await supabase
      .from("user_credits")
      .insert({
        user_id: userId,
        credits,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select();

    if (error) throw error;
    return data;
  }
};

// Advanced Queries with Joins
export const getUserWithProfileAndSubscription = async (userId: string) => {
  const supabase = createClientComponentClient<Database>();

  const { data, error } = await supabase
    .from("profiles")
    .select(
      `
      *,
      subscriptions:subscriptions(*, plan:subscription_plans(*))
    `,
    )
    .eq("id", userId)
    .single();

  if (error) throw error;
  return data;
};

// Pagination
export const getPaginatedBillingHistory = async (
  userId: string,
  page = 1,
  pageSize = 10,
) => {
  const supabase = createClientComponentClient<Database>();

  // Calculate range start and end
  const from = (page - 1) * pageSize;
  const to = from + pageSize - 1;

  const { data, error, count } = await supabase
    .from("billing_history")
    .select("*", { count: "exact" })
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .range(from, to);

  if (error) throw error;
  return { data: data || [], count: count || 0 };
};

// Real-time subscriptions
export const subscribeToUserCredits = (
  userId: string,
  callback: (payload: any) => void,
) => {
  const supabase = createClientComponentClient<Database>();

  const subscription = supabase
    .channel("user_credits_changes")
    .on(
      "postgres_changes",
      {
        event: "*",
        schema: "public",
        table: "user_credits",
        filter: `user_id=eq.${userId}`,
      },
      callback,
    )
    .subscribe();

  return () => {
    supabase.removeChannel(subscription);
  };
};

// Server-side functions (for API routes)
export const serverGetUserProfile = async (userId: string) => {
  const { data, error } = await supabaseClient
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .single();

  if (error) throw error;
  return data;
};

export const serverUpdateUserCredits = async (
  userId: string,
  credits: number,
) => {
  // First check if user has credits record
  const { data: existingCredits } = await supabaseClient
    .from("user_credits")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  if (existingCredits) {
    // Update existing record
    const { data, error } = await supabaseClient
      .from("user_credits")
      .update({
        credits,
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId)
      .select();

    if (error) throw error;
    return data;
  } else {
    // Create new record
    const { data, error } = await supabaseClient
      .from("user_credits")
      .insert({
        user_id: userId,
        credits,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select();

    if (error) throw error;
    return data;
  }
};
