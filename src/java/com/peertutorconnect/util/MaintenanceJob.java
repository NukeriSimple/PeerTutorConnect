package com.peertutorconnect.util;

import com.peertutorconnect.dao.NotificationDAO;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Housekeeping tasks:
 *
 *  1. Expiry. A booking that nobody acts on no longer blocks the slot forever.
 *       - PENDING          : expires 48 hours after the request, or when the session start passes.
 *       - AWAITING_PAYMENT : expires 72 hours after the request, or when the session start passes.
 *     The slots are freed and both people are notified.
 *     PAYMENT_SUBMITTED is never expired automatically: the student has paid, so a person must decide.
 *
 *  2. Reminders. CONFIRMED sessions get an in-app notification and an email to both people
 *     about 24 hours before and again about 1 hour before the start.
 *     A reminder_log table (created automatically) guarantees each reminder is sent once.
 *
 *  3. Tutor subscriptions. Reminders 4 days before month end, and freezing unpaid tutors
 *     (see SubscriptionDAO.runMonthlyChecks).
 */
public class MaintenanceJob {

    private static final Logger LOGGER = Logger.getLogger(MaintenanceJob.class.getName());

    public static final int PENDING_EXPIRY_HOURS = 48;
    public static final int AWAITING_PAYMENT_EXPIRY_HOURS = 72;

    private static boolean prepared = false;
    private static boolean hasCreatedAt = false;

    public static synchronized void runOnce() {
        try {
            prepare();
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Maintenance setup failed", e);
            return;
        }
        try {
            expireStaleBookings();
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Booking expiry failed (is 'EXPIRED' allowed in booking.status?)", e);
        }
        try {
            sendReminders();
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Sending reminders failed", e);
        }
        try {
            com.peertutorconnect.dao.SubscriptionDAO.runMonthlyChecks();
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Subscription checks failed", e);
        }
    }

