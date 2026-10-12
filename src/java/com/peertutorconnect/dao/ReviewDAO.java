package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Review moderation.
 *  - a tutor can report a review written about them (with a reason)
 *  - an admin keeps it (review stays) or removes it (review is deleted, tutor's average is recalculated)
 * Every report keeps a snapshot of the review, so the admin history survives even after removal.
 * The review_flag table is created automatically.
 */
public class ReviewDAO {

    public static final int MIN_REASON = 5;
    public static final int MAX_REASON = 500;

    private static boolean tableReady = false;

    private static synchronized void ensureTable() throws SQLException {
        if (tableReady) return;
        try (Connection conn = DBConnection.getConnection()) {
            try (Statement st = conn.createStatement()) {
                st.executeUpdate("CREATE TABLE IF NOT EXISTS review_flag ("
                        + "flagId INT AUTO_INCREMENT PRIMARY KEY, "
                        + "ratingId INT NOT NULL, "
                        + "tutorId INT NOT NULL, tutorUserId INT NOT NULL, tutorName VARCHAR(255), "
                        + "studentUserId INT, studentName VARCHAR(255), "
                        + "stars INT, comment TEXT, reason VARCHAR(500) NOT NULL, "
                        + "status VARCHAR(12) NOT NULL DEFAULT 'PENDING', "
                        + "createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "
                        + "resolvedAt TIMESTAMP NULL, resolvedBy INT NULL, "
                        + "UNIQUE KEY uq_review_flag_rating (ratingId))");
            } catch (SQLException createFailed) {
                // CREATE may be denied for the app user. If the table already exists, carry on.
                try (Statement st = conn.createStatement()) {
                    st.executeQuery("SELECT flagId FROM review_flag LIMIT 1").close();
                } catch (SQLException missing) {
                    throw new SQLException("review_flag table is missing and could not be created: "
                            + createFailed.getMessage(), createFailed);
                }
            }
        }
        tableReady = true;
    }

    // ---------------- data classes ----------------
    public static class TutorReview {
        public int ratingId;
        public String studentName;
        public int stars;
        public String comment;
        public String createdAt;
        /** null = never reported, otherwise PENDING / KEPT */
        public String flagStatus;
    }

    public static class Flag {
        public int flagId;
        public int ratingId;
        public String tutorName;
        public String studentName;
        public int stars;
        public String comment;
        public String reason;
        public String status;
        public String createdAt;
        public int tutorUserId;
        public int studentUserId;
    }

    public static class FlagResult {
        public int tutorUserId;
        public String tutorName;
        public int studentUserId;
        public String studentName;
    }

    // ---------------- tutor side ----------------
    public List<TutorReview> getReviewsForTutor(int tutorId) throws SQLException {
        ensureTable();
        String sql = "SELECT r.ratingId, u.name AS studentName, r.stars, r.comment, r.createdAt, f.status AS flagStatus "
                + "FROM rating r "
                + "JOIN session s ON r.sessionId = s.sessionId "
                + "JOIN booking b ON s.bookingId = b.bookingId "
                + "JOIN student st ON r.studentId = st.studentId "
                + "JOIN user u ON st.userId = u.userId "
                + "LEFT JOIN review_flag f ON f.ratingId = r.ratingId "
                + "WHERE b.tutorId = ? ORDER BY r.createdAt DESC";
        List<TutorReview> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    TutorReview r = new TutorReview();
                    r.ratingId = rs.getInt("ratingId");
                    r.studentName = rs.getString("studentName");
                    r.stars = rs.getInt("stars");
                    r.comment = rs.getString("comment");
                    r.createdAt = rs.getString("createdAt");
                    r.flagStatus = rs.getString("flagStatus");
                    list.add(r);
                }
            }
        }
        return list;
    }

    /**
     * Tutor reports a review about themselves.
     * @throws IllegalStateException "notfound" (not this tutor's review) or "alreadyflagged"
     */
    public FlagResult flag(int ratingId, int tutorId, int tutorUserId, String reason) throws SQLException {
        ensureTable();
        FlagResult result = new FlagResult();
        result.tutorUserId = tutorUserId;

        String sql = "SELECT r.stars, r.comment, su.userId AS studentUserId, su.name AS studentName, tu.name AS tutorName "
                + "FROM rating r "
                + "JOIN session s ON r.sessionId = s.sessionId "
                + "JOIN booking b ON s.bookingId = b.bookingId "
                + "JOIN student st ON r.studentId = st.studentId "
                + "JOIN user su ON st.userId = su.userId "
                + "JOIN tutor t ON b.tutorId = t.tutorId "
                + "JOIN user tu ON t.userId = tu.userId "
                + "WHERE r.ratingId = ? AND b.tutorId = ?";
        try (Connection conn = DBConnection.getConnection()) {
            int stars;
            String comment;
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setInt(1, ratingId);
                ps.setInt(2, tutorId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new IllegalStateException("notfound");
                    stars = rs.getInt("stars");
                    comment = rs.getString("comment");
                    result.studentUserId = rs.getInt("studentUserId");
                    result.studentName = rs.getString("studentName");
                    result.tutorName = rs.getString("tutorName");
                }
            }
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO review_flag (ratingId, tutorId, tutorUserId, tutorName, studentUserId, studentName, "
                    + "stars, comment, reason, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING')")) {
                ps.setInt(1, ratingId);
                ps.setInt(2, tutorId);
                ps.setInt(3, tutorUserId);
                ps.setString(4, result.tutorName);
                ps.setInt(5, result.studentUserId);
                ps.setString(6, result.studentName);
                ps.setInt(7, stars);
                ps.setString(8, comment);
                ps.setString(9, reason);
                ps.executeUpdate();
            } catch (SQLIntegrityConstraintViolationException dup) {
                throw new IllegalStateException("alreadyflagged");
            }
        }
        return result;
    }

    // ---------------- admin side ----------------
    public List<Flag> getAllFlags() throws SQLException {
        ensureTable();
        List<Flag> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                     "SELECT flagId, ratingId, tutorName, studentName, stars, comment, reason, status, createdAt "
                     + "FROM review_flag ORDER BY (status = 'PENDING') DESC, createdAt DESC");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Flag f = new Flag();
                f.flagId = rs.getInt("flagId");
                f.ratingId = rs.getInt("ratingId");
                f.tutorName = rs.getString("tutorName");
                f.studentName = rs.getString("studentName");
                f.stars = rs.getInt("stars");
                f.comment = rs.getString("comment");
                f.reason = rs.getString("reason");
                f.status = rs.getString("status");
                f.createdAt = rs.getString("createdAt");
                list.add(f);
            }
        }
        return list;
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

    /** Admin keeps the review. @throws IllegalStateException "notfound" or "resolved" */
    public Flag keep(int flagId, int adminUserId) throws SQLException {
        return resolve(flagId, adminUserId, false);
    }

    /** Admin removes the review and the tutor's average is recalculated. @throws IllegalStateException "notfound" or "resolved" */
    public Flag remove(int flagId, int adminUserId) throws SQLException {
        return resolve(flagId, adminUserId, true);
    }

    private Flag resolve(int flagId, int adminUserId, boolean remove) throws SQLException {
        ensureTable();
        Flag f = new Flag();
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            int tutorId;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT flagId, ratingId, tutorId, tutorUserId, studentUserId, tutorName, studentName, status "
                    + "FROM review_flag WHERE flagId = ? FOR UPDATE")) {
                ps.setInt(1, flagId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new IllegalStateException("notfound");
                    if (!"PENDING".equals(rs.getString("status"))) throw new IllegalStateException("resolved");
                    f.flagId = flagId;
                    f.ratingId = rs.getInt("ratingId");
                    f.tutorName = rs.getString("tutorName");
                    f.studentName = rs.getString("studentName");
                    tutorId = rs.getInt("tutorId");
                    f.tutorUserId = rs.getInt("tutorUserId");
                    f.studentUserId = rs.getInt("studentUserId");
                }
            }

            if (remove) {
                try (PreparedStatement ps = conn.prepareStatement("DELETE FROM rating WHERE ratingId = ?")) {
                    ps.setInt(1, f.ratingId);
                    ps.executeUpdate();
                }
                try (PreparedStatement ps = conn.prepareStatement(
                        "UPDATE tutor t SET averageRating = ( "
                        + "SELECT AVG(r.stars) FROM rating r "
                        + "JOIN session s ON r.sessionId = s.sessionId "
                        + "JOIN booking b ON s.bookingId = b.bookingId "
                        + "WHERE b.tutorId = t.tutorId ) WHERE t.tutorId = ?")) {
                    ps.setInt(1, tutorId);
                    ps.executeUpdate();
                }
            }

            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE review_flag SET status = ?, resolvedAt = NOW(), resolvedBy = ? WHERE flagId = ?")) {
                ps.setString(1, remove ? "REMOVED" : "KEPT");
                ps.setInt(2, adminUserId);
                ps.setInt(3, flagId);
                ps.executeUpdate();
            }
            conn.commit();
            return f;
        } catch (SQLException | RuntimeException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }
}