BEGIN;
-- Accent/punctuation-insensitive words, independent of their order in the query.
CREATE FUNCTION public.admin_search_words(p_text text) RETURNS text[]
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT regexp_split_to_array(trim(regexp_replace(translate(lower(coalesce(p_text,'')), 'áàäâéèëêíìïîóòöôúùüûñç', 'aaaaeeeeiiiioooouuuunc'), '[^a-z0-9]+', ' ', 'g')), ' +');
$$;
CREATE FUNCTION public.admin_search_typo(p_word text,p_term text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE i integer:=1; j integer:=1; mistakes integer:=0; a integer:=length(p_word); b integer:=length(p_term);
BEGIN
 IF a<4 OR b<4 OR abs(a-b)>1 THEN RETURN false; END IF;
 WHILE i<=a AND j<=b LOOP
  IF substr(p_word,i,1)=substr(p_term,j,1) THEN i:=i+1; j:=j+1;
  ELSE
   mistakes:=mistakes+1;
   IF mistakes>1 THEN RETURN false; END IF;
   IF a>b THEN i:=i+1; ELSIF b>a THEN j:=j+1; ELSE i:=i+1;j:=j+1; END IF;
  END IF;
 END LOOP;
 RETURN mistakes+(a-i+1)+(b-j+1)<=1;
END $$;
CREATE FUNCTION public.admin_search_matches(p_text text,p_query text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT NOT EXISTS (
  SELECT 1 FROM unnest(public.admin_search_words(p_query)) term WHERE term<>'' AND NOT EXISTS (
   SELECT 1 FROM unnest(public.admin_search_words(p_text)) word
   WHERE strpos(word,term)>0 OR public.admin_search_typo(word,term)
  )
 );
$$;
CREATE FUNCTION public.admin_list_app_rounds_v2(p_search text DEFAULT '',p_status text DEFAULT '',p_kind text DEFAULT '',p_page integer DEFAULT 0,p_mode text DEFAULT '',p_group text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT public.is_app_administrator() THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
 IF p_page IS NULL OR p_page<0 OR p_page>100000 OR length(p_search)>200 OR length(p_group)>200 OR p_kind NOT IN ('','quick','group') OR p_mode NOT IN ('','stableford','match','sindicato','parejas') OR p_status NOT IN ('','active','completed','archived','cancelled','deleted','withdrawn') THEN RAISE EXCEPTION 'Filtro inválido'; END IF;
 WITH filtered AS (
 SELECT r.id,r.reference_number,r.created_at,r.updated_at,r.user_id,r.group_id,r.game_mode,r.num_holes,c.name AS course_name,r.status,r.admin_withdrawn_at,
 g.name AS group_name,g.group_code,
 (SELECT count(*) FROM public.round_players p WHERE p.round_id=r.id) AS players_count
 FROM public.golf_rounds r LEFT JOIN public.golf_courses c ON c.id=r.course_id LEFT JOIN public.groups g ON g.id=r.group_id
 WHERE (p_kind='' OR (p_kind='quick' AND r.group_id IS NULL) OR (p_kind='group' AND r.group_id IS NOT NULL))
 AND (p_kind<>'quick' OR p_mode='' OR r.game_mode=p_mode)
 AND (p_kind<>'group' OR public.admin_search_matches(concat_ws(' ',g.name,g.group_code,r.group_id::text),p_group))
 AND (p_status='' OR (p_status='withdrawn' AND r.admin_withdrawn_at IS NOT NULL) OR (r.admin_withdrawn_at IS NULL AND r.status=p_status))
 AND public.admin_search_matches(concat_ws(' ',r.id::text,r.reference_number::text,r.user_id,r.group_id::text,c.name,g.name,g.group_code,
  (SELECT string_agg(p.name,' ') FROM public.round_players p WHERE p.round_id=r.id)),p_search)
 ), page AS (SELECT * FROM filtered ORDER BY created_at DESC,id LIMIT 25 OFFSET p_page*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM filtered),'rounds',coalesce((SELECT jsonb_agg(to_jsonb(page)) FROM page),'[]'::jsonb)) INTO result;
 RETURN result;
END $$;
-- Existing clients retain the old signature during the rollout.
CREATE OR REPLACE FUNCTION public.admin_list_app_rounds(p_search text DEFAULT '',p_status text DEFAULT '',p_kind text DEFAULT '',p_page integer DEFAULT 0)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.admin_list_app_rounds_v2(p_search,p_status,p_kind,p_page,'','');
$$;
REVOKE ALL ON FUNCTION public.admin_search_words(text),public.admin_search_typo(text,text),public.admin_search_matches(text,text),public.admin_list_app_rounds_v2(text,text,text,integer,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_app_rounds_v2(text,text,text,integer,text,text) TO authenticated;
COMMIT;
