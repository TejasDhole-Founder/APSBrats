-- V23 renamed phone -> email but kept VARCHAR(15); real emails did not fit.
ALTER TABLE otp_codes ALTER COLUMN email TYPE VARCHAR(100);
