package com.peertutorconnect.controller;

import com.peertutorconnect.dao.UserDAO;
import com.peertutorconnect.util.EmailUtil;
import java.io.IOException;
import java.security.SecureRandom;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@WebServlet(name = "ForgotPasswordServlet", urlPatterns = {"/forgot-password"})
public class ForgotPasswordServlet extends HttpServlet {

    private static final SecureRandom RANDOM = new SecureRandom();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String email = request.getParameter("email");

        if (email == null || email.trim().isEmpty()) {
            request.setAttribute("error", "Please enter your email address.");
            request.getRequestDispatcher("/forgot-password.jsp").forward(request, response);
            return;
        }

        UserDAO userDAO = new UserDAO();

        try {
            String token = generateToken();
            String name = userDAO.setResetToken(email.trim(), token);

            // Only send the email if the address matched an account, but always
            // show the same confirmation screen either way — this prevents the
            // form from being used to check which emails are registered.
            if (name != null) {
                String baseUrl = request.getScheme() + "://" + request.getServerName()
                        + ":" + request.getServerPort() + request.getContextPath();
                String resetLink = baseUrl + "/reset-password.jsp?token=" + token;
                EmailUtil.sendPasswordResetEmail(email.trim(), name, resetLink);
            }

            response.sendRedirect(request.getContextPath() + "/forgot-password.jsp?sent=true");

        } catch (SQLException e) {
            request.setAttribute("error", "Something went wrong. Please try again.");
            request.getRequestDispatcher("/forgot-password.jsp").forward(request, response);
        }
    }

    private String generateToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}