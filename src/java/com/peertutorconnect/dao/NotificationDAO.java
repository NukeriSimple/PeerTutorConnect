package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class NotificationDAO {

    public static class Notification {
        public int notificationId;
        public String message;
        public String link;
        public boolean isRead;
        public String createdAt;
    }

    public void create(int userId, String message, String link) throws SQLException {
        String sql = "INSERT INTO notification (userId, message, link) VALUES (?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setString(2, message);
            ps.setString(3, link);
            ps.executeUpdate();
        }
    }

    public List<Notification> getForUser(int userId) throws SQLException {
        String sql = "SELECT notificationId, message, link, isRead, createdAt FROM notification " +
                     "WHERE userId = ? ORDER BY createdAt DESC LIMIT 50";
        List<Notification> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Notification n = new Notification();
                    n.notificationId = rs.getInt("notificationId");
                    n.message = rs.getString("message");
                    n.link = rs.getString("link");
                    n.isRead = rs.getBoolean("isRead");
                    n.createdAt = rs.getString("createdAt");
                    list.add(n);
                }
            }
        }
        return list;
    }

    public int getUnreadCount(int userId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM notification WHERE userId = ? AND isRead = FALSE";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    public void markAsRead(int notificationId, int userId) throws SQLException {
        String sql = "UPDATE notification SET isRead = TRUE WHERE notificationId = ? AND userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, notificationId);
            ps.setInt(2, userId);
            ps.executeUpdate();
        }
    }

    public void markAllAsRead(int userId) throws SQLException {
        String sql = "UPDATE notification SET isRead = TRUE WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.executeUpdate();
        }
    }
}