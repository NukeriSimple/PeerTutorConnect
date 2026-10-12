package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import com.peertutorconnect.util.EmailUtil;
import java.sql.*;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Monthly tutor subscription (R59.99).
 *
 *  - A tutor pays the admin and uploads proof of payment; the admin approves or rejects it.
 *  - Approving a payment for month M keeps the tutor active until the last day of M.
 *  - 4 days before month end the tutor gets a reminder (notification + email), once per month.
 *  - If the tutor is not paid up when a month ends, the account is frozen: it disappears from
 *    search and nobody can book it. Paying (and the admin approving) unfreezes it.
 *  - A tutor with a payment awaiting admin review is never frozen, so a slow admin doesn't punish them.
 *  - Each tutor's first month is free: when a verified tutor is first seen they are paid up to the end of that month.
 *
 * The two tables below are created automatically.
 */
public class SubscriptionDAO {

    private static final Logger LOGGER = Logger.getLogger(SubscriptionDAO.class.getName());

    public static final double MONTHLY_FEE = 59.99;
    public static final int REMINDER_DAYS_BEFORE_MONTH_END = 4;

    private static boolean tablesReady = false;

    public static synchronized void ensureTables() throws SQLException {
        if (tablesReady) return;
        try (Connection conn = DBConnection.getConnection()) {
            try (Statement st = conn.createStatement()) {
                st.executeUpdate("CREATE TABLE IF NOT EXISTS tutor_subscription ("
                        + "tutorId INT PRIMARY KEY, "
                        + "paidUntil DATE NOT NULL, "
                        + "frozen TINYINT(1) NOT NULL DEFAULT 0, "
                        + "frozenAt TIMESTAMP NULL, "
                        + "lastReminder VARCHAR(7) NULL)");
                st.executeUpdate("CREATE TABLE IF NOT EXISTS subscription_payment ("
                        + "paymentId INT AUTO_INCREMENT PRIMARY KEY, "
                        + "tutorId INT NOT NULL, tutorUserId INT NOT NULL, tutorName VARCHAR(255), "
                        + "period VARCHAR(7) NOT NULL, "
                        + "amount DECIMAL(8,2) NOT NULL, "
                        + "proofPath VARCHAR(500) NOT NULL, "
                        + "status VARCHAR(10) NOT NULL DEFAULT 'PENDING', "
                        + "rejectReason VARCHAR(300) NULL, "
                        + "submittedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "
                        + "reviewedAt TIMESTAMP NULL, reviewedBy INT NULL)");
            } catch (SQLException createFailed) {
                // CREATE may be denied for the app user; carry on if the tables already exist.
                try (Statement st = conn.createStatement()) {
                    st.executeQuery("SELECT tutorId FROM tutor_subscription LIMIT 1").close();
                    st.executeQuery("SELECT paymentId FROM subscription_payment LIMIT 1").close();
                } catch (SQLException missing) {
                    throw new SQLException("Subscription tables are missing and could not be created: "
                            + createFailed.getMessage(), createFailed);
                }
            }
        }
        tablesReady = true;
    }

    // ---------------- data classes ----------------
    public static class Status {
        public int tutorId;
        public String paidUntil;      // yyyy-MM-dd
        public boolean frozen;
        public String nextPeriod;     // yyyy-MM, the month the tutor should pay for next
        public boolean hasPending;
    }

    public static class Payment {
        public int paymentId;
        public int tutorId;
        public int tutorUserId;
        public String tutorName;
        public String period;
        public double amount;
        public String status;
        public String rejectReason;
        public String submittedAt;
        public String reviewedAt;
    }

    public static class TutorRow {
        public int tutorId;
        public String name;
        public String paidUntil;
        public boolean frozen;
        public boolean hasPending;
    }

    // ---------------- helpers ----------------
    public static String formatFee() {
        return String.format("R%.2f", MONTHLY_FEE);
    }

    /** "2026-11" -> "November 2026" */
    public static String prettyPeriod(String period) {
        try {
            YearMonth ym = YearMonth.parse(period);
            String month = ym.getMonth().getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.ENGLISH);
            return month + " " + ym.getYear();
        } catch (Exception e) {
            return period;
        }
    }

    // ---------------- reads ----------------
    public boolean isFrozen(int tutorId) throws SQLException {
        ensureTables();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT frozen FROM tutor_subscription WHERE tutorId = ?")) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getBoolean(1);
            }
        }
    }

    /** Status for one tutor. Creates their row (first month free) if they don't have one yet. */
    public Status getStatus(int tutorId) throws SQLException {
        ensureTables();
        try (Connection conn = DBConnection.getConnection()) {
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT IGNORE INTO tutor_subscription (tutorId, paidUntil) VALUES (?, LAST_DAY(CURDATE()))")) {
                ps.setInt(1, tutorId);
                ps.executeUpdate();
            }
            Status s = new Status();
            s.tutorId = tutorId;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT paidUntil, frozen FROM tutor_subscription WHERE tutorId = ?")) {
                ps.setInt(1, tutorId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) return null;
                    s.paidUntil = rs.getString("paidUntil");
                    s.frozen = rs.getBoolean("frozen");
                }
            }
            s.nextPeriod = YearMonth.from(LocalDate.parse(s.paidUntil)).plusMonths(1).toString();
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) FROM subscription_payment WHERE tutorId = ? AND status = 'PENDING'")) {
                ps.setInt(1, tutorId);
                try (ResultSet rs = ps.executeQuery()) {
                    s.hasPending = rs.next() && rs.getInt(1) > 0;
                }
            }
            return s;
        }
    }

    public List<Payment> getPaymentsForTutor(int tutorId) throws SQLException {
        return queryPayments("WHERE tutorId = ?", tutorId);
    }

    public List<Payment> getAllPayments() throws SQLException {
        return queryPayments("", null);
    }

    private List<Payment> queryPayments(String where, Integer tutorId) throws SQLException {
        ensureTables();
        String sql = "SELECT paymentId, tutorId, tutorUserId, tutorName, period, amount, status, rejectReason, "
                + "submittedAt, reviewedAt FROM subscription_payment " + where
                + " ORDER BY (status = 'PENDING') DESC, submittedAt DESC";
        List<Payment> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            if (tutorId != null) ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Payment p = new Payment();
                    p.paymentId = rs.getInt("paymentId");
                    p.tutorId = rs.getInt("tutorId");
                    p.tutorUserId = rs.getInt("tutorUserId");
                    p.tutorName = rs.getString("tutorName");
                    p.period = rs.getString("period");
                    p.amount = rs.getDouble("amount");
                    p.status = rs.getString("status");
                    p.rejectReason = rs.getString("rejectReason");
                    p.submittedAt = rs.getString("submittedAt");
                    p.reviewedAt = rs.getString("reviewedAt");
                    list.add(p);
                }
            }
        }
        return list;
    }

    /** Every verified tutor with their subscription state, frozen ones first. */
    public List<TutorRow> getTutorRows() throws SQLException {
        ensureTables();
        ensureStateRows();
        String sql = "SELECT s.tutorId, u.name, s.paidUntil, s.frozen, "
                + "EXISTS (SELECT 1 FROM subscription_payment p WHERE p.tutorId = s.tutorId AND p.status = 'PENDING') AS hasPending "
                + "FROM tutor_subscription s JOIN tutor t ON t.tutorId = s.tutorId JOIN user u ON u.userId = t.userId "
                + "WHERE t.isVerified = TRUE ORDER BY s.frozen DESC, s.paidUntil ASC, u.name ASC";
        List<TutorRow> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                TutorRow r = new TutorRow();
                r.tutorId = rs.getInt("tutorId");
                r.name = rs.getString("name");
                r.paidUntil = rs.getString("paidUntil");
                r.frozen = rs.getBoolean("frozen");
                r.hasPending = rs.getBoolean("hasPending");
                list.add(r);
            }
        }
        return list;
    }

    /** [tutorUserId, proofPath] or null. */
    public String[] getProofInfo(int paymentId) throws SQLException {
        ensureTables();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                     "SELECT tutorUserId, proofPath FROM subscription_payment WHERE paymentId = ?")) {
            ps.setInt(1, paymentId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? new String[]{String.valueOf(rs.getInt(1)), rs.getString(2)} : null;
            }
        }
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

    // ---------------- tutor submits proof ----------------
    /**
     * Records a payment for the tutor's next unpaid month.
     * @return the period (yyyy-MM) the payment is for
     * @throws IllegalStateException "pending" if a payment is already waiting for review
     */
    public String submit(int tutorId, int tutorUserId, String tutorName, String proofPath) throws SQLException {
        Status s = getStatus(tutorId);
        if (s == null) throw new IllegalStateException("notfound");
        if (s.hasPending) throw new IllegalStateException("pending");
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                     "INSERT INTO subscription_payment (tutorId, tutorUserId, tutorName, period, amount, proofPath, status) "
                     + "VALUES (?, ?, ?, ?, ?, ?, 'PENDING')")) {
            ps.setInt(1, tutorId);
            ps.setInt(2, tutorUserId);
            ps.setString(3, tutorName);
            ps.setString(4, s.nextPeriod);
            ps.setDouble(5, MONTHLY_FEE);
            ps.setString(6, proofPath);
            ps.executeUpdate();
        }
        return s.nextPeriod;
    }

    // ---------------- admin decisions ----------------
    /** @throws IllegalStateException "notfound" or "resolved" */
    public Payment approve(int paymentId, int adminUserId) throws SQLException {
        ensureTables();
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);
            Payment p = lockPending(conn, paymentId);

            LocalDate newUntil = YearMonth.parse(p.period).atEndOfMonth();
            boolean stillOverdue = newUntil.isBefore(LocalDate.now());

            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE subscription_payment SET status = 'APPROVED', reviewedAt = NOW(), reviewedBy = ? WHERE paymentId = ?")) {
                ps.setInt(1, adminUserId);
                ps.setInt(2, paymentId);
                ps.executeUpdate();
            }
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE tutor_subscription SET paidUntil = GREATEST(paidUntil, ?), frozen = ?, "
                    + "frozenAt = IF(?, frozenAt, NULL) WHERE tutorId = ?")) {
                ps.setDate(1, java.sql.Date.valueOf(newUntil));
                ps.setBoolean(2, stillOverdue);
                ps.setBoolean(3, stillOverdue);
                ps.setInt(4, p.tutorId);
                ps.executeUpdate();
            }
            conn.commit();
            return p;
        } catch (SQLException | RuntimeException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }

    /** @throws IllegalStateException "notfound" or "resolved" */
    public Payment reject(int paymentId, int adminUserId, String reason) throws SQLException {
        ensureTables();
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);
            Payment p = lockPending(conn, paymentId);
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE subscription_payment SET status = 'REJECTED', rejectReason = ?, reviewedAt = NOW(), reviewedBy = ? "
                    + "WHERE paymentId = ?")) {
                ps.setString(1, reason);
                ps.setInt(2, adminUserId);
                ps.setInt(3, paymentId);
                ps.executeUpdate();
            }
            conn.commit();
            p.rejectReason = reason;
            return p;
        } catch (SQLException | RuntimeException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }

    private Payment lockPending(Connection conn, int paymentId) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT paymentId, tutorId, tutorUserId, tutorName, period, amount, status "
                + "FROM subscription_payment WHERE paymentId = ? FOR UPDATE")) {
            ps.setInt(1, paymentId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) throw new IllegalStateException("notfound");
                if (!"PENDING".equals(rs.getString("status"))) throw new IllegalStateException("resolved");
                Payment p = new Payment();
                p.paymentId = rs.getInt("paymentId");
                p.tutorId = rs.getInt("tutorId");
                p.tutorUserId = rs.getInt("tutorUserId");
                p.tutorName = rs.getString("tutorName");
                p.period = rs.getString("period");
                p.amount = rs.getDouble("amount");
                p.status = rs.getString("status");
                return p;
            }
        }
    }

    // ---------------- background job (called by MaintenanceJob every 5 minutes) ----------------
    private static void ensureStateRows() throws SQLException {
        try (Connection conn = DBConnection.getConnection(); Statement st = conn.createStatement()) {
            st.executeUpdate("INSERT IGNORE INTO tutor_subscription (tutorId, paidUntil) "
                    + "SELECT tutorId, LAST_DAY(CURDATE()) FROM tutor WHERE isVerified = TRUE");
        }
    }

    public static void runMonthlyChecks() throws SQLException {
        ensureTables();
        ensureStateRows();
        freezeOverdueTutors();
        sendReminders();
    }

    private static void freezeOverdueTutors() throws SQLException {
        String sql = "SELECT s.tutorId, t.userId, u.name, u.email, s.paidUntil FROM tutor_subscription s "
                + "JOIN tutor t ON t.tutorId = s.tutorId JOIN user u ON u.userId = t.userId "
                + "WHERE s.frozen = FALSE AND s.paidUntil < CURDATE() AND t.isVerified = TRUE "
                + "AND NOT EXISTS (SELECT 1 FROM subscription_payment p WHERE p.tutorId = s.tutorId AND p.status = 'PENDING')";
        NotificationDAO notify = new NotificationDAO();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            List<Integer> admins = null;
            while (rs.next()) {
                int tutorId = rs.getInt("tutorId");
                int userId = rs.getInt("userId");
                String name = rs.getString("name");
                String email = rs.getString("email");
                String nextPeriod = YearMonth.from(LocalDate.parse(rs.getString("paidUntil"))).plusMonths(1).toString();

                int changed;
                try (PreparedStatement up = conn.prepareStatement(
                        "UPDATE tutor_subscription SET frozen = TRUE, frozenAt = NOW() WHERE tutorId = ? AND frozen = FALSE")) {
                    up.setInt(1, tutorId);
                    changed = up.executeUpdate();
                }
                if (changed == 0) continue;
                LOGGER.log(Level.INFO, "Tutor {0} frozen: subscription not paid", tutorId);

                try {
                    notify.create(userId, "Your account is frozen because your " + formatFee()
                            + " subscription was not paid. Students can't book you until you pay for "
                            + prettyPeriod(nextPeriod) + " and the admin approves it.", "/tutor-subscription.jsp");
                    if (admins == null) admins = new SubscriptionDAO().getAdminUserIds();
                    for (int adminId : admins) {
                        notify.create(adminId, name + " was flagged and frozen for an unpaid subscription.",
                                "/admin-subscriptions.jsp");
                    }
                } catch (SQLException e) {
                    LOGGER.log(Level.WARNING, "Frozen tutor " + tutorId + " but could not notify", e);
                }
                EmailUtil.sendSimpleEmail(email, "Your PeerTutorConnect account is frozen",
                        "Hi " + name + ",\n\nYour monthly subscription of " + formatFee() + " was not paid, so your account "
                        + "has been frozen and students can no longer book you.\n\nLog in, go to Subscription, and upload "
                        + "your proof of payment for " + prettyPeriod(nextPeriod) + ". Once the admin approves it, your "
                        + "account is active again.\n\n- The PeerTutorConnect Team");
            }
        }
    }

    private static void sendReminders() throws SQLException {
        // Due when: within the last N days of the month, paid only up to this month, nothing waiting for review,
        // and not already reminded this month.
        String sql = "SELECT s.tutorId, t.userId, u.name, u.email, LAST_DAY(CURDATE()) AS monthEnd, "
                + "DATE_FORMAT(CURDATE() + INTERVAL 1 MONTH, '%Y-%m') AS nextPeriod, DATE_FORMAT(CURDATE(), '%Y-%m') AS thisMonth "
                + "FROM tutor_subscription s JOIN tutor t ON t.tutorId = s.tutorId JOIN user u ON u.userId = t.userId "
                + "WHERE s.frozen = FALSE AND t.isVerified = TRUE "
                + "AND s.paidUntil <= LAST_DAY(CURDATE()) "
                + "AND CURDATE() >= LAST_DAY(CURDATE()) - INTERVAL " + REMINDER_DAYS_BEFORE_MONTH_END + " DAY "
                + "AND (s.lastReminder IS NULL OR s.lastReminder <> DATE_FORMAT(CURDATE(), '%Y-%m')) "
                + "AND NOT EXISTS (SELECT 1 FROM subscription_payment p WHERE p.tutorId = s.tutorId AND p.status = 'PENDING')";
        NotificationDAO notify = new NotificationDAO();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                int tutorId = rs.getInt("tutorId");
                int changed;
                try (PreparedStatement up = conn.prepareStatement(
                        "UPDATE tutor_subscription SET lastReminder = ? WHERE tutorId = ? "
                        + "AND (lastReminder IS NULL OR lastReminder <> ?)")) {
                    up.setString(1, rs.getString("thisMonth"));
                    up.setInt(2, tutorId);
                    up.setString(3, rs.getString("thisMonth"));
                    changed = up.executeUpdate();
                }
                if (changed == 0) continue;

                String name = rs.getString("name");
                String monthEnd = rs.getString("monthEnd");
                String pretty = prettyPeriod(rs.getString("nextPeriod"));
                try {
                    notify.create(rs.getInt("userId"), "Reminder: your " + formatFee() + " subscription for " + pretty
                            + " is due by " + monthEnd + ". Upload your proof of payment, or your account will be frozen "
                            + "and students won't be able to book you.", "/tutor-subscription.jsp");
                } catch (SQLException e) {
                    LOGGER.log(Level.WARNING, "Subscription reminder notification failed for tutor " + tutorId, e);
                }
                EmailUtil.sendSimpleEmail(rs.getString("email"), "Reminder: subscription due by " + monthEnd,
                        "Hi " + name + ",\n\nYour monthly PeerTutorConnect subscription of " + formatFee() + " for " + pretty
                        + " is due by " + monthEnd + ".\n\nLog in, go to Subscription, and upload your proof of payment. "
                        + "If it isn't paid, your account will be flagged and frozen, and students won't be able to book you."
                        + "\n\n- The PeerTutorConnect Team");
            }
        }
    }
}