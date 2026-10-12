package com.peertutorconnect.controller;

import com.peertutorconnect.dao.UserDAO;
import com.peertutorconnect.dao.UserDAO.ProfileRow;
import com.peertutorconnect.util.EmailUtil;
import com.peertutorconnect.util.PasswordUtil;
import java.io.IOException;
import java.sql.SQLException;
import java.util.UUID;
import java.util.regex.Pattern;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "ProfileServlet", urlPatterns = {"/profile"})
public class ProfileServlet extends HttpServlet {

    private static final Pattern EMAIL_PATTERN =
            Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$");
    private static final Pattern PHONE_PATTERN =
            Pattern.compile("^\\d{10}$");

    private final UserDAO userDAO = new UserDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        Integer userId = getUserId(request);
        if (userId == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        try {
            ProfileRow profile = userDAO.getProfile(userId);
            if (profile == null) {
                response.sendRedirect(request.getContextPath() + "/login.jsp");
                return;
            }
            request.setAttribute("profile", profile);

            if ("true".equals(request.getParameter("emailChanged"))) {
                request.setAttribute("infoSuccess", "Your email has been updated.");
            }

            request.getRequestDispatcher("/profile.jsp").forward(request, response);
        } catch (SQLException e) {
            throw new ServletException("Failed to load profile", e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        Integer userId = getUserId(request);
        if (userId == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String action = request.getParameter("action");
        if ("changePassword".equals(action)) {
            handlePasswordChange(request, response, userId);
        } else {
            handleInfoUpdate(request, response, userId);
        }
    }

    /**
     * Phone updates apply immediately. An email change does NOT update
     * user.email right away — it stores the request and emails a
     * confirmation link to the NEW address, so a typo or account
     * takeover attempt can't silently succeed.
     */
    private void handleInfoUpdate(HttpServletRequest request, HttpServletResponse response, int userId)
            throws ServletException, IOException {

        String email = request.getParameter("email");
        String phone = request.getParameter("phone");

        if (email == null || email.trim().isEmpty() ||
            phone == null || phone.trim().isEmpty()) {
            request.setAttribute("infoError", "Please fill in all required fields.");
            reloadProfile(request, response, userId);
            return;
        }

        email = email.trim();
        phone = phone.trim();

        if (!EMAIL_PATTERN.matcher(email).matches()) {
            request.setAttribute("infoError", "Please enter a valid email address.");
            reloadProfile(request, response, userId);
            return;
        }

        if (!PHONE_PATTERN.matcher(phone).matches()) {
            request.setAttribute("infoError", "Phone number must be exactly 10 digits.");
            reloadProfile(request, response, userId);
            return;
        }

        try {
            ProfileRow existing = userDAO.getProfile(userId);
            if (existing == null) {
                response.sendRedirect(request.getContextPath() + "/login.jsp");
                return;
            }

            // Phone updates immediately, regardless of whether email changed too.
            userDAO.updatePhone(userId, phone);

            boolean emailChanged = !email.equalsIgnoreCase(existing.email);

            if (emailChanged) {
                if (userDAO.emailExists(email, userId)) {
                    request.setAttribute("infoError", "Another account is already using this email.");
                    reloadProfile(request, response, userId);
                    return;
                }

                String token = UUID.randomUUID().toString();
                userDAO.setPendingEmail(userId, email, token);

                String confirmLink = request.getScheme() + "://" + request.getServerName()
                        + (request.getServerPort() == 80 || request.getServerPort() == 443 ? "" : ":" + request.getServerPort())
                        + request.getContextPath() + "/confirm-email?token=" + token;

                EmailUtil.sendEmailChangeConfirmation(email, existing.name, confirmLink);

                request.setAttribute("infoSuccess",
                        "Your phone number was updated. We've sent a confirmation link to " + email +
                        " — your email will change once you click it.");
            } else {
                request.setAttribute("infoSuccess", "Your profile has been updated.");
            }

            reloadProfile(request, response, userId);

        } catch (SQLException e) {
            java.util.logging.Logger.getLogger(ProfileServlet.class.getName()).log(java.util.logging.Level.SEVERE, "Profile update failed", e);
            request.setAttribute("infoError", "Update failed. Please try again later.");
            reloadProfile(request, response, userId);
        }
    }

    private void handlePasswordChange(HttpServletRequest request, HttpServletResponse response, int userId)
            throws ServletException, IOException {

        String currentPassword = request.getParameter("currentPassword");
        String newPassword = request.getParameter("newPassword");
        String confirmNewPassword = request.getParameter("confirmNewPassword");

        if (currentPassword == null || currentPassword.isEmpty() ||
            newPassword == null || newPassword.isEmpty()) {
            request.setAttribute("passwordError", "Please fill in all password fields.");
            reloadProfile(request, response, userId);
            return;
        }

        if (!newPassword.equals(confirmNewPassword)) {
            request.setAttribute("passwordError", "New passwords do not match.");
            reloadProfile(request, response, userId);
            return;
        }

        if (newPassword.length() < 8) {
            request.setAttribute("passwordError", "New password must be at least 8 characters.");
            reloadProfile(request, response, userId);
            return;
        }

        try {
            String currentHash = userDAO.getPasswordHash(userId);
            if (currentHash == null || !PasswordUtil.verify(currentPassword, currentHash)) {
                request.setAttribute("passwordError", "Current password is incorrect.");
                reloadProfile(request, response, userId);
                return;
            }

            userDAO.updatePassword(userId, newPassword);
            request.setAttribute("passwordSuccess", "Your password has been updated.");
            reloadProfile(request, response, userId);

        } catch (SQLException e) {
            java.util.logging.Logger.getLogger(ProfileServlet.class.getName()).log(java.util.logging.Level.SEVERE, "Password update failed", e);
            request.setAttribute("passwordError", "Update failed. Please try again later.");
            reloadProfile(request, response, userId);
        }
    }

    private void reloadProfile(HttpServletRequest request, HttpServletResponse response, int userId)
            throws ServletException, IOException {
        try {
            ProfileRow profile = userDAO.getProfile(userId);
            request.setAttribute("profile", profile);
            request.getRequestDispatcher("/profile.jsp").forward(request, response);
        } catch (SQLException e) {
            throw new ServletException("Failed to reload profile", e);
        }
    }

    private Integer getUserId(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session == null) return null;
        Object userId = session.getAttribute("userId");
        return (userId instanceof Integer) ? (Integer) userId : null;
    }
}