package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import com.peertutorconnect.util.PasswordUtil;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class UserDAO {

    public boolean emailExists(String email) throws SQLException {
        String sql = "SELECT userId FROM user WHERE email = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, email);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        }
    }

    /**
     * Same as emailExists, but excludes the given user's own row — needed
     * on the profile edit page so a user isn't blocked from "reusing"
     * their own existing email.
     */
    public boolean emailExists(String email, int excludeUserId) throws SQLException {
        String sql = "SELECT userId FROM user WHERE email = ? AND userId <> ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, email);
            ps.setInt(2, excludeUserId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        }
    }

    public int registerStudent(String name, String email, String phone, String plainPassword,
                                String department, int yearOfStudy) throws SQLException {
        return registerStudent(name, email, phone, plainPassword, department, yearOfStudy, null);
    }

    /** verifyToken != null: the account starts unverified and must be activated by the email link. */
    public int registerStudent(String name, String email, String phone, String plainPassword,
                                String department, int yearOfStudy,
                                String verifyToken) throws SQLException {
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            int userId = insertUser(conn, name, email, phone, plainPassword, "STUDENT", verifyToken);

            String sql = "INSERT INTO student (userId, department, yearOfStudy) VALUES (?, ?, ?)";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setInt(1, userId);
                ps.setString(2, department);
                ps.setInt(3, yearOfStudy);
                ps.executeUpdate();
            }

            conn.commit();
            return userId;
        } catch (SQLException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }

    public int registerTutor(String name, String email, String phone, String plainPassword,
                              double hourlyRate, String bio, int[] subjectIds) throws SQLException {
        return registerTutor(name, email, phone, plainPassword, hourlyRate, bio, subjectIds, false);
    }

    /**
     * Full tutor registration used by the admin "Add User" panel: creates
     * the account with a rate/bio already set, so the application is
     * considered complete immediately.
     */
    public int registerTutor(String name, String email, String phone, String plainPassword,
                              double hourlyRate, String bio, int[] subjectIds, boolean autoVerify) throws SQLException {
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            int userId = insertUser(conn, name, email, phone, plainPassword, "TUTOR");

            int tutorId;
            String sql = "INSERT INTO tutor (userId, hourlyRate, bio, isVerified, verifiedAt, applicationComplete) VALUES (?, ?, ?, ?, ?, TRUE)";
            try (PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
                ps.setInt(1, userId);
                ps.setDouble(2, hourlyRate);
                ps.setString(3, bio);
                ps.setBoolean(4, autoVerify);
                if (autoVerify) {
                    ps.setTimestamp(5, new Timestamp(System.currentTimeMillis()));
                } else {
                    ps.setNull(5, Types.TIMESTAMP);
                }
                ps.executeUpdate();
                try (ResultSet keys = ps.getGeneratedKeys()) {
                    if (keys.next()) {
                        tutorId = keys.getInt(1);
                    } else {
                        throw new SQLException("Failed to retrieve generated tutorId");
                    }
                }
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
            return userId;
        } catch (SQLException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }

    /**
     * Lightweight tutor registration used by the public sign-up form: just
     * the account and a bare tutor row. The rate, bio, subjects, and
     * documents are filled in afterward via TutorDAO.completeApplication
     * on the complete-tutor-application page, so applicationComplete
     * starts FALSE here.
     */
    public int registerTutorBasic(String name, String email, String phone, String plainPassword) throws SQLException {
        return registerTutorBasic(name, email, phone, plainPassword, null);
    }

    /** verifyToken != null: the account starts unverified and must be activated by the email link. */
    public int registerTutorBasic(String name, String email, String phone, String plainPassword,
                                  String verifyToken) throws SQLException {
        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            int userId = insertUser(conn, name, email, phone, plainPassword, "TUTOR", verifyToken);

            String sql = "INSERT INTO tutor (userId, hourlyRate, bio, isVerified, applicationComplete) VALUES (?, 0, '', FALSE, FALSE)";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setInt(1, userId);
                ps.executeUpdate();
            }

            conn.commit();
            return userId;
        } catch (SQLException e) {
            if (conn != null) conn.rollback();
            throw e;
        } finally {
            if (conn != null) conn.close();
        }
    }

    public int registerAdmin(String name, String email, String phone, String plainPassword) throws SQLException {
        try (Connection conn = DBConnection.getConnection()) {
            return insertUser(conn, name, email, phone, plainPassword, "ADMIN");
        }
    }

    /** Accounts created without a token (e.g. by an admin) are verified immediately. */
    private int insertUser(Connection conn, String name, String email, String phone,
                            String plainPassword, String role) throws SQLException {
        return insertUser(conn, name, email, phone, plainPassword, role, null);
    }

    private int insertUser(Connection conn, String name, String email, String phone,
                            String plainPassword, String role, String verifyToken) throws SQLException {
        boolean needsVerification = verifyToken != null;
        String sql = needsVerification
                ? "INSERT INTO user (email, passwordHash, name, phone, role, emailVerified, verifyToken, verifyTokenExpiry) "
                  + "VALUES (?, ?, ?, ?, ?, 0, ?, DATE_ADD(NOW(), INTERVAL 24 HOUR))"
                : "INSERT INTO user (email, passwordHash, name, phone, role, emailVerified) VALUES (?, ?, ?, ?, ?, 1)";
        try (PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, email);
            ps.setString(2, PasswordUtil.hash(plainPassword));
            ps.setString(3, name);
            ps.setString(4, phone);
            ps.setString(5, role);
            if (needsVerification) {
                ps.setString(6, verifyToken);
            }
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                if (keys.next()) {
                    return keys.getInt(1);
                }
            }
        }
        throw new SQLException("Failed to retrieve generated userId");
    }

    public static class LoginResult {
        public int userId;
        public String name;
        public String role;
        public String passwordHash;
        public boolean emailVerified;
    }

    public LoginResult findByEmail(String email) throws SQLException {
        String sql = "SELECT userId, name, role, passwordHash, emailVerified FROM user WHERE email = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, email);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    LoginResult r = new LoginResult();
                    r.userId = rs.getInt("userId");
                    r.name = rs.getString("name");
                    r.role = rs.getString("role");
                    r.passwordHash = rs.getString("passwordHash");
                    r.emailVerified = rs.getBoolean("emailVerified");
                    return r;
                }
                return null;
            }
        }
    }

    /** Activates the account that owns this (unexpired) token. Returns false if the link is invalid or expired. */
    public boolean verifyEmail(String token) throws SQLException {
        String sql = "UPDATE user SET emailVerified = 1, verifyToken = NULL, verifyTokenExpiry = NULL "
                   + "WHERE verifyToken = ? AND verifyTokenExpiry > NOW() AND emailVerified = 0";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, token);
            return ps.executeUpdate() > 0;
        }
    }

    /**
     * Issues a fresh 24-hour link for an account that is still unverified (older links stop working).
     * Returns true if a new token was stored.
     */
    public boolean renewVerificationToken(int userId, String token) throws SQLException {
        String sql = "UPDATE user SET verifyToken = ?, verifyTokenExpiry = DATE_ADD(NOW(), INTERVAL 24 HOUR) "
                   + "WHERE userId = ? AND emailVerified = 0";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, token);
            ps.setInt(2, userId);
            return ps.executeUpdate() > 0;
        }
    }

    /** Replaces a user's stored password hash (used to upgrade legacy SHA-256 hashes at login). */
    public void updatePasswordHash(int userId, String newHash) throws SQLException {
        String sql = "UPDATE user SET passwordHash = ? WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, newHash);
            ps.setInt(2, userId);
            ps.executeUpdate();
        }
    }

    public static class UserRow {
        public int userId;
        public String name;
        public String email;
        public String phone;
        public String role;
        public String createdAt;
    }

    public List<UserRow> getAllUsers() throws SQLException {
        String sql = "SELECT userId, name, email, phone, role, createdAt FROM user ORDER BY createdAt DESC";
        List<UserRow> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                UserRow u = new UserRow();
                u.userId = rs.getInt("userId");
                u.name = rs.getString("name");
                u.email = rs.getString("email");
                u.phone = rs.getString("phone");
                u.role = rs.getString("role");
                u.createdAt = rs.getString("createdAt");
                list.add(u);
            }
        }
        return list;
    }

    /**
     * Full profile row for the profile-settings page: basic user fields
     * plus student fields when applicable (null otherwise).
     */
    public static class ProfileRow {
        public int userId;
        public String name;
        public String email;
        public String phone;
        public String role;
        public String department;      // null for non-students
        public Integer yearOfStudy;    // null for non-students
    }

    public ProfileRow getProfile(int userId) throws SQLException {
        String sql = "SELECT u.userId, u.name, u.email, u.phone, u.role, " +
                     "s.department, s.yearOfStudy " +
                     "FROM user u LEFT JOIN student s ON s.userId = u.userId " +
                     "WHERE u.userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                ProfileRow p = new ProfileRow();
                p.userId = rs.getInt("userId");
                p.name = rs.getString("name");
                p.email = rs.getString("email");
                p.phone = rs.getString("phone");
                p.role = rs.getString("role");
                p.department = rs.getString("department");
                int year = rs.getInt("yearOfStudy");
                p.yearOfStudy = rs.wasNull() ? null : year;
                return p;
            }
        }
    }

    /**
     * Minimal name+email+phone lookup by userId. Used wherever a servlet
     * only has a userId on hand (e.g. from BookingDAO) and needs to send
     * that person an email or SMS.
     */
    public static class BasicInfo {
        public String name;
        public String email;
        public String phone;
    }

    public BasicInfo getBasicInfo(int userId) throws SQLException {
        String sql = "SELECT name, email, phone FROM user WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                BasicInfo b = new BasicInfo();
                b.name = rs.getString("name");
                b.email = rs.getString("email");
                b.phone = rs.getString("phone");
                return b;
            }
        }
    }

    /**
     * Updates the fields shared by every role: name, email, phone.
     * Kept for admin edit tooling, where an admin CAN directly change a
     * user's email without the confirmation-link flow.
     */
    public void updateBasicInfo(int userId, String name, String email, String phone) throws SQLException {
        String sql = "UPDATE user SET name = ?, email = ?, phone = ? WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, name);
            ps.setString(2, email);
            ps.setString(3, phone);
            ps.setInt(4, userId);
            ps.executeUpdate();
        }
    }

    /**
     * Updates ONLY phone, leaving email and name untouched. Used by the
     * profile-settings page: phone can change immediately, but email
     * changes go through the pending/confirm flow below instead.
     */
    public void updatePhone(int userId, String phone) throws SQLException {
        String sql = "UPDATE user SET phone = ? WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, phone);
            ps.setInt(2, userId);
            ps.executeUpdate();
        }
    }

    /**
     * Updates the student-only fields. Kept for admin tooling; the
     * profile-settings page no longer lets students change these
     * themselves.
     */
    public void updateStudentInfo(int userId, String department, int yearOfStudy) throws SQLException {
        String sql = "UPDATE student SET department = ?, yearOfStudy = ? WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, department);
            ps.setInt(2, yearOfStudy);
            ps.setInt(3, userId);
            ps.executeUpdate();
        }
    }

    /**
     * Starts an email change: stores the requested new address plus a
     * one-time token in pendingEmail/emailChangeToken, expiring in 1 hour.
     * The user's actual "email" column is untouched until the token is
     * confirmed via confirmEmailChange().
     */
    public void setPendingEmail(int userId, String newEmail, String token) throws SQLException {
        String sql = "UPDATE user SET pendingEmail = ?, emailChangeToken = ?, " +
                     "emailChangeTokenExpiry = DATE_ADD(NOW(), INTERVAL 1 HOUR) WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, newEmail);
            ps.setString(2, token);
            ps.setInt(3, userId);
            ps.executeUpdate();
        }
    }

    public static class EmailChangeRequest {
        public int userId;
        public String name;
        public String pendingEmail;
    }

    /**
     * Looks up a still-valid (unexpired) email-change token. Returns null
     * if the token doesn't exist or has expired.
     */
    public EmailChangeRequest findByEmailChangeToken(String token) throws SQLException {
        String sql = "SELECT userId, name, pendingEmail FROM user " +
                     "WHERE emailChangeToken = ? AND emailChangeTokenExpiry > NOW()";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, token);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    EmailChangeRequest r = new EmailChangeRequest();
                    r.userId = rs.getInt("userId");
                    r.name = rs.getString("name");
                    r.pendingEmail = rs.getString("pendingEmail");
                    return r;
                }
                return null;
            }
        }
    }

    /**
     * Finalizes a confirmed email change: moves pendingEmail into email
     * and clears the token fields.
     */
    public void confirmEmailChange(int userId, String newEmail) throws SQLException {
        String sql = "UPDATE user SET email = ?, pendingEmail = NULL, " +
                     "emailChangeToken = NULL, emailChangeTokenExpiry = NULL WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, newEmail);
            ps.setInt(2, userId);
            ps.executeUpdate();
        }
    }

    /**
     * Returns the current password hash for a user, so the profile page
     * can verify the "current password" before allowing a change.
     */
    public String getPasswordHash(int userId) throws SQLException {
        String sql = "SELECT passwordHash FROM user WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString("passwordHash") : null;
            }
        }
    }

    public void updatePassword(int userId, String newPlainPassword) throws SQLException {
        String sql = "UPDATE user SET passwordHash = ? WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, PasswordUtil.hash(newPlainPassword));
            ps.setInt(2, userId);
            ps.executeUpdate();
        }
    }

    public void deleteUser(int userId) throws SQLException {
        String sql = "DELETE FROM user WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.executeUpdate();
        }
    }

    public String setResetToken(String email, String token) throws SQLException {
        String sql = "UPDATE user SET resetToken = ?, resetTokenExpiry = DATE_ADD(NOW(), INTERVAL 1 HOUR) WHERE email = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, token);
            ps.setString(2, email);
            int updated = ps.executeUpdate();
            if (updated == 0) return null;
        }

        String nameSql = "SELECT name FROM user WHERE email = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(nameSql)) {
            ps.setString(1, email);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString("name") : null;
            }
        }
    }

    public static class ResetTokenResult {
        public int userId;
        public String name;
        public String email;
    }

    public ResetTokenResult findByResetToken(String token) throws SQLException {
        String sql = "SELECT userId, name, email FROM user WHERE resetToken = ? AND resetTokenExpiry > NOW()";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, token);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    ResetTokenResult r = new ResetTokenResult();
                    r.userId = rs.getInt("userId");
                    r.name = rs.getString("name");
                    r.email = rs.getString("email");
                    return r;
                }
                return null;
            }
        }
    }

    public void resetPassword(int userId, String newPlainPassword) throws SQLException {
        String sql = "UPDATE user SET passwordHash = ?, resetToken = NULL, resetTokenExpiry = NULL WHERE userId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, PasswordUtil.hash(newPlainPassword));
            ps.setInt(2, userId);
            ps.executeUpdate();
        }
    }
}