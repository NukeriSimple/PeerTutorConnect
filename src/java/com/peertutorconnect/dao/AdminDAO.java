package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class AdminDAO {

    public static class PendingTutor {
        public int tutorId;
        public String name;
        public String email;
        public double hourlyRate;
        public String bio;
        public String subjects;
        public List<DocumentDAO.Document> documents;
    }

    public static class TutorSummary {
        public int tutorId;
        public int userId;
        public String name;
        public String email;
        public double hourlyRate;
        public double averageRating;
        public String subjects;
    }

    public static class BookingSummary {
        public int bookingId;
        public int studentUserId;
        public String studentName;
        public int tutorUserId;
        public String tutorName;
        public String bookingDate;
        public String startTime;
        public String endTime;
        public String status;
    }

    public List<PendingTutor> getPendingTutors() throws SQLException {
        String sql = "SELECT t.tutorId, u.name, u.email, t.hourlyRate, t.bio " +
                     "FROM tutor t JOIN user u ON t.userId = u.userId " +
                     "WHERE t.isVerified = FALSE AND t.applicationComplete = TRUE ORDER BY u.name";
        List<PendingTutor> list = new ArrayList<>();
        DocumentDAO documentDAO = new DocumentDAO();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                PendingTutor p = new PendingTutor();
                p.tutorId = rs.getInt("tutorId");
                p.name = rs.getString("name");
                p.email = rs.getString("email");
                p.hourlyRate = rs.getDouble("hourlyRate");
                p.bio = rs.getString("bio");
                p.subjects = getSubjectsForTutor(conn, p.tutorId);
                p.documents = documentDAO.getDocumentsForTutor(p.tutorId);
                list.add(p);
            }
        }
        return list;
    }

    public PendingTutor getPendingTutorById(int tutorId) throws SQLException {
        String sql = "SELECT t.tutorId, u.name, u.email, t.hourlyRate, t.bio " +
                     "FROM tutor t JOIN user u ON t.userId = u.userId " +
                     "WHERE t.tutorId = ? AND t.isVerified = FALSE AND t.applicationComplete = TRUE";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                PendingTutor p = new PendingTutor();
                p.tutorId = rs.getInt("tutorId");
                p.name = rs.getString("name");
                p.email = rs.getString("email");
                p.hourlyRate = rs.getDouble("hourlyRate");
                p.bio = rs.getString("bio");
                p.subjects = getSubjectsForTutor(conn, p.tutorId);
                p.documents = new DocumentDAO().getDocumentsForTutor(p.tutorId);
                return p;
            }
        }
    }

    /**
     * All tutors an admin has approved. Backs the "Active Tutors" stat
     * card on the admin dashboard.
     */
    public List<TutorSummary> getActiveTutors() throws SQLException {
        String sql = "SELECT t.tutorId, t.userId, u.name, u.email, t.hourlyRate, t.averageRating " +
                     "FROM tutor t JOIN user u ON t.userId = u.userId " +
                     "WHERE t.isVerified = TRUE ORDER BY u.name";
        List<TutorSummary> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                TutorSummary t = new TutorSummary();
                t.tutorId = rs.getInt("tutorId");
                t.userId = rs.getInt("userId");
                t.name = rs.getString("name");
                t.email = rs.getString("email");
                t.hourlyRate = rs.getDouble("hourlyRate");
                t.averageRating = rs.getDouble("averageRating");
                t.subjects = getSubjectsForTutor(conn, t.tutorId);
                list.add(t);
            }
        }
        return list;
    }

    /**
     * All bookings in the system, optionally filtered to one status.
     * Backs the "Total Bookings" and "Completed" stat cards.
     *
     * @param statusFilter e.g. "COMPLETED", or null/empty for all bookings
     */
    public List<BookingSummary> getAllBookings(String statusFilter) throws SQLException {
        StringBuilder sql = new StringBuilder(
                "SELECT b.bookingId, b.bookingDate, b.startTime, b.endTime, b.status, " +
                "su.userId AS studentUserId, su.name AS studentName, " +
                "tu.userId AS tutorUserId, tu.name AS tutorName " +
                "FROM booking b " +
                "JOIN student st ON b.studentId = st.studentId " +
                "JOIN user su ON st.userId = su.userId " +
                "JOIN tutor t ON b.tutorId = t.tutorId " +
                "JOIN user tu ON t.userId = tu.userId "
        );

        boolean hasFilter = statusFilter != null && !statusFilter.trim().isEmpty();
        if (hasFilter) {
            sql.append("WHERE b.status = ? ");
        }
        sql.append("ORDER BY b.bookingDate DESC, b.startTime DESC");

        List<BookingSummary> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            if (hasFilter) {
                ps.setString(1, statusFilter.trim());
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    BookingSummary b = new BookingSummary();
                    b.bookingId = rs.getInt("bookingId");
                    b.bookingDate = rs.getString("bookingDate");
                    b.startTime = rs.getString("startTime");
                    b.endTime = rs.getString("endTime");
                    b.status = rs.getString("status");
                    b.studentUserId = rs.getInt("studentUserId");
                    b.studentName = rs.getString("studentName");
                    b.tutorUserId = rs.getInt("tutorUserId");
                    b.tutorName = rs.getString("tutorName");
                    list.add(b);
                }
            }
        }
        return list;
    }

    private String getSubjectsForTutor(Connection conn, int tutorId) throws SQLException {
        String sql = "SELECT s.moduleCode FROM tutor_subject ts JOIN subject s ON ts.subjectId = s.subjectId WHERE ts.tutorId = ?";
        StringBuilder sb = new StringBuilder();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    if (sb.length() > 0) sb.append(" \u00b7 ");
                    sb.append(rs.getString("moduleCode"));
                }
            }
        }
        return sb.toString();
    }

    public void approveTutor(int tutorId) throws SQLException {
        String sql = "UPDATE tutor SET isVerified = TRUE, verifiedAt = NOW() WHERE tutorId = ? AND applicationComplete = TRUE";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            ps.executeUpdate();
        }
    }

    public void rejectTutor(int tutorId) throws SQLException {
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);
            try (PreparedStatement ps = conn.prepareStatement("DELETE FROM supporting_document WHERE tutorId = ?")) {
                ps.setInt(1, tutorId);
                ps.executeUpdate();
            }
            try (PreparedStatement ps = conn.prepareStatement("DELETE FROM tutor_subject WHERE tutorId = ?")) {
                ps.setInt(1, tutorId);
                ps.executeUpdate();
            }
            try (PreparedStatement ps = conn.prepareStatement("DELETE FROM tutor WHERE tutorId = ? AND isVerified = FALSE")) {
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

    public Integer getUserIdForTutor(int tutorId) throws SQLException {
        String sql = "SELECT userId FROM tutor WHERE tutorId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt("userId") : null;
            }
        }
    }

    public static class SystemStats {
        public int totalUsers;
        public int activeTutors;
        public int pendingApplications;
        public int totalSessions;
        public int completedSessions;
    }

    public SystemStats getStats() throws SQLException {
        SystemStats stats = new SystemStats();
        try (Connection conn = DBConnection.getConnection();
             Statement st = conn.createStatement()) {

            try (ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM user")) {
                if (rs.next()) stats.totalUsers = rs.getInt(1);
            }
            try (ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM tutor WHERE isVerified = TRUE")) {
                if (rs.next()) stats.activeTutors = rs.getInt(1);
            }
            try (ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM tutor WHERE isVerified = FALSE AND applicationComplete = TRUE")) {
                if (rs.next()) stats.pendingApplications = rs.getInt(1);
            }
            try (ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM booking")) {
                if (rs.next()) stats.totalSessions = rs.getInt(1);
            }
            try (ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM booking WHERE status = 'COMPLETED'")) {
                if (rs.next()) stats.completedSessions = rs.getInt(1);
            }
        }
        return stats;
    }
}