-- Allow authenticated users to create a new business and become its owner.
CREATE OR REPLACE FUNCTION public.apex_create_organization(business_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  uid uuid := auth.uid();
  trimmed_name text;
  new_org_id uuid;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  trimmed_name := trim(business_name);
  IF trimmed_name IS NULL OR trimmed_name = '' THEN
    RAISE EXCEPTION 'Business name is required';
  END IF;

  INSERT INTO public.organizations (name)
  VALUES (trimmed_name)
  RETURNING id INTO new_org_id;

  UPDATE public.profiles
  SET
    organization_id = new_org_id,
    role = 'Owner',
    first_time_login = true
  WHERE id = uid;

  RETURN new_org_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.apex_create_organization(text) TO authenticated;
