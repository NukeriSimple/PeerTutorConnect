package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * No-show handling. Every report now waits for an admin to decide:
 *  - tutor reports a student who did not attend  -> PENDING, no strike yet
 *  - student reports a tutor who did not attend  -> PENDING (stars + written review required)
 *  - admin confirms  -> the absent person gets a strike (3 strikes = account removed)
 *  - admin dismisses -> no strike, session counts as completed
 *  - admin can later revoke a strike that was issued by mistake
 */
public class NoShowDAO {

    public static final int MAX_STRIKES = 3;
    /** Minutes after the session start before anyone may report a no-show. */
    public static final int GRACE_MINUTES = 15;

    public static class Report {
        public int reportId;
        public int bookingId;
        public String absentRole;
        public int absentUserId;
        public String absentName;
        public int absentStrikes;
        public String reporterName;
        public String bookingDate;
        public String startTime;
        public String endTime;
        public String note;
        public String status;
        public String createdAt;
        /** Price of the session (hourly rate x duration). Used for the refund shown on tutor reports. */
        public double sessionPrice;
    }

    /** Outcome of an admin confirming a report (issuing a strike). */
    public static class StrikeResult {
        public int userId;
        public String role;
        public String name;
        public String email;
        public int strikes;
        public boolean removed;
        public boolean removalFailed;
    }

    /** Outcome of a tutor reporting a student (no strike yet). */
    public static class FlagResult {
        public int studentUserId;
        public String studentName;
        public int strikes;
    }

    /** Outcome of a student reporting a tutor (no strike yet). */
    public static class TutorReportResult {
        public int tutorUserId;
        public String tutorName;
        public double refundAmount;
    }

    /** Outcome of an admin revoking a strike. */
    public static class RevokeResult {
        public int userId;
        public String name;
        public int strikes;
    }

    /** Outcome of an admin dismissing a report. */
    public static class DismissResult {
        public int absentUserId;
        public int reporterUserId;
    }

