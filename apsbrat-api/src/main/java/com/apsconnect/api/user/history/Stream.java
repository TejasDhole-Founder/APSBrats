package com.apsconnect.api.user.history;

/** Subject stream chosen in Class 11-12. Stored as text (see V20). */
public enum Stream {
    SCIENCE_MEDICAL("Science (Medical)"),
    SCIENCE_NON_MEDICAL("Science (Non-Medical)"),
    SCIENCE_PCMB("Science (PCMB)"),
    COMMERCE("Commerce"),
    ARTS("Arts");

    /** Class from which a stream applies. */
    public static final short FIRST_CLASS = 11;

    private final String label;

    Stream(String label) {
        this.label = label;
    }

    public String label() {
        return label;
    }
}
