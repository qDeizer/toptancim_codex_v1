CREATE TABLE IF NOT EXISTS notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- 'order_update', 'transaction', 'system', 'connection_request'
    related_id TEXT, -- order_id, transaction_id, etc.
    data JSONB DEFAULT '{}'::jsonb, -- Store extra data for widgets (e.g. { "amount": 100, "currency": "TRY", "action": "approve" })
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster queries on user's notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
-- Index for unread count
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id) WHERE is_read = FALSE;
