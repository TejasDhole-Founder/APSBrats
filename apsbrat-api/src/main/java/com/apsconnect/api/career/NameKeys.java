package com.apsconnect.api.career;

import java.util.List;
import java.util.Locale;

/** Turns what a user typed into the key we compare on, so spelling variants match. */
public final class NameKeys {
    private static final List<String> LEGAL_SUFFIXES = List.of(
            "pvt", "private", "ltd", "limited", "inc", "incorporated", "llp", "llc", "corp", "corporation", "co");

    private NameKeys() {}

    /** "  Zomato Pvt. Ltd. " -> "zomato" */
    public static String of(String name) {
        if (name == null) {
            return "";
        }
        String clean = name.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", " ").trim();
        List<String> words = new java.util.ArrayList<>(List.of(clean.isEmpty() ? new String[0] : clean.split(" ")));
        while (words.size() > 1 && LEGAL_SUFFIXES.contains(words.get(words.size() - 1))) {
            words.remove(words.size() - 1);
        }
        return String.join(" ", words);
    }
}