    // ------------------------------------------------------------------
    // One-time setup: reminder_log table and booking.createdAt column
    // ------------------------------------------------------------------
    private static void prepare() throws SQLException {
        if (prepared) return;
        try (Connection conn = DBConnection.getConnection(); Statement st = conn.createStatement()) {
            st.executeUpdate("CREATE TABLE IF NOT EXISTS reminder_log ("
                    + "bookingId INT NOT NULL, kind VARCHAR(8) NOT NULL, "
                    + "sentAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "
                    + "PRIMARY KEY (bookingId, kind))");

            boolean exists;
            try (ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM information_schema.COLUMNS "
                    + "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'booking' AND COLUMN_NAME = 'createdAt'")) {
                exists = rs.next() && rs.getInt(1) > 0;
            }
            if (!exists) {
                try {
                    // Existing rows receive the time of this ALTER, so old stuck requests
                    // start their 48h/72h countdown at deployment, not retroactively.
                    st.executeUpdate("ALTER TABLE booking ADD COLUMN createdAt TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP");
                    exists = true;
                } catch (SQLException e) {
                    LOGGER.log(Level.WARNING, "Could not add booking.createdAt (no ALTER privilege?). "
                            + "Only 'session start has passed' expiry will run.", e);
                }
            }
            hasCreatedAt = exists;
        }
        prepared = true;
    }

    // ------------------------------------------------------------------
    // Expiry
    // ------------------------------------------------------------------
    private static class Stale {
        int bookingId;
        String status;
        int availabilityId;
        String date;
        String start;
        int studentUserId;
        int tutorUserId;
        String studentName;
        String tutorName;
    }

    private static void expireStaleBookings() throws SQLException {
        String ageRule = hasCreatedAt
                ? " OR (b.status = 'PENDING' AND b.createdAt < NOW() - INTERVAL " + PENDING_EXPIRY_HOURS + " HOUR)"
                + " OR (b.status = 'AWAITING_PAYMENT' AND b.createdAt < NOW() - INTERVAL " + AWAITING_PAYMENT_EXPIRY_HOURS + " HOUR)"
                : "";
        String sql = "SELECT b.bookingId, b.status, b.availabilityId, b.bookingDate, b.startTime, "
                + "st.userId AS studentUserId, su.name AS studentName, t.userId AS tutorUserId, tu.name AS tutorName "
                + "FROM booking b "
                + "JOIN student st ON st.studentId = b.studentId JOIN user su ON su.userId = st.userId "
                + "JOIN tutor t ON t.tutorId = b.tutorId JOIN user tu ON tu.userId = t.userId "
                + "WHERE b.status IN ('PENDING', 'AWAITING_PAYMENT') "
                + "AND (TIMESTAMP(b.bookingDate, b.startTime) <= NOW()" + ageRule + ")";

        List<Stale> stale = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Stale s = new Stale();
                s.bookingId = rs.getInt("bookingId");
                s.status = rs.getString("status");
                s.availabilityId = rs.getInt("availabilityId");
                s.date = rs.getString("bookingDate");
                s.start = rs.getString("startTime");
                s.studentUserId = rs.getInt("studentUserId");
                s.tutorUserId = rs.getInt("tutorUserId");
                s.studentName = rs.getString("studentName");
                s.tutorName = rs.getString("tutorName");
                stale.add(s);
            }
        }

        NotificationDAO notify = new NotificationDAO();
        for (Stale s : stale) {
            if (!expireOne(s)) continue;
            String when = s.date + " at " + s.start;
            try {
                String why = "PENDING".equals(s.status)
                        ? "the tutor did not respond in time"
                        : "payment was not completed in time";
                notify.create(s.studentUserId,
                        "Your booking request with " + s.tutorName + " for " + when + " expired because " + why
                        + ". The time slot is free again, so you can book another time.",
                        "/search-tutors.jsp");
                notify.create(s.tutorUserId,
                        "The booking request from " + s.studentName + " for " + when + " expired and the slot is open again.",
                        "/tutor-dashboard.jsp");
            } catch (SQLException e) {
                LOGGER.log(Level.WARNING, "Expired booking " + s.bookingId + " but could not notify", e);
            }
            LOGGER.log(Level.INFO, "Booking {0} expired (was {1})", new Object[]{s.bookingId, s.status});
        }
    }

    /** Marks one booking EXPIRED and frees its slots in one transaction. Returns false if it changed meanwhile. */
    private static boolean expireOne(Stale s) throws SQLException {
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            int updated;
            // The status check makes this safe if the tutor accepted a moment ago.
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE booking SET status = 'EXPIRED' WHERE bookingId = ? AND status = ?")) {
                ps.setInt(1, s.bookingId);
                ps.setString(2, s.status);
                updated = ps.executeUpdate();
            }
            if (updated == 0) {
                conn.rollback();
                return false;
            }

            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE availability a JOIN booking_slot bs ON bs.availabilityId = a.availabilityId "
                    + "SET a.isBooked = FALSE WHERE bs.bookingId = ?")) {
                ps.setInt(1, s.bookingId);
                ps.executeUpdate();
            }
            // Older bookings made before booking_slot existed.
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE availability SET isBooked = FALSE WHERE availabilityId = ?")) {
                ps.setInt(1, s.availabilityId);
                ps.executeUpdate();
            }
            conn.commit();
            return true;
        } catch (SQLException | RuntimeException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }

    // ------------------------------------------------------------------
    // Reminders
    // ------------------------------------------------------------------
    private static void sendReminders() throws SQLException {
        String sql = "SELECT b.bookingId, b.bookingDate, b.startTime, b.endTime, "
                + "TIMESTAMPDIFF(MINUTE, NOW(), TIMESTAMP(b.bookingDate, b.startTime)) AS minsUntil, "
                + "st.userId AS studentUserId, su.name AS studentName, su.email AS studentEmail, "
                + "t.userId AS tutorUserId, tu.name AS tutorName, tu.email AS tutorEmail, s.meetingLink "
                + "FROM booking b "
                + "JOIN student st ON st.studentId = b.studentId JOIN user su ON su.userId = st.userId "
                + "JOIN tutor t ON t.tutorId = b.tutorId JOIN user tu ON tu.userId = t.userId "
                + "LEFT JOIN session s ON s.bookingId = b.bookingId "
                + "WHERE b.status = 'CONFIRMED' "
                + "AND TIMESTAMP(b.bookingDate, b.startTime) > NOW() "
                + "AND TIMESTAMP(b.bookingDate, b.startTime) <= NOW() + INTERVAL 24 HOUR";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            NotificationDAO notify = new NotificationDAO();
            while (rs.next()) {
                int bookingId = rs.getInt("bookingId");
                long mins = rs.getLong("minsUntil");
                String kind = mins <= 60 ? "H1" : "H24";

                if (!claimReminder(conn, bookingId, kind)) continue;

                String when = rs.getString("bookingDate") + " at " + rs.getString("startTime");
                String lead = "H1".equals(kind) ? "starts in about an hour" : "is tomorrow";
                String link = rs.getString("meetingLink");
                String linkLine = (link != null && !link.trim().isEmpty())
                        ? "\n\nMeeting link: " + link
                        : "\n\nNo meeting link has been added yet.";

                String studentName = rs.getString("studentName");
                String tutorName = rs.getString("tutorName");

                try {
                    notify.create(rs.getInt("studentUserId"),
                            "Reminder: your session with " + tutorName + " " + lead + " (" + when + ").",
                            "/my-sessions.jsp");
                    notify.create(rs.getInt("tutorUserId"),
                            "Reminder: your session with " + studentName + " " + lead + " (" + when + ").",
                            "/tutor-dashboard.jsp");
                } catch (SQLException e) {
                    LOGGER.log(Level.WARNING, "Reminder notification failed for booking " + bookingId, e);
                }

                String subject = "Reminder: tutoring session " + ("H1".equals(kind) ? "in 1 hour" : "tomorrow");
                EmailUtil.sendSimpleEmail(rs.getString("studentEmail"), subject,
                        "Hi " + studentName + ",\n\nYour session with " + tutorName + " " + lead
                        + " (" + when + ")." + linkLine + "\n\n- The PeerTutorConnect Team");
                EmailUtil.sendSimpleEmail(rs.getString("tutorEmail"), subject,
                        "Hi " + tutorName + ",\n\nYour session with " + studentName + " " + lead
                        + " (" + when + ")." + linkLine + "\n\n- The PeerTutorConnect Team");
            }
        }
    }

    /** True only the first time a given reminder is claimed (INSERT IGNORE on the primary key). */
    private static boolean claimReminder(Connection conn, int bookingId, String kind) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(
                "INSERT IGNORE INTO reminder_log (bookingId, kind) VALUES (?, ?)")) {
            ps.setInt(1, bookingId);
            ps.setString(2, kind);
            return ps.executeUpdate() == 1;
        }
    }
}