package com.apsconnect.api.notification;

/** What a notification points at, so the app can open or act on the right thing. */
public enum NotificationRef {
    /** ref_id = connections.id — request cards can Accept / Decline directly. */
    CONNECTION,
    /** ref_id = users.id — open that profile. */
    USER,
    /** ref_id = conversations.id. */
    CONVERSATION,
    /** ref_id = posts.id — someone commented on my post. */
    POST,
    /** ref_id = community_events.id — an event I RSVP'd to changed or was cancelled. */
    EVENT
}
