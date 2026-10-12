package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AuditLogDAO;
import com.peertutorconnect.dao.AvailabilityDAO;
import com.peertutorconnect.dao.TutorDAO;
import com.peertutorconnect.dao.UserDAO;
import com.peertutorconnect.util.EmailUtil;
import com.peertutorconnect.util.PasswordUtil;
import com.peertutorconnect.util.TokenUtil;
import java.io.IOException;
import java.sql.SQLException;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

/**
 * Handles login. Hardened with: a fresh session on login (prevents session fixation),
 * a temporary lockout after repeated failures, generic error messages, and automatic
 * upgrade of legacy SHA-256 password hashes to PBKDF2.
 */
@WebServlet(name = "LoginServlet", urlPatterns = {"/login"})
public class LoginServlet extends HttpServlet {

    private static final Logger LOGGER = Logger.getLogger(LoginServlet.class.getName());
    private static final int MAX_FAILURES = 5;
    private static final long LOCK_MILLIS = 5 * 60 * 1000L;

    /** Failed-login counters kept in memory, keyed by lower-cased email. */
    private static final ConcurrentHashMap<String, Attempts> ATTEMPTS = new ConcurrentHashMap<>();

    private static class Attempts {
        int failures;
        long lockedUntil;
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String email = request.getParameter("email");
        String password = request.getParameter("password");

        if (email == null || email.trim().isEmpty() || password == null || password.isEmpty()) {
            fail(request, response, "Please enter both email and password.");
            return;
        }
        email = email.trim();
        String key = email.toLowerCase();

        Attempts attempts = ATTEMPTS.computeIfAbsent(key, k -> new Attempts());
        synchronized (attempts) {
            if (attempts.lockedUntil > System.currentTimeMillis()) {
                fail(request, response, "Too many failed attempts. Please try again in a few minutes.");
                return;
            }
        }

        UserDAO userDAO = new UserDAO();
        AuditLogDAO auditDAO = new AuditLogDAO();

        try {
            UserDAO.LoginResult user = userDAO.findByEmail(email);

            if (user == null || !PasswordUtil.verify(password, user.passwordHash)) {
                synchronized (attempts) {
                    if (++attempts.failures >= MAX_FAILURES) {
                        attempts.lockedUntil = System.currentTimeMillis() + LOCK_MILLIS;
                        attempts.failures = 0;
                    }
                }
                auditDAO.log(null, email, "LOGIN_FAILED", "Invalid credentials for " + email);
                fail(request, response, "Invalid email or password.");
                return;
            }

            ATTEMPTS.remove(key);

            // Correct password but the email link was never clicked: no access yet.
            // Send a fresh link (older ones stop working) and stop here.
            if (!user.emailVerified) {
                String token = TokenUtil.newToken();
                if (userDAO.renewVerificationToken(user.userId, token)) {
                    String baseUrl = request.getScheme() + "://" + request.getServerName()
                            + ":" + request.getServerPort() + request.getContextPath();
                    EmailUtil.sendVerificationEmail(email, user.name, user.role,
                            baseUrl + "/verify-email?token=" + token);
                }
                auditDAO.log(user.userId, user.name, "LOGIN_BLOCKED", "Email not verified");
                // login.jsp shows a pop-up dialog when this attribute is present
                request.setAttribute("unverifiedEmail", email);
                request.getRequestDispatcher("/login.jsp").forward(request, response);
                return;
            }

            // Upgrade old SHA-256 hashes to PBKDF2 now that we know the plain password.
            if (PasswordUtil.needsRehash(user.passwordHash)) {
                userDAO.updatePasswordHash(user.userId, PasswordUtil.hash(password));
            }

            // New session after authentication: stops session fixation.
            HttpSession old = request.getSession(false);
            if (old != null) {
                old.invalidate();
            }
            HttpSession session = request.getSession(true);
            session.setAttribute("userId", user.userId);
            session.setAttribute("name", user.name);
            session.setAttribute("role", user.role);

            auditDAO.log(user.userId, user.name, "LOGIN", "Logged in as " + user.role);

            // A tutor whose post-registration application isn't finished yet
            // gets sent there first, before any redirect/dashboard logic.
            if ("TUTOR".equals(user.role)) {
                AvailabilityDAO availDAO = new AvailabilityDAO();
                Integer tutorId = availDAO.getTutorIdForUser(user.userId);
                if (tutorId != null && !new TutorDAO().isApplicationComplete(tutorId)) {
                    response.sendRedirect(request.getContextPath() + "/complete-tutor-application.jsp");
                    return;
                }
            }

            String redirect = request.getParameter("redirect");
            if ("STUDENT".equals(user.role) && redirect != null
                    && redirect.matches("book-session\\.jsp\\?tutorId=\\d+")) {
                response.sendRedirect(request.getContextPath() + "/" + redirect);
                return;
            }

            switch (user.role) {
                case "STUDENT":
                    response.sendRedirect(request.getContextPath() + "/student-dashboard.jsp");
                    break;
                case "TUTOR":
                    response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp");
                    break;
                case "ADMIN":
                    response.sendRedirect(request.getContextPath() + "/admin-dashboard.jsp");
                    break;
                default:
                    response.sendRedirect(request.getContextPath() + "/index.jsp");
            }

        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Login failed due to a database error", e);
            fail(request, response, "Something went wrong. Please try again later.");
        }
    }

    private void fail(HttpServletRequest request, HttpServletResponse response, String message)
            throws ServletException, IOException {
        request.setAttribute("error", message);
        request.getRequestDispatcher("/login.jsp").forward(request, response);
    }
}