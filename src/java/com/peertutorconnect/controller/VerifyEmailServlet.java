package com.peertutorconnect.controller;

import com.peertutorconnect.dao.UserDAO;
import java.io.IOException;
import java.sql.SQLException;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Activates an account when the user clicks the link in the verification email.
 */
@WebServlet(name = "VerifyEmailServlet", urlPatterns = {"/verify-email"})
public class VerifyEmailServlet extends HttpServlet {

    private static final Logger LOGGER = Logger.getLogger(VerifyEmailServlet.class.getName());

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String token = request.getParameter("token");
        String base = request.getContextPath() + "/login.jsp";

        if (token == null || !token.matches("[0-9a-f]{64}")) {
            response.sendRedirect(base + "?verifyfailed=true");
            return;
        }

        try {
            if (new UserDAO().verifyEmail(token)) {
                response.sendRedirect(base + "?verified=true");
            } else {
                response.sendRedirect(base + "?verifyfailed=true");
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Email verification failed", e);
            response.sendRedirect(base + "?verifyfailed=true");
        }
    }
}
