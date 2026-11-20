package com.apsconnect.api.email;

/** One email: both an HTML and a plain-text body, so any mail client can show it. */
public record EmailMessage(String to, String subject, String html, String text) {
}
