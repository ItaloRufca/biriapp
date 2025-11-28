-- Enable replication for user_items to allow Realtime subscriptions
begin;
  -- Check if publication exists (it usually does in Supabase)
  -- We try to add the table to the publication.
  -- This is idempotent-ish (if already added, it might error or be fine, but 'alter publication' is the standard way).
  
  -- Drop from publication first just in case to ensure clean state (optional, but safer to just add)
  -- alter publication supabase_realtime drop table user_items; 
  
  alter publication supabase_realtime add table user_items;
  
commit;
