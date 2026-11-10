-- QA audit section 4: indexes for queries that were scanning.

-- Pinned posts shown on top of a community (findByCommunityIdAndStatusAndPinnedAtIsNotNull...).
CREATE INDEX IF NOT EXISTS idx_posts_pinned
    ON posts (community_id, pinned_at DESC) WHERE pinned_at IS NOT NULL;

-- Unread badge: count of a user's unread notifications.
CREATE INDEX IF NOT EXISTS idx_notif_unread
    ON notifications (user_id) WHERE is_read = FALSE;

-- Messages tab: a user's active conversations, newest first (either side of the pair).
CREATE INDEX IF NOT EXISTS idx_conv_user_a_last
    ON conversations (user_a_id, last_message_at DESC) WHERE last_message_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_conv_user_b_last
    ON conversations (user_b_id, last_message_at DESC) WHERE last_message_at IS NOT NULL;

-- "My RSVPs" and "my join requests": the primary keys lead with event/community, not user.
CREATE INDEX IF NOT EXISTS idx_rsvps_user ON event_rsvps (user_id);
CREATE INDEX IF NOT EXISTS idx_join_requests_user ON community_join_requests (user_id);

-- Batchmates list: accepted connections, newest first.
CREATE INDEX IF NOT EXISTS idx_conn_requester_accepted
    ON connections (requester_id, accepted_at DESC) WHERE status = 'ACCEPTED';
CREATE INDEX IF NOT EXISTS idx_conn_addressee_accepted
    ON connections (addressee_id, accepted_at DESC) WHERE status = 'ACCEPTED';
