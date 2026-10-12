package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.*;
import java.time.Duration;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

public class AvailabilityDAO {

    public static class Slot {
        public int availabilityId;
        public String date;
        public String startTime;
        public String endTime;
        public boolean isBooked;
    }

    /** True only if end is after start and the length is an exact multiple of 60 minutes. */
    public static boolean isWholeHours(String startTime, String endTime) {
        try {
            long minutes = Duration.between(LocalTime.parse(startTime), LocalTime.parse(endTime)).toMinutes();
            return minutes > 0 && minutes % 60 == 0;
        } catch (Exception e) {
            return false;
        }
    }

    /** True only if the slot is exactly 60 minutes long (start can be any minute, e.g. 11:50 - 12:50). */
    public static boolean isOneHour(String startTime, String endTime) {
        try {
            long minutes = Duration.between(LocalTime.parse(startTime), LocalTime.parse(endTime)).toMinutes();
            return minutes == 60;
        } catch (Exception e) {
            return false;
        }
    }

    public void addSlot(int tutorId, String date, String startTime, String endTime) throws SQLException {
        String sql = "INSERT INTO availability (tutorId, date, startTime, endTime, isBooked) VALUES (?, ?, ?, ?, FALSE)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            ps.setString(2, date);
            ps.setString(3, startTime);
            ps.setString(4, endTime);
            ps.executeUpdate();
        }
    }

    public void deleteSlot(int availabilityId, int tutorId) throws SQLException {
        String sql = "DELETE FROM availability WHERE availabilityId = ? AND tutorId = ? AND isBooked = FALSE";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, availabilityId);
            ps.setInt(2, tutorId);
            ps.executeUpdate();
        }
    }

    public List<Slot> getSlotsForTutor(int tutorId) throws SQLException {
        String sql = "SELECT availabilityId, date, startTime, endTime, isBooked FROM availability " +
                     "WHERE tutorId = ? AND date >= CURDATE() ORDER BY date, startTime";
        List<Slot> slots = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Slot s = new Slot();
                    s.availabilityId = rs.getInt("availabilityId");
                    s.date = rs.getString("date");
                    s.startTime = rs.getString("startTime");
                    s.endTime = rs.getString("endTime");
                    s.isBooked = rs.getBoolean("isBooked");
                    slots.add(s);
                }
            }
        }
        return slots;
    }

    public List<Slot> getOpenSlotsForTutor(int tutorId) throws SQLException {
        String sql = "SELECT availabilityId, date, startTime, endTime, isBooked FROM availability " +
                     "WHERE tutorId = ? AND isBooked = FALSE AND date >= CURDATE() ORDER BY date, startTime";
        List<Slot> slots = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Slot s = new Slot();
                    s.availabilityId = rs.getInt("availabilityId");
                    s.date = rs.getString("date");
                    s.startTime = rs.getString("startTime");
                    s.endTime = rs.getString("endTime");
                    s.isBooked = rs.getBoolean("isBooked");
                    slots.add(s);
                }
            }
        }
        return slots;
    }

    public Integer getTutorIdForUser(int userId) throws SQLException {
        String sql = "SELECT tutorId FROM tutor WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt("tutorId") : null;
            }
        }
    }
}