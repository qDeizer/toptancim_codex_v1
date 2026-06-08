-- Add approval columns to relations table
ALTER TABLE relations 
ADD COLUMN IF NOT EXISTS wholesaler_approval BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS customer_approval BOOLEAN DEFAULT TRUE;
