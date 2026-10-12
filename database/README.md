# Database

Export your MySQL database and place it here:

    mysqldump -u root -p --no-data peertutorconnect > database/schema.sql
    mysqldump -u root -p peertutorconnect > database/sample_data.sql   # optional, no real user data!

Tables used by the code: user, student, tutor, tutor_subject, subject, availability,
booking, booking_slot, session, rating, review_flag, no_show_report, notification,
supporting_document, tutor_subscription, subscription_payment, audit_log, reminder_log.
