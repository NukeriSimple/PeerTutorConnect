package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class TutorDAO {

    public static class TutorSearchResult {

        public int tutorId;
        public String name;
        public double hourlyRate;
        public double averageRating;
        public String bio;
        public String subjects;
        public boolean isVerified;
    }

    public List<TutorSearchResult> searchTutors(String keyword, Integer subjectId,
            Double maxRate, Double minRating,
            String sortBy) throws SQLException {

        SubscriptionDAO.ensureTables();

        StringBuilder sql = new StringBuilder(
                "SELECT DISTINCT t.tutorId, u.name, t.hourlyRate, t.averageRating, t.bio, t.isVerified "
                + "FROM tutor t "
                + "JOIN user u ON t.userId = u.userId "
                + "LEFT JOIN tutor_subject ts ON t.tutorId = ts.tutorId "
                + "LEFT JOIN subject s ON ts.subjectId = s.subjectId "
                + "WHERE t.isVerified = TRUE "
                + "AND NOT EXISTS (SELECT 1 FROM tutor_subscription fz WHERE fz.tutorId = t.tutorId AND fz.frozen = TRUE)"
        );

        List<Object> params = new ArrayList<>();

        if (keyword != null && !keyword.trim().isEmpty()) {
            sql.append(" AND u.name LIKE ?");
            params.add("%" + keyword.trim() + "%");
        }

        if (subjectId != null) {
            sql.append(" AND s.subjectId = ?");
            params.add(subjectId);
        }

        if (maxRate != null) {
            sql.append(" AND t.hourlyRate <= ?");
            params.add(maxRate);
        }

        if (minRating != null) {
            sql.append(" AND t.averageRating >= ?");
            params.add(minRating);
        }

        if ("price".equals(sortBy)) {
            sql.append(" ORDER BY t.hourlyRate ASC");
        } else {
            sql.append(" ORDER BY t.averageRating DESC");
        }

        List<TutorSearchResult> results = new ArrayList<>();

        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql.toString())) {

            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    TutorSearchResult r = new TutorSearchResult();
                    r.tutorId = rs.getInt("tutorId");
                    r.name = rs.getString("name");
                    r.hourlyRate = rs.getDouble("hourlyRate");
                    r.averageRating = rs.getDouble("averageRating");
                    r.bio = rs.getString("bio");
                    r.isVerified = rs.getBoolean("isVerified");
                    r.subjects = getSubjectsForTutor(conn, r.tutorId);
                    results.add(r);
                }
            }
        }

        return results;
    }

    public TutorSearchResult getTutorById(int tutorId) throws SQLException {
        String sql = "SELECT t.tutorId, u.name, t.hourlyRate, t.averageRating, t.bio, t.isVerified "
                + "FROM tutor t JOIN user u ON t.userId = u.userId WHERE t.tutorId = ?";
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    TutorSearchResult r = new TutorSearchResult();
                    r.tutorId = rs.getInt("tutorId");
                    r.name = rs.getString("name");
                    r.hourlyRate = rs.getDouble("hourlyRate");
                    r.averageRating = rs.getDouble("averageRating");
                    r.bio = rs.getString("bio");
                    r.isVerified = rs.getBoolean("isVerified");
                    if (r.isVerified && new SubscriptionDAO().isFrozen(tutorId)) r.isVerified = false; // frozen = not bookable
                    r.subjects = getSubjectsForTutor(conn, r.tutorId);
                    return r;
                }
                return null;
            }
        }
    }

    public int getCompletedSessionCount(int tutorId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM booking WHERE tutorId = ? AND status = 'COMPLETED'";
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    private String getSubjectsForTutor(Connection conn, int tutorId) throws SQLException {
        String sql = "SELECT s.moduleCode FROM tutor_subject ts "
                + "JOIN subject s ON ts.subjectId = s.subjectId WHERE ts.tutorId = ?";
        StringBuilder subjects = new StringBuilder();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    if (subjects.length() > 0) {
                        subjects.append(" · ");
                    }
                    subjects.append(rs.getString("moduleCode"));
                }
            }
        }
        return subjects.toString();
    }

    /**
     * Whether this tutor has finished the post-registration application
     * (rate, bio, subjects, documents). Newly self-registered tutors start
     * as FALSE; tutors added directly by an admin, or existing tutors
     * backfilled during migration, are TRUE.
     */
    public boolean isApplicationComplete(int tutorId) throws SQLException {
        String sql = "SELECT applicationComplete FROM tutor WHERE tutorId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getBoolean("applicationComplete");
            }
        }
    }

    /**
     * Whether an admin has approved this tutor. Used to gate tutor-only
     * features (availability management, appearing in search, etc.) so a
     * tutor who has merely registered or submitted an application, but
     * hasn't been approved yet, can't use them.
     */
    public boolean isVerified(int tutorId) throws SQLException {
        String sql = "SELECT isVerified FROM tutor WHERE tutorId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getBoolean("isVerified");
            }
        }
    }

    /**
     * Fills in the rest of a tutor's profile after their basic account was
     * created at registration, and marks the application as complete.
     * Document upload is handled separately by the caller via DocumentDAO.
     */
    public void completeApplication(int tutorId, double hourlyRate, String bio, int[] subjectIds) throws SQLException {
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            String sql = "UPDATE tutor SET hourlyRate = ?, bio = ?, applicationComplete = TRUE WHERE tutorId = ?";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setDouble(1, hourlyRate);
                ps.setString(2, bio);
                ps.setInt(3, tutorId);
                ps.executeUpdate();
            }

            if (subjectIds != null) {
                String subjectSql = "INSERT INTO tutor_subject (tutorId, subjectId) VALUES (?, ?)";
                try (PreparedStatement ps = conn.prepareStatement(subjectSql)) {
                    for (int subjectId : subjectIds) {
                        ps.setInt(1, tutorId);
                        ps.setInt(2, subjectId);
                        ps.addBatch();
                    }
                    ps.executeBatch();
                }
            }

            conn.commit();
        } catch (SQLException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }

    /** The PaySharp details a tutor wants students to pay to (null if not set yet). */
    public String getPaysharpDetails(int tutorId) throws SQLException {
        String sql = "SELECT paysharpDetails FROM tutor WHERE tutorId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString("paysharpDetails") : null;
            }
        }
    }

    public void setPaysharpDetails(int tutorId, String details) throws SQLException {
        String sql = "UPDATE tutor SET paysharpDetails = ? WHERE tutorId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, details);
            ps.setInt(2, tutorId);
            ps.executeUpdate();
        }
    }
}