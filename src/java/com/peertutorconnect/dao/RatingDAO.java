package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class RatingDAO {

    public boolean canRate(int bookingId, int studentId) throws SQLException {
        String sql = "SELECT b.status, s.sessionId, r.ratingId " +
                     "FROM booking b " +
                     "JOIN session s ON s.bookingId = b.bookingId " +
                     "LEFT JOIN rating r ON r.sessionId = s.sessionId " +
                     "WHERE b.bookingId = ? AND b.studentId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, bookingId);
            ps.setInt(2, studentId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return false;
                boolean completed = "COMPLETED".equals(rs.getString("status"));
                boolean alreadyRated = rs.getObject("ratingId") != null;
                return completed && !alreadyRated;
            }
        }
    }

    public void submitRating(int bookingId, int studentId, int stars, String comment) throws SQLException {
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            int sessionId;
            int tutorId;
            String sessionSql = "SELECT s.sessionId, b.tutorId FROM session s JOIN booking b ON s.bookingId = b.bookingId WHERE b.bookingId = ? AND b.studentId = ?";
            try (PreparedStatement ps = conn.prepareStatement(sessionSql)) {
                ps.setInt(1, bookingId);
                ps.setInt(2, studentId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new SQLException("Session not found for this booking.");
                    sessionId = rs.getInt("sessionId");
                    tutorId = rs.getInt("tutorId");
                }
            }

            String insertSql = "INSERT INTO rating (sessionId, studentId, stars, comment) VALUES (?, ?, ?, ?)";
            try (PreparedStatement ps = conn.prepareStatement(insertSql)) {
                ps.setInt(1, sessionId);
                ps.setInt(2, studentId);
                ps.setInt(3, stars);
                ps.setString(4, comment);
                ps.executeUpdate();
            }

            String updateAvgSql = "UPDATE tutor t SET averageRating = ( " +
                "SELECT AVG(r.stars) FROM rating r " +
                "JOIN session s ON r.sessionId = s.sessionId " +
                "JOIN booking b ON s.bookingId = b.bookingId " +
                "WHERE b.tutorId = t.tutorId " +
                ") WHERE t.tutorId = ?";
            try (PreparedStatement ps = conn.prepareStatement(updateAvgSql)) {
                ps.setInt(1, tutorId);
                ps.executeUpdate();
            }

            conn.commit();
        } catch (SQLException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }

    public static class Review {
        public String studentName;
        public int stars;
        public String comment;
        public String createdAt;
    }

    public List<Review> getReviewsForTutor(int tutorId) throws SQLException {
        String sql = "SELECT u.name AS studentName, r.stars, r.comment, r.createdAt " +
                     "FROM rating r " +
                     "JOIN session s ON r.sessionId = s.sessionId " +
                     "JOIN booking b ON s.bookingId = b.bookingId " +
                     "JOIN student st ON r.studentId = st.studentId " +
                     "JOIN user u ON st.userId = u.userId " +
                     "WHERE b.tutorId = ? ORDER BY r.createdAt DESC";
        List<Review> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Review r = new Review();
                    r.studentName = rs.getString("studentName");
                    r.stars = rs.getInt("stars");
                    r.comment = rs.getString("comment");
                    r.createdAt = rs.getString("createdAt");
                    list.add(r);
                }
            }
        }
        return list;
    }

    public int getReviewCount(int tutorId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM rating r " +
                     "JOIN session s ON r.sessionId = s.sessionId " +
                     "JOIN booking b ON s.bookingId = b.bookingId " +
                     "WHERE b.tutorId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    public double getAverageRatingForTutor(int tutorId) throws SQLException {
        String sql = "SELECT averageRating FROM tutor WHERE tutorId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    double avg = rs.getDouble("averageRating");
                    return rs.wasNull() ? 0.0 : avg;
                }
                return 0.0;
            }
        }
    }
}