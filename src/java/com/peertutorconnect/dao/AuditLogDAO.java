package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class AuditLogDAO {

    public void log(Integer userId, String userName, String action, String details) {
        String sql = "INSERT INTO audit_log (userId, userName, action, details) VALUES (?, ?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (userId != null) {
                ps.setInt(1, userId);
            } else {
                ps.setNull(1, Types.INTEGER);
            }
            ps.setString(2, userName);
            ps.setString(3, action);
            ps.setString(4, details);
            ps.executeUpdate();
        } catch (SQLException e) {
            // Logging must never break the actual user-facing action.
            // If the audit write fails, we swallow it here rather than
            // propagating an exception up into a servlet that has already
            // done its real work.
            System.err.println("Audit log write failed: " + e.getMessage());
        }
    }

    public static class LogEntry {
        public int logId;
        public String userName;
        public String action;
        public String details;
        public String createdAt;
    }

    public List<LogEntry> getRecentLogs(int limit) throws SQLException {
        String sql = "SELECT logId, userName, action, details, createdAt FROM audit_log " +
                     "ORDER BY createdAt DESC LIMIT ?";
        List<LogEntry> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    LogEntry e = new LogEntry();
                    e.logId = rs.getInt("logId");
                    e.userName = rs.getString("userName");
                    e.action = rs.getString("action");
                    e.details = rs.getString("details");
                    e.createdAt = rs.getString("createdAt");
                    list.add(e);
                }
            }
        }
        return list;
    }
}