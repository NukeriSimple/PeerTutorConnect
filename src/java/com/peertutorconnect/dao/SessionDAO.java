package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.*;

public class SessionDAO {

    public boolean setMeetingLink(int bookingId, int tutorId, String meetingLink) throws SQLException {
        String sql = "UPDATE session s JOIN booking b ON s.bookingId = b.bookingId " +
                     "SET s.meetingLink = ? WHERE b.bookingId = ? AND b.tutorId = ? AND b.status = 'CONFIRMED'";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, meetingLink);
            ps.setInt(2, bookingId);
            ps.setInt(3, tutorId);
            return ps.executeUpdate() > 0;
        }
    }

    public boolean removeMeetingLink(int bookingId, int tutorId) throws SQLException {
        return setMeetingLink(bookingId, tutorId, null);
    }
}