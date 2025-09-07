-- Function to begin a transaction
CREATE OR REPLACE FUNCTION begin_transaction()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Begin the transaction
  BEGIN;
END;
$$;

-- Function to commit a transaction
CREATE OR REPLACE FUNCTION commit_transaction()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Commit the transaction
  COMMIT;
END;
$$;

-- Function to rollback a transaction
CREATE OR REPLACE FUNCTION rollback_transaction()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Rollback the transaction
  ROLLBACK;
END;
$$;

-- Function to update subscription status
CREATE OR REPLACE FUNCTION update_subscription_status()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update profile subscription status based on active subscriptions
  UPDATE profiles
  SET subscription_status = 
    CASE 
      WHEN EXISTS (
        SELECT 1 
        FROM subscriptions 
        WHERE user_id = NEW.user_id 
        AND status = 'active'
        AND start_date <= CURRENT_TIMESTAMP
        AND end_date >= CURRENT_TIMESTAMP
      ) THEN 'active'
      ELSE 'inactive'
    END
  WHERE id = NEW.user_id;
  
  RETURN NEW;
END;
$$;

-- Create trigger for subscription updates
CREATE TRIGGER subscription_status_trigger
AFTER INSERT OR UPDATE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_subscription_status();
