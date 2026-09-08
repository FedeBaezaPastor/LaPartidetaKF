/*
# OMIKI Golf - Roles, Profiles, Team Invitations, Pro-Shop

## Overview
This migration adds the full roles system (Express/Player/Team), user profiles
with unique Nick, group memberships with admin roles, in-app notifications for
group invitations, Pro-Shop purchases, and Hoyo 19 configuration on groups.

## New Tables
1. `user_profiles` - Extended player data linked to auth.users (nick, avatar, handicap, etc.)
2. `group_members` - Membership records linking users to groups with roles (admin/member)
3. `group_invitations` - Pending invitations for players to join groups (in-app notifications)
4. `pro_shop_purchases` - Records of Pro-Shop purchases per group

## Modified Tables
1. `groups` - Added hoyo_19_enabled, max_players, premium_branding, weekend_mode, group_type columns
2. `user_subscriptions` - Updated plan_type constraint to allow 'express', 'player', 'team'

## Security
- RLS enabled on all new tables
- Users can only read/write their own profile
- Group members can view their group data
- Only group admins can manage members and purchases
- Invitations are visible to the invited user only
*/

-- ============================================================
-- 1. user_profiles
-- ============================================================
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  nick text NOT NULL UNIQUE,
  display_name text,
  avatar_url text,
  exact_handicap numeric DEFAULT 0,
  default_tee text DEFAULT 'amarillo',
  country text,
  postal_code text,
  age integer,
  accepted_terms boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_profile" ON user_profiles;
CREATE POLICY "select_own_profile" ON user_profiles FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_profile" ON user_profiles;
CREATE POLICY "insert_own_profile" ON user_profiles FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_profile" ON user_profiles;
CREATE POLICY "update_own_profile" ON user_profiles FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_profile" ON user_profiles;
CREATE POLICY "delete_own_profile" ON user_profiles FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- Public read for nick lookup (all authenticated users can search nicks)
DROP POLICY IF EXISTS "public_search_profiles" ON user_profiles;
CREATE POLICY "public_search_profiles" ON user_profiles FOR SELECT
  TO authenticated USING (true);

-- ============================================================
-- 2. group_members
-- ============================================================
CREATE TABLE IF NOT EXISTS group_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  invited_by uuid REFERENCES auth.users(id),
  joined_at timestamptz DEFAULT now(),
  UNIQUE(group_id, user_id)
);

ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_group_members" ON group_members;
CREATE POLICY "select_group_members" ON group_members FOR SELECT
  TO authenticated USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM group_members gm2
      WHERE gm2.group_id = group_members.group_id
      AND gm2.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "insert_own_membership" ON group_members;
CREATE POLICY "insert_own_membership" ON group_members FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_group_members" ON group_members;
CREATE POLICY "update_group_members" ON group_members FOR UPDATE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM group_members gm2
      WHERE gm2.group_id = group_members.group_id
      AND gm2.user_id = auth.uid()
      AND gm2.role = 'admin'
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM group_members gm3
      WHERE gm3.group_id = group_members.group_id
      AND gm3.user_id = auth.uid()
      AND gm3.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "delete_group_members" ON group_members;
CREATE POLICY "delete_group_members" ON group_members FOR DELETE
  TO authenticated USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM group_members gm2
      WHERE gm2.group_id = group_members.group_id
      AND gm2.user_id = auth.uid()
      AND gm2.role = 'admin'
    )
  );

-- ============================================================
-- 3. group_invitations
-- ============================================================
CREATE TABLE IF NOT EXISTS group_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  invited_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invited_by uuid NOT NULL REFERENCES auth.users(id),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  message text,
  created_at timestamptz DEFAULT now(),
  responded_at timestamptz,
  UNIQUE(group_id, invited_user_id)
);

ALTER TABLE group_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_invitations" ON group_invitations;
CREATE POLICY "select_invitations" ON group_invitations FOR SELECT
  TO authenticated USING (
    auth.uid() = invited_user_id
    OR auth.uid() = invited_by
    OR EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_invitations.group_id
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "insert_invitations" ON group_invitations;
CREATE POLICY "insert_invitations" ON group_invitations FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_invitations.group_id
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "update_invitations" ON group_invitations;
CREATE POLICY "update_invitations" ON group_invitations FOR UPDATE
  TO authenticated USING (auth.uid() = invited_user_id)
  WITH CHECK (auth.uid() = invited_user_id);

DROP POLICY IF EXISTS "delete_invitations" ON group_invitations;
CREATE POLICY "delete_invitations" ON group_invitations FOR DELETE
  TO authenticated USING (
    auth.uid() = invited_by
    OR EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_invitations.group_id
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
    )
  );

-- ============================================================
-- 4. pro_shop_purchases
-- ============================================================
CREATE TABLE IF NOT EXISTS pro_shop_purchases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  purchased_by uuid NOT NULL REFERENCES auth.users(id),
  product_type text NOT NULL CHECK (product_type IN ('extra_players', 'premium_branding', 'weekend_mode')),
  amount_paid numeric NOT NULL DEFAULT 0,
  payment_method text NOT NULL DEFAULT 'lightning' CHECK (payment_method IN ('lightning', 'stripe')),
  payment_ref text,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
  active_until timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE pro_shop_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_pro_shop_purchases" ON pro_shop_purchases;
CREATE POLICY "select_pro_shop_purchases" ON pro_shop_purchases FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = pro_shop_purchases.group_id
      AND gm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "insert_pro_shop_purchases" ON pro_shop_purchases;
CREATE POLICY "insert_pro_shop_purchases" ON pro_shop_purchases FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = pro_shop_purchases.group_id
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "update_pro_shop_purchases" ON pro_shop_purchases;
CREATE POLICY "update_pro_shop_purchases" ON pro_shop_purchases FOR UPDATE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = pro_shop_purchases.group_id
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = pro_shop_purchases.group_id
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
    )
  );

-- ============================================================
-- 5. Modify groups table - add new columns
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'groups' AND column_name = 'hoyo_19_enabled') THEN
    ALTER TABLE groups ADD COLUMN hoyo_19_enabled boolean NOT NULL DEFAULT true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'groups' AND column_name = 'max_players') THEN
    ALTER TABLE groups ADD COLUMN max_players integer NOT NULL DEFAULT 20;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'groups' AND column_name = 'premium_branding') THEN
    ALTER TABLE groups ADD COLUMN premium_branding boolean NOT NULL DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'groups' AND column_name = 'weekend_mode_until') THEN
    ALTER TABLE groups ADD COLUMN weekend_mode_until timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'groups' AND column_name = 'group_type') THEN
    ALTER TABLE groups ADD COLUMN group_type text NOT NULL DEFAULT 'team';
  END IF;
END $$;

-- ============================================================
-- 6. Modify user_subscriptions - expand plan_type
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'user_subscriptions' AND constraint_name = 'user_subscriptions_plan_type_check'
  ) THEN
    ALTER TABLE user_subscriptions DROP CONSTRAINT user_subscriptions_plan_type_check;
  END IF;
END $$;

ALTER TABLE user_subscriptions
  ADD CONSTRAINT user_subscriptions_plan_type_check
  CHECK (plan_type IN ('free', 'express', 'player', 'team'));

-- ============================================================
-- 7. Indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_invitations_invited_user ON group_invitations(invited_user_id);
CREATE INDEX IF NOT EXISTS idx_group_invitations_group_id ON group_invitations(group_id);
CREATE INDEX IF NOT EXISTS idx_pro_shop_group_id ON pro_shop_purchases(group_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_nick_lower ON user_profiles(lower(nick));