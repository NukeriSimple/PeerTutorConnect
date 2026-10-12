package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class HomeStatsDAO {

    public int getVerifiedTutorCount() throws SQLException {
        String sql = "SELECT COUNT(*) FROM tutor WHERE isVerified = TRUE";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }

    public int getSubjectCount() throws SQLException {
        String sql = "SELECT COUNT(*) FROM subject";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }

    public int getCompletedSessionCount() throws SQLException {
        String sql = "SELECT COUNT(*) FROM booking WHERE status = 'COMPLETED'";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }

    public int getStudentsHelpedCount() throws SQLException {
        String sql = "SELECT COUNT(DISTINCT studentId) FROM booking WHERE status = 'COMPLETED'";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }
}