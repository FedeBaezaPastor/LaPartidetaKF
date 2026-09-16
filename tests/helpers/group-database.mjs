export async function createGroupDatabase(db) {
 await db.exec(`
 CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('request.uid',true),'')::uuid$$;
 CREATE TABLE auth.users(id uuid PRIMARY KEY);
 CREATE TABLE app_user_restrictions(user_id uuid PRIMARY KEY,read_only boolean);
 CREATE FUNCTION is_app_user_read_only() RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$SELECT coalesce((SELECT read_only FROM public.app_user_restrictions WHERE user_id=auth.uid()),false)$$;
 CREATE TABLE app_administrators(user_id uuid,status text);
 CREATE TABLE user_profiles(user_id uuid PRIMARY KEY,nick text,display_name text,avatar_url text,exact_handicap numeric);
 CREATE TABLE groups(id uuid PRIMARY KEY,user_auth_id uuid);
 CREATE TABLE group_members(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),group_id uuid,user_id uuid,role text,invited_by uuid,joined_at timestamptz DEFAULT now(),UNIQUE(group_id,user_id));
 CREATE TABLE group_invitations(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),group_id uuid,invited_user_id uuid,invited_by uuid,status text,responded_at timestamptz,UNIQUE(group_id,invited_user_id));
 CREATE FUNCTION is_group_member(g uuid) RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$SELECT EXISTS(SELECT 1 FROM public.group_members WHERE group_id=g AND user_id=auth.uid())$$;
 CREATE FUNCTION can_manage_group_messages(g uuid) RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$SELECT auth.uid() IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.app_administrators WHERE user_id=auth.uid()) AND (EXISTS(SELECT 1 FROM public.groups WHERE id=g AND user_auth_id=auth.uid()) OR EXISTS(SELECT 1 FROM public.group_members WHERE group_id=g AND user_id=auth.uid() AND role='admin'))$$;
 CREATE TABLE players(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),group_id uuid,name text,exact_handicap numeric NOT NULL DEFAULT 0,exact_handicap_18 numeric DEFAULT 0,playing_handicap numeric,created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now(),UNIQUE(name,group_id));
 CREATE TABLE tees(id uuid PRIMARY KEY,slope_18 numeric,slope_9_i numeric,slope_9_ii numeric);
 CREATE TABLE golf_rounds(id uuid PRIMARY KEY,group_id uuid,num_holes int,use_slope boolean,manual_slope numeric,holes_range text,tee_id uuid,status text DEFAULT 'completed',game_mode text DEFAULT 'stableford');
 CREATE TABLE round_players(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),round_id uuid,player_id uuid,user_id uuid,name text,exact_handicap numeric,exact_handicap_18 numeric,playing_handicap numeric,created_at timestamptz DEFAULT now());
 CREATE TABLE round_scores(round_id uuid,player_id uuid,stableford_points numeric,mode_points numeric,spanish_hands boolean DEFAULT false);
 CREATE TABLE app_admin_audit(id bigint GENERATED ALWAYS AS IDENTITY,actor_user_id uuid,actor_alias text,action text,target_user_id uuid,details jsonb);
 CREATE TABLE archived_rounds(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),group_id uuid,course_name text,season_id uuid,played_at timestamptz,archived_at timestamptz DEFAULT now(),final_ranking jsonb,player_stats jsonb,hole_scores jsonb DEFAULT '[]',handicap_adjusted boolean DEFAULT false);
 CREATE TABLE daily_rankings(group_id uuid,ranking_date date,player_name text,total_points numeric,hcp_juego int,position int,receives_beer boolean,pays_beer boolean,total_strokes int,total_stableford_net int,handicap_play numeric,UNIQUE(group_id,ranking_date,player_name));
 CREATE TABLE handicap_adjustments(group_id uuid,player_id uuid,player_name text,adjustment_date date,ranking_position int,hcp_before numeric,hcp_after numeric,adjustment numeric,playing_handicap_before numeric,archived_round_id uuid,created_at timestamptz DEFAULT now(),UNIQUE(group_id,player_id,archived_round_id));
 CREATE FUNCTION revert_handicap_adjustments_for_round() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RETURN OLD; END$$;
 CREATE TRIGGER revert_archive BEFORE DELETE ON archived_rounds FOR EACH ROW EXECUTE FUNCTION revert_handicap_adjustments_for_round();
 CREATE FUNCTION auto_calculate_daily_ranking() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN PERFORM apply_handicap_adjustments_for_round(NEW.id); RETURN NEW; END$$;
 CREATE TRIGGER archive_adjust AFTER INSERT ON archived_rounds FOR EACH ROW EXECUTE FUNCTION auto_calculate_daily_ranking();
 `);
}
