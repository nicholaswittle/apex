-- Apex's north-star metric: number of paying venues. This is a state
-- query, not an event stream (a venue is either currently active or it
-- isn't), so it's exposed as a view rather than an event log — always
-- correct, no risk of drifting from actual subscription state.

create or replace view v_paying_venues as
select o.id as organization_id, o.name
from organizations o
where exists (
  select 1
  from profiles p
  where p.organization_id = o.id
    and p.subscription_status = 'active'
);

-- North-star query:
--   select count(*) from v_paying_venues;