    // ------------------------------------------------------------------
    // Tutor reports a student who did not show up: waits for an admin
    // ------------------------------------------------------------------
    /** @throws IllegalStateException "notfound", "notflaggable", "toosoon" */
    public FlagResult flagStudentNoShow(int bookingId, int tutorId, int tutorUserId, String note) throws SQLException {
        FlagResult result = new FlagResult();

        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            String sql = "SELECT b.status, st.userId AS studentUserId, u.name AS studentName, u.strikes AS strikes, "
                    + "TIMESTAMPDIFF(MINUTE, TIMESTAMP(b.bookingDate, b.startTime), NOW()) AS minutesSinceStart "
                    + "FROM booking b JOIN student st ON b.studentId = st.studentId "
                    + "JOIN user u ON u.userId = st.userId "
                    + "WHERE b.bookingId = ? AND b.tutorId = ? FOR UPDATE";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setInt(1, bookingId);
                ps.setInt(2, tutorId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new IllegalStateException("notfound");
                    if (!"CONFIRMED".equals(rs.getString("status"))) throw new IllegalStateException("notflaggable");
                    if (rs.getLong("minutesSinceStart") < GRACE_MINUTES) throw new IllegalStateException("toosoon");
                    result.studentUserId = rs.getInt("studentUserId");
                    result.studentName = rs.getString("studentName");
                    result.strikes = rs.getInt("strikes");
                }
            }

            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE booking SET status = 'NO_SHOW_STUDENT' WHERE bookingId = ?")) {
                ps.setInt(1, bookingId);
                ps.executeUpdate();
            }

            // No strike yet: an admin has to confirm the report first.
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO no_show_report (bookingId, absentRole, absentUserId, reporterUserId, note, status) "
                    + "VALUES (?, 'STUDENT', ?, ?, ?, 'PENDING')")) {
                ps.setInt(1, bookingId);
                ps.setInt(2, result.studentUserId);
                ps.setInt(3, tutorUserId);
                ps.setString(4, note);
                ps.executeUpdate();
            }

            conn.commit();
        } catch (SQLException | RuntimeException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
        return result;
    }

    // ------------------------------------------------------------------
    // Student reports a tutor no-show: rating + review are mandatory, admin decides
    // ------------------------------------------------------------------
    /** @throws IllegalStateException "notfound", "notflaggable", "toosoon", "alreadyrated" */
    public TutorReportResult reportTutorNoShow(int bookingId, int studentId, int studentUserId, int stars, String review) throws SQLException {
        TutorReportResult result = new TutorReportResult();
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            String sql = "SELECT b.status, b.tutorId, t.userId AS tutorUserId, tu.name AS tutorName, t.hourlyRate, s.sessionId, "
                    + "TIME_TO_SEC(TIMEDIFF(b.endTime, b.startTime)) / 60 AS durationMinutes, "
                    + "TIMESTAMPDIFF(MINUTE, TIMESTAMP(b.bookingDate, b.startTime), NOW()) AS minutesSinceStart "
                    + "FROM booking b JOIN tutor t ON t.tutorId = b.tutorId "
                    + "JOIN user tu ON tu.userId = t.userId "
                    + "LEFT JOIN session s ON s.bookingId = b.bookingId "
                    + "WHERE b.bookingId = ? AND b.studentId = ? FOR UPDATE";
            int tutorId, sessionId;
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setInt(1, bookingId);
                ps.setInt(2, studentId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new IllegalStateException("notfound");
                    if (!"CONFIRMED".equals(rs.getString("status"))) throw new IllegalStateException("notflaggable");
                    if (rs.getLong("minutesSinceStart") < GRACE_MINUTES) throw new IllegalStateException("toosoon");
                    if (rs.getObject("sessionId") == null) throw new IllegalStateException("notfound");
                    tutorId = rs.getInt("tutorId");
                    result.tutorUserId = rs.getInt("tutorUserId");
                    result.tutorName = rs.getString("tutorName");
                    result.refundAmount = rs.getDouble("hourlyRate") * rs.getDouble("durationMinutes") / 60.0;
                    sessionId = rs.getInt("sessionId");
                }
            }

            try (PreparedStatement ps = conn.prepareStatement("SELECT 1 FROM rating WHERE sessionId = ?")) {
                ps.setInt(1, sessionId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) throw new IllegalStateException("alreadyrated");
                }
            }

            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO rating (sessionId, studentId, stars, comment) VALUES (?, ?, ?, ?)")) {
                ps.setInt(1, sessionId);
                ps.setInt(2, studentId);
                ps.setInt(3, stars);
                ps.setString(4, review);
                ps.executeUpdate();
            }

            String avgSql = "UPDATE tutor t SET averageRating = ( "
                    + "SELECT AVG(r.stars) FROM rating r "
                    + "JOIN session s ON r.sessionId = s.sessionId "
                    + "JOIN booking b ON s.bookingId = b.bookingId "
                    + "WHERE b.tutorId = t.tutorId ) WHERE t.tutorId = ?";
            try (PreparedStatement ps = conn.prepareStatement(avgSql)) {
                ps.setInt(1, tutorId);
                ps.executeUpdate();
            }

            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE booking SET status = 'NO_SHOW_TUTOR' WHERE bookingId = ?")) {
                ps.setInt(1, bookingId);
                ps.executeUpdate();
            }

            // Waits for an admin: confirming it gives the tutor a strike and the student a refund.
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO no_show_report (bookingId, absentRole, absentUserId, reporterUserId, note, status) "
                    + "VALUES (?, 'TUTOR', ?, ?, ?, 'PENDING')")) {
                ps.setInt(1, bookingId);
                ps.setInt(2, result.tutorUserId);
                ps.setInt(3, studentUserId);
                ps.setString(4, review);
                ps.executeUpdate();
            }

            conn.commit();
            return result;
        } catch (SQLException | RuntimeException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }

    // ------------------------------------------------------------------
    // Admin: list, issue strike, dismiss, revoke
    // ------------------------------------------------------------------
    public List<Report> getAllReports() throws SQLException {
        String sql = "SELECT r.reportId, r.bookingId, r.absentRole, r.absentUserId, au.name AS absentName, "
                + "au.strikes AS absentStrikes, ru.name AS reporterName, b.bookingDate, b.startTime, b.endTime, "
                + "r.note, r.status, r.createdAt, "
                + "COALESCE(t.hourlyRate, 0) * TIME_TO_SEC(TIMEDIFF(b.endTime, b.startTime)) / 3600 AS sessionPrice "
                + "FROM no_show_report r "
                + "JOIN booking b ON b.bookingId = r.bookingId "
                + "LEFT JOIN tutor t ON t.tutorId = b.tutorId "
                + "LEFT JOIN user au ON au.userId = r.absentUserId "
                + "LEFT JOIN user ru ON ru.userId = r.reporterUserId "
                + "ORDER BY (r.status = 'PENDING') DESC, r.createdAt DESC";
        List<Report> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Report r = new Report();
                r.reportId = rs.getInt("reportId");
                r.bookingId = rs.getInt("bookingId");
                r.absentRole = rs.getString("absentRole");
                r.absentUserId = rs.getInt("absentUserId");
                r.absentName = rs.getString("absentName");
                r.absentStrikes = rs.getInt("absentStrikes");
                r.reporterName = rs.getString("reporterName");
                r.bookingDate = rs.getString("bookingDate");
                r.startTime = rs.getString("startTime");
                r.endTime = rs.getString("endTime");
                r.note = rs.getString("note");
                r.status = rs.getString("status");
                r.createdAt = rs.getString("createdAt");
                r.sessionPrice = rs.getDouble("sessionPrice");
                list.add(r);
            }
        }
        return list;
    }

    public int countPending() throws SQLException {
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                     "SELECT COUNT(*) FROM no_show_report WHERE status = 'PENDING'");
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }

    public int getStrikes(int userId) throws SQLException {
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT strikes FROM user WHERE userId = ?")) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    public List<Integer> getAdminUserIds() throws SQLException {
        List<Integer> ids = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT userId FROM user WHERE role = 'ADMIN'");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) ids.add(rs.getInt(1));
        }
        return ids;
    }

    /**
     * Admin confirms a pending report (student OR tutor): the absent person gets a strike.
     * At MAX_STRIKES the account is deleted (same removal the admin "Delete user" button uses).
     * @throws IllegalStateException "notfound" or "resolved"
     */
    public StrikeResult issueStrike(int reportId, int adminUserId) throws SQLException {
        StrikeResult result = new StrikeResult();

        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT absentUserId, absentRole, status FROM no_show_report WHERE reportId = ? FOR UPDATE")) {
                ps.setInt(1, reportId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new IllegalStateException("notfound");
                    if (!"PENDING".equals(rs.getString("status"))) throw new IllegalStateException("resolved");
                    result.userId = rs.getInt("absentUserId");
                    result.role = rs.getString("absentRole");
                }
            }

            try (PreparedStatement ps = conn.prepareStatement("UPDATE user SET strikes = strikes + 1 WHERE userId = ?")) {
                ps.setInt(1, result.userId);
                ps.executeUpdate();
            }
            try (PreparedStatement ps = conn.prepareStatement("SELECT name, email, strikes FROM user WHERE userId = ?")) {
                ps.setInt(1, result.userId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        result.name = rs.getString("name");
                        result.email = rs.getString("email");
                        result.strikes = rs.getInt("strikes");
                    }
                }
            }
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE no_show_report SET status = 'STRIKE_ISSUED', resolvedAt = NOW(), resolvedBy = ? WHERE reportId = ?")) {
                ps.setInt(1, adminUserId);
                ps.setInt(2, reportId);
                ps.executeUpdate();
            }
            conn.commit();
        } catch (SQLException | RuntimeException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }

        // Strike is saved. Now remove the account if the limit is reached.
        if (result.strikes >= MAX_STRIKES) {
            try {
                new UserDAO().deleteUser(result.userId);
                result.removed = true;
            } catch (SQLException e) {
                result.removalFailed = true;
            }
        }
        return result;
    }

    /** Admin rejects a pending report: no strike, and the session is treated as having taken place. */
    public DismissResult dismiss(int reportId, int adminUserId) throws SQLException {
        DismissResult result = new DismissResult();
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            int bookingId;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT bookingId, absentUserId, reporterUserId, status FROM no_show_report WHERE reportId = ? FOR UPDATE")) {
                ps.setInt(1, reportId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new IllegalStateException("notfound");
                    if (!"PENDING".equals(rs.getString("status"))) throw new IllegalStateException("resolved");
                    bookingId = rs.getInt("bookingId");
                    result.absentUserId = rs.getInt("absentUserId");
                    result.reporterUserId = rs.getInt("reporterUserId");
                }
            }
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE no_show_report SET status = 'DISMISSED', resolvedAt = NOW(), resolvedBy = ? WHERE reportId = ?")) {
                ps.setInt(1, adminUserId);
                ps.setInt(2, reportId);
                ps.executeUpdate();
            }
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE booking SET status = 'COMPLETED' WHERE bookingId = ? AND status IN ('NO_SHOW_STUDENT', 'NO_SHOW_TUTOR')")) {
                ps.setInt(1, bookingId);
                ps.executeUpdate();
            }
            conn.commit();
            return result;
        } catch (SQLException | RuntimeException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }

    /**
     * Admin undoes a strike that was issued by mistake: the user loses one strike and the
     * report is closed as dismissed. Not possible once the account has been removed.
     * @throws IllegalStateException "notfound", "notissued" or "accountgone"
     */
    public RevokeResult revokeStrike(int reportId, int adminUserId) throws SQLException {
        RevokeResult result = new RevokeResult();
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            int bookingId;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT bookingId, absentUserId, status FROM no_show_report WHERE reportId = ? FOR UPDATE")) {
                ps.setInt(1, reportId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new IllegalStateException("notfound");
                    if (!"STRIKE_ISSUED".equals(rs.getString("status"))) throw new IllegalStateException("notissued");
                    bookingId = rs.getInt("bookingId");
                    result.userId = rs.getInt("absentUserId");
                }
            }

            int updated;
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE user SET strikes = GREATEST(strikes - 1, 0) WHERE userId = ?")) {
                ps.setInt(1, result.userId);
                updated = ps.executeUpdate();
            }
            if (updated == 0) throw new IllegalStateException("accountgone");

            try (PreparedStatement ps = conn.prepareStatement("SELECT name, strikes FROM user WHERE userId = ?")) {
                ps.setInt(1, result.userId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        result.name = rs.getString("name");
                        result.strikes = rs.getInt("strikes");
                    }
                }
            }
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE no_show_report SET status = 'DISMISSED', resolvedAt = NOW(), resolvedBy = ? WHERE reportId = ?")) {
                ps.setInt(1, adminUserId);
                ps.setInt(2, reportId);
                ps.executeUpdate();
            }
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE booking SET status = 'COMPLETED' WHERE bookingId = ? AND status IN ('NO_SHOW_STUDENT', 'NO_SHOW_TUTOR')")) {
                ps.setInt(1, bookingId);
                ps.executeUpdate();
            }
            conn.commit();
            return result;
        } catch (SQLException | RuntimeException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }
}