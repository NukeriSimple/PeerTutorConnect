package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.*;
import java.time.Duration;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

public class BookingDAO {

    public static class BookingRow {

        public int bookingId;
        public String otherPartyName;
        public String bookingDate;
        public String startTime;
        public String endTime;
        public String status;
        public int tutorId;
        public int studentId;
        public int availabilityId;
        public boolean hasRating;
        public String meetingLink;
        // cancellation policy fields
        public double hourlyRate;
        public String cancelReason;
        public double cancellationFee;
        // booking flow fields
        public String description;
        public String paymentProofUrl;
        public String paymentSubmittedAt;
        // PaySharp
        public String tutorPaysharp;     // where the student pays the tutor
        public String refundPaysharp;    // where the student's refund is sent
        public double refundAmount;      // amount refunded after a paid cancellation
    }

    /** A student must cancel at least this many hours before the session starts. */
    public static final int CANCEL_DEADLINE_HOURS = 8;
    /** Share of the session price charged when a student cancels a CONFIRMED session. 0 = free. */
    public static final double CANCEL_FEE_PERCENT = 0.50;

    public Integer getStudentIdForUser(int userId) throws SQLException {
        String sql = "SELECT studentId FROM student WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt("studentId") : null;
            }
        }
    }

    /** A student can book at most this many consecutive 1-hour slots in one request. */
    public static final int MAX_SLOTS_PER_BOOKING = 4;

    /**
     * Creates a booking covering one or more consecutive slots and returns its
     * generated bookingId.
     *
     * Rules enforced here: every slot must exist, belong to this tutor, be free,
     * be a whole-hour slot, be on the same date, and the slots must run back to back
     * (one ends exactly when the next starts) so they form a single session.
     *
     * @throws IllegalStateException with code "noslots", "toomany", "notfound", "wrongtutor",
     *         "wholehour", "notconsecutive"; a SQLException is thrown if a slot was taken.
     */
    public int createBooking(int studentId, int tutorId, int[] availabilityIds, String description) throws SQLException {
        if (availabilityIds == null || availabilityIds.length == 0) {
            throw new IllegalStateException("noslots");
        }
        if (availabilityIds.length > MAX_SLOTS_PER_BOOKING) {
            throw new IllegalStateException("toomany");
        }

        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            // Lock the chosen slots, earliest first.
            StringBuilder in = new StringBuilder();
            for (int i = 0; i < availabilityIds.length; i++) {
                in.append(i == 0 ? "?" : ",?");
            }
            String slotSql = "SELECT availabilityId, tutorId, date, startTime, endTime, isBooked FROM availability "
                    + "WHERE availabilityId IN (" + in + ") ORDER BY startTime FOR UPDATE";

            List<String[]> slots = new ArrayList<>(); // [availabilityId, date, start, end]
            try (PreparedStatement ps = conn.prepareStatement(slotSql)) {
                for (int i = 0; i < availabilityIds.length; i++) {
                    ps.setInt(i + 1, availabilityIds[i]);
                }
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        if (rs.getInt("tutorId") != tutorId) {
                            throw new IllegalStateException("wrongtutor");
                        }
                        if (rs.getBoolean("isBooked")) {
                            throw new SQLException("This time slot has already been booked by someone else.");
                        }
                        slots.add(new String[]{
                            String.valueOf(rs.getInt("availabilityId")),
                            rs.getString("date"), rs.getString("startTime"), rs.getString("endTime")});
                    }
                }
            }

            if (slots.size() != availabilityIds.length) {
                throw new IllegalStateException("notfound");
            }

            // Same date, whole hours, and back to back.
            for (int i = 0; i < slots.size(); i++) {
                String[] sl = slots.get(i);
                if (!AvailabilityDAO.isWholeHours(sl[2], sl[3])) {
                    throw new IllegalStateException("wholehour");
                }
                if (i > 0) {
                    String[] prev = slots.get(i - 1);
                    if (!prev[1].equals(sl[1])
                            || !LocalTime.parse(prev[3]).equals(LocalTime.parse(sl[2]))) {
                        throw new IllegalStateException("notconsecutive");
                    }
                }
            }

            String date = slots.get(0)[1];
            String startTime = slots.get(0)[2];
            String endTime = slots.get(slots.size() - 1)[3];
            int firstAvailabilityId = Integer.parseInt(slots.get(0)[0]);

            String insertSql = "INSERT INTO booking (studentId, tutorId, availabilityId, bookingDate, startTime, endTime, status, description) "
                    + "VALUES (?, ?, ?, ?, ?, ?, 'PENDING', ?)";
            int generatedBookingId;
            try (PreparedStatement ps = conn.prepareStatement(insertSql, Statement.RETURN_GENERATED_KEYS)) {
                ps.setInt(1, studentId);
                ps.setInt(2, tutorId);
                ps.setInt(3, firstAvailabilityId);
                ps.setString(4, date);
                ps.setString(5, startTime);
                ps.setString(6, endTime);
                ps.setString(7, description);
                ps.executeUpdate();

                try (ResultSet keys = ps.getGeneratedKeys()) {
                    if (keys.next()) {
                        generatedBookingId = keys.getInt(1);
                    } else {
                        throw new SQLException("Failed to retrieve generated booking ID.");
                    }
                }
            }

            try (PreparedStatement link = conn.prepareStatement(
                         "INSERT INTO booking_slot (bookingId, availabilityId) VALUES (?, ?)");
                 PreparedStatement mark = conn.prepareStatement(
                         "UPDATE availability SET isBooked = TRUE WHERE availabilityId = ?")) {
                for (String[] sl : slots) {
                    int avId = Integer.parseInt(sl[0]);
                    link.setInt(1, generatedBookingId);
                    link.setInt(2, avId);
                    link.executeUpdate();
                    mark.setInt(1, avId);
                    mark.executeUpdate();
                }
            }

            conn.commit();
            return generatedBookingId;

        } catch (SQLException | RuntimeException e) {
            if (conn != null) {
                conn.rollback();
            }
            throw e;
        } finally {
            if (conn != null) {
                conn.close();
            }
        }
    }

    /** Frees every slot attached to a booking (used on decline / cancel). */
    private void freeSlots(Connection conn, int bookingId, int fallbackAvailabilityId) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(
                "UPDATE availability a JOIN booking_slot bs ON bs.availabilityId = a.availabilityId "
                + "SET a.isBooked = FALSE WHERE bs.bookingId = ?")) {
            ps.setInt(1, bookingId);
            ps.executeUpdate();
        }
        // Older bookings made before booking_slot existed.
        try (PreparedStatement ps = conn.prepareStatement(
                "UPDATE availability SET isBooked = FALSE WHERE availabilityId = ?")) {
            ps.setInt(1, fallbackAvailabilityId);
            ps.executeUpdate();
        }
    }

    /**
     * Fetches a single booking's core schedule fields by its exact ID.
     * Used right after creation to email confirmations with the correct
     * session details, instead of guessing which row in a sorted list
     * is "the one that was just created".
     */
    public BookingRow getBookingById(int bookingId) throws SQLException {
        String sql = "SELECT bookingId, bookingDate, startTime, endTime, status, tutorId, studentId, availabilityId "
                + "FROM booking WHERE bookingId = ?";
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, bookingId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return null;
                }
                BookingRow r = new BookingRow();
                r.bookingId = rs.getInt("bookingId");
                r.bookingDate = rs.getString("bookingDate");
                r.startTime = rs.getString("startTime");
                r.endTime = rs.getString("endTime");
                r.status = rs.getString("status");
                r.tutorId = rs.getInt("tutorId");
                r.studentId = rs.getInt("studentId");
                r.availabilityId = rs.getInt("availabilityId");
                return r;
            }
        }
    }

    public static boolean isCancellableStatus(String status) {
        return "PENDING".equals(status) || "AWAITING_PAYMENT".equals(status)
                || "PAYMENT_SUBMITTED".equals(status) || "CONFIRMED".equals(status);
    }

    /** Statuses where the student has already paid, so a late cancel is charged. */
    public static boolean isFeeStatus(String status) {
        return "PAYMENT_SUBMITTED".equals(status) || "CONFIRMED".equals(status);
    }

    /** Refund owed to the student: what they paid minus the cancellation fee (0 when no fee applied). */
    private static double refundFor(double rate, String start, String end, double fee) {
        if (fee <= 0 || start == null || end == null) {
            return 0;
        }
        long mins = Duration.between(LocalTime.parse(start), LocalTime.parse(end)).toMinutes();
        return Math.max(0, Math.round((rate * mins / 60.0 - fee) * 100) / 100.0);
    }

    /**
     * Cancels a booking on behalf of a student.
     *
     * Rules enforced here (not just in the UI):
     *  - the booking must belong to this student
     *  - status must be PENDING, AWAITING_PAYMENT, PAYMENT_SUBMITTED or CONFIRMED
     *  - the session must not have started yet
     *  - a reason is stored with the cancellation
     *  - cancelling is only allowed up to CANCEL_DEADLINE_HOURS before the start
     *    (after that the student can no longer cancel; a no-show can be flagged)
     *  - cancelling after payment was submitted (PAYMENT_SUBMITTED / CONFIRMED) costs
     *    CANCEL_FEE_PERCENT of (hourlyRate x hours); the rest is refunded to refundPaysharp
     *
     * @param refundPaysharp where the refund must be sent; required (code "norefund")
     *                       when the student has already paid.
     * @throws IllegalStateException with code "notfound", "notcancellable", "started", "tooclose" or "norefund"
     */
    public BookingRow cancelBookingByStudent(int bookingId, int studentId, String reason, String refundPaysharp) throws SQLException {
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            String checkSql = "SELECT b.tutorId, b.availabilityId, b.bookingDate, b.startTime, b.endTime, b.status, "
                    + "TIMESTAMPDIFF(SECOND, NOW(), TIMESTAMP(b.bookingDate, b.startTime)) AS secondsUntil, "
                    + "(SELECT t.hourlyRate FROM tutor t WHERE t.tutorId = b.tutorId) AS hourlyRate "
                    + "FROM booking b WHERE b.bookingId = ? AND b.studentId = ? FOR UPDATE";

            BookingRow info = new BookingRow();
            long secondsUntil;

            try (PreparedStatement ps = conn.prepareStatement(checkSql)) {
                ps.setInt(1, bookingId);
                ps.setInt(2, studentId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) {
                        throw new IllegalStateException("notfound");
                    }
                    info.bookingId = bookingId;
                    info.studentId = studentId;
                    info.tutorId = rs.getInt("tutorId");
                    info.availabilityId = rs.getInt("availabilityId");
                    info.bookingDate = rs.getString("bookingDate");
                    info.startTime = rs.getString("startTime");
                    info.endTime = rs.getString("endTime");
                    info.status = rs.getString("status");
                    info.hourlyRate = rs.getDouble("hourlyRate");
                    secondsUntil = rs.getLong("secondsUntil");
                }
            }

            if (!isCancellableStatus(info.status)) {
                throw new IllegalStateException("notcancellable");
            }

            if (secondsUntil <= 0) {
                throw new IllegalStateException("started");
            }

            if (secondsUntil < CANCEL_DEADLINE_HOURS * 3600L) {
                throw new IllegalStateException("tooclose");
            }

            info.cancellationFee = 0.0;
            if (isFeeStatus(info.status) && CANCEL_FEE_PERCENT > 0) {
                long minutes = Duration.between(
                        LocalTime.parse(info.startTime), LocalTime.parse(info.endTime)).toMinutes();
                BigDecimal fee = BigDecimal.valueOf(info.hourlyRate)
                        .multiply(BigDecimal.valueOf(minutes))
                        .divide(BigDecimal.valueOf(60), 4, RoundingMode.HALF_UP)
                        .multiply(BigDecimal.valueOf(CANCEL_FEE_PERCENT))
                        .setScale(2, RoundingMode.HALF_UP);
                info.cancellationFee = fee.doubleValue();
            }
            info.cancelReason = reason;
            info.refundAmount = refundFor(info.hourlyRate, info.startTime, info.endTime, info.cancellationFee);

            // A paid booking is refunded, so we need to know where to send the money.
            if (isFeeStatus(info.status) && (refundPaysharp == null || refundPaysharp.trim().isEmpty())) {
                throw new IllegalStateException("norefund");
            }
            info.refundPaysharp = (refundPaysharp == null || refundPaysharp.trim().isEmpty()) ? null : refundPaysharp.trim();

            String updateSql = "UPDATE booking SET status = 'CANCELLED_STUDENT', cancelReason = ?, "
                    + "cancellationFee = ?, refundPaysharp = ?, cancelledAt = NOW() WHERE bookingId = ? AND studentId = ?";
            try (PreparedStatement ps = conn.prepareStatement(updateSql)) {
                ps.setString(1, reason);
                ps.setBigDecimal(2, BigDecimal.valueOf(info.cancellationFee).setScale(2, RoundingMode.HALF_UP));
                ps.setString(3, info.refundPaysharp);
                ps.setInt(4, bookingId);
                ps.setInt(5, studentId);
                ps.executeUpdate();
            }

            freeSlots(conn, bookingId, info.availabilityId);

            conn.commit();
            return info;

        } catch (SQLException | RuntimeException e) {
            if (conn != null) {
                conn.rollback();
            }
            throw e;
        } finally {
            if (conn != null) {
                conn.close();
            }
        }
    }

    public List<BookingRow> getBookingsForStudent(int studentId) throws SQLException {
        String sql = "SELECT b.bookingId, u.name AS otherName, b.bookingDate, b.startTime, b.endTime, b.status, "
                + "b.tutorId, b.studentId, b.availabilityId, s.meetingLink, "
                + "b.description, b.paymentProofUrl, b.paymentSubmittedAt, t.paysharpDetails, b.refundPaysharp, "
                + "t.hourlyRate, b.cancelReason, b.cancellationFee, "
                + "CASE WHEN r.ratingId IS NOT NULL THEN 1 ELSE 0 END AS hasRating "
                + "FROM booking b "
                + "JOIN tutor t ON b.tutorId = t.tutorId "
                + "JOIN user u ON t.userId = u.userId "
                + "LEFT JOIN session s ON s.bookingId = b.bookingId "
                + "LEFT JOIN rating r ON r.sessionId = s.sessionId "
                + "WHERE b.studentId = ? ORDER BY b.bookingDate DESC, b.startTime DESC";
        List<BookingRow> rows = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, studentId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    BookingRow r = mapRow(rs);
                    r.hasRating = rs.getInt("hasRating") == 1;
                    r.hourlyRate = rs.getDouble("hourlyRate");
                    r.cancelReason = rs.getString("cancelReason");
                    r.cancellationFee = rs.getDouble("cancellationFee");
                    r.tutorPaysharp = rs.getString("paysharpDetails");
                    r.refundPaysharp = rs.getString("refundPaysharp");
                    r.refundAmount = refundFor(r.hourlyRate, r.startTime, r.endTime, r.cancellationFee);
                    rows.add(r);
                }
            }
        }
        return rows;
    }

    public List<BookingRow> getBookingsForTutor(int tutorId) throws SQLException {
        String sql = "SELECT b.bookingId, u.name AS otherName, b.bookingDate, b.startTime, b.endTime, b.status, "
                + "b.tutorId, b.studentId, b.availabilityId, s.meetingLink, "
                + "b.description, b.paymentProofUrl, b.paymentSubmittedAt, "
                + "b.cancelReason, b.cancellationFee, b.refundPaysharp, "
                + "(SELECT t2.hourlyRate FROM tutor t2 WHERE t2.tutorId = b.tutorId) AS hourlyRate "
                + "FROM booking b "
                + "JOIN student st ON b.studentId = st.studentId "
                + "JOIN user u ON st.userId = u.userId "
                + "LEFT JOIN session s ON s.bookingId = b.bookingId "
                + "WHERE b.tutorId = ? ORDER BY b.bookingDate DESC, b.startTime DESC";
        List<BookingRow> rows = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    BookingRow r = mapRow(rs);
                    r.hourlyRate = rs.getDouble("hourlyRate");
                    r.cancelReason = rs.getString("cancelReason");
                    r.cancellationFee = rs.getDouble("cancellationFee");
                    r.refundPaysharp = rs.getString("refundPaysharp");
                    r.refundAmount = refundFor(r.hourlyRate, r.startTime, r.endTime, r.cancellationFee);
                    rows.add(r);
                }
            }
        }
        return rows;
    }

    private BookingRow mapRow(ResultSet rs) throws SQLException {
        BookingRow r = new BookingRow();
        r.bookingId = rs.getInt("bookingId");
        r.otherPartyName = rs.getString("otherName");
        r.bookingDate = rs.getString("bookingDate");
        r.startTime = rs.getString("startTime");
        r.endTime = rs.getString("endTime");
        r.status = rs.getString("status");
        r.tutorId = rs.getInt("tutorId");
        r.studentId = rs.getInt("studentId");
        r.availabilityId = rs.getInt("availabilityId");
        r.meetingLink = rs.getString("meetingLink");
        r.description = rs.getString("description");
        r.paymentProofUrl = rs.getString("paymentProofUrl");
        r.paymentSubmittedAt = rs.getString("paymentSubmittedAt");
        return r;
    }

    public void respondToBooking(int bookingId, int tutorId, boolean accept, String declineReason) throws SQLException {
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            String checkSql = "SELECT availabilityId, status FROM booking WHERE bookingId = ? AND tutorId = ?";
            int availabilityId;
            String currentStatus;
            try (PreparedStatement ps = conn.prepareStatement(checkSql)) {
                ps.setInt(1, bookingId);
                ps.setInt(2, tutorId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) {
                        throw new SQLException("Booking not found.");
                    }
                    availabilityId = rs.getInt("availabilityId");
                    currentStatus = rs.getString("status");
                }
            }

            if (!"PENDING".equals(currentStatus)) {
                throw new SQLException("This booking has already been responded to.");
            }

            String newStatus = accept ? "AWAITING_PAYMENT" : "DECLINED";
            String updateSql = "UPDATE booking SET status = ?, declineReason = ? WHERE bookingId = ?";
            try (PreparedStatement ps = conn.prepareStatement(updateSql)) {
                ps.setString(1, newStatus);
                ps.setString(2, accept ? null : declineReason);
                ps.setInt(3, bookingId);
                ps.executeUpdate();
            }

            // Accepting only approves the request: the student must now pay and upload proof.
            // The slots stay reserved. A declined request frees all of its slots.
            if (!accept) {
                freeSlots(conn, bookingId, availabilityId);
            }

            conn.commit();
        } catch (SQLException e) {
            if (conn != null) {
                conn.rollback();
            }
            throw e;
        } finally {
            if (conn != null) {
                conn.close();
            }
        }
    }

    /**
     * Student uploads proof of payment for an approved booking.
     * Allowed while AWAITING_PAYMENT, or PAYMENT_SUBMITTED (to replace a wrong file
     * before the tutor confirms). Returns false if the booking isn't in such a state.
     */
    public boolean submitPaymentProof(int bookingId, int studentId, String proofPath) throws SQLException {
        String sql = "UPDATE booking SET status = 'PAYMENT_SUBMITTED', paymentProofUrl = ?, paymentSubmittedAt = NOW() "
                + "WHERE bookingId = ? AND studentId = ? AND status IN ('AWAITING_PAYMENT', 'PAYMENT_SUBMITTED')";
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, proofPath);
            ps.setInt(2, bookingId);
            ps.setInt(3, studentId);
            return ps.executeUpdate() > 0;
        }
    }

    /**
     * Tutor has received the proof of payment and sends the Teams link:
     * the booking becomes CONFIRMED and the session row is created with the link.
     * Returns false if the booking isn't PAYMENT_SUBMITTED for this tutor.
     */
    public boolean confirmWithLink(int bookingId, int tutorId, String meetingLink) throws SQLException {
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE booking SET status = 'CONFIRMED' "
                    + "WHERE bookingId = ? AND tutorId = ? AND status = 'PAYMENT_SUBMITTED'")) {
                ps.setInt(1, bookingId);
                ps.setInt(2, tutorId);
                if (ps.executeUpdate() == 0) {
                    conn.rollback();
                    return false;
                }
            }

            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO session (bookingId, sessionDate, startTime, endTime, meetingLink) "
                    + "SELECT bookingId, bookingDate, startTime, endTime, ? FROM booking WHERE bookingId = ?")) {
                ps.setString(1, meetingLink);
                ps.setInt(2, bookingId);
                ps.executeUpdate();
            }

            conn.commit();
            return true;
        } catch (SQLException | RuntimeException e) {
            if (conn != null) {
                conn.rollback();
            }
            throw e;
        } finally {
            if (conn != null) {
                conn.close();
            }
        }
    }

    /** Who may view a payment proof: returns [studentUserId, tutorUserId, path] or null. */
    public String[] getPaymentProofInfo(int bookingId) throws SQLException {
        String sql = "SELECT st.userId AS studentUserId, t.userId AS tutorUserId, b.paymentProofUrl "
                + "FROM booking b JOIN student st ON b.studentId = st.studentId "
                + "JOIN tutor t ON b.tutorId = t.tutorId WHERE b.bookingId = ?";
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, bookingId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next() || rs.getString("paymentProofUrl") == null) {
                    return null;
                }
                return new String[]{
                    String.valueOf(rs.getInt("studentUserId")),
                    String.valueOf(rs.getInt("tutorUserId")),
                    rs.getString("paymentProofUrl")};
            }
        }
    }

    public void markCompleted(int bookingId, int tutorId) throws SQLException {
        String sql = "UPDATE booking SET status = 'COMPLETED' WHERE bookingId = ? AND tutorId = ? AND status = 'CONFIRMED'";
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, bookingId);
            ps.setInt(2, tutorId);
            ps.executeUpdate();
        }
    }

    public Integer getUserIdForTutorId(int tutorId) throws SQLException {
        String sql = "SELECT userId FROM tutor WHERE tutorId = ?";
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt("userId") : null;
            }
        }
    }

    public Integer getStudentUserIdForBooking(int bookingId) throws SQLException {
        String sql = "SELECT st.userId FROM booking b JOIN student st ON b.studentId = st.studentId WHERE b.bookingId = ?";
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, bookingId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt("userId") : null;
            }
        }
    }
}