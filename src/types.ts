export interface GolfHole {
  id: string;
  course_id: string;
  hole_number: number;
  par: 3 | 4 | 5;
  stroke_index: number;
  created_at: string;
  updated_at: string;
}

export interface GolfCourse {
  id: string;
  name: string;
  description?: string;
  created_at: string;
}

export interface Tee {
  id: string;
  course_id: string;
  name: string;
  color: string;
  slope_18: number;
  slope_9_i: number;
  slope_9_ii: number;
  created_at: string;
}

export interface Group {
  id: string;
  name?: string;
  group_code: string;
  created_at: string;
  created_by?: string;
  hoyo_19_enabled?: boolean;
  max_players?: number;
  premium_branding?: boolean;
  weekend_mode_until?: string | null;
  group_type?: string;
}

export type PlanType = 'express' | 'player' | 'team';

export interface UserProfile {
  id: string;
  user_id: string;
  nick: string;
  display_name?: string;
  avatar_url?: string;
  exact_handicap: number;
  default_tee: string;
  country?: string;
  postal_code?: string;
  age?: number;
  accepted_terms: boolean;
  created_at: string;
  updated_at: string;
}

export interface GroupMember {
  id: string;
  group_id: string;
  user_id: string;
  role: 'admin' | 'member';
  invited_by?: string;
  joined_at: string;
  profile?: UserProfile;
}

export interface GroupInvitation {
  id: string;
  group_id: string;
  invited_user_id: string;
  invited_by: string;
  status: 'pending' | 'accepted' | 'rejected';
  message?: string;
  created_at: string;
  responded_at?: string;
  group?: Group;
  inviter_profile?: UserProfile;
}

export interface ProShopPurchase {
  id: string;
  group_id: string;
  purchased_by: string;
  product_type: 'extra_players' | 'premium_branding' | 'weekend_mode';
  amount_paid: number;
  payment_method: 'lightning' | 'stripe';
  payment_ref?: string;
  status: 'pending' | 'completed' | 'failed';
  active_until?: string;
  created_at: string;
}

export interface Player {
  id: string;
  name: string;
  exact_handicap: number;
  exact_handicap_18?: number;
  created_at: string;
  updated_at: string;
}

export interface RoundPlayer {
  id: string;
  round_id: string;
  user_id?: string;
  player_id?: string;
  name: string;
  exact_handicap: number;
  exact_handicap_18?: number;
  playing_handicap: number;
  created_at: string;
}

export interface RoundScore {
  id: string;
  round_id: string;
  player_id: string;
  hole_number: number;
  gross_strokes: number;
  strokes_received: number;
  net_strokes: number;
  stableford_points: number;
  no_paso_rojas: boolean;
  abandoned: boolean;
  mode_points: number;
  created_at: string;
  updated_at: string;
}

export type GameMode = 'stableford' | 'match' | 'sindicato' | 'parejas';

export interface GolfRound {
  id: string;
  course_id: string;
  created_by: string;
  user_id: string;
  group_id?: string;
  num_holes: 9 | 18;
  holes_range?: '1-9' | '10-18';
  use_slope: boolean;
  tee_id?: string;
  manual_slope?: number;
  game_mode: GameMode;
  status: 'active' | 'completed' | 'cancelled';
  reference_number: number;
  access_code: string;
  created_at: string;
  updated_at: string;
}

export interface RoundWithDetails {
  round: GolfRound;
  holes: GolfHole[];
  players: RoundPlayer[];
  scores: RoundScore[];
}

export interface PlayerStats {
  playerId: string;
  playerName: string;
  totalPoints: number;
  scoresEntered: number;
  totalHoles: number;
}

export type RoundStatus = 'active' | 'completed' | 'cancelled';
