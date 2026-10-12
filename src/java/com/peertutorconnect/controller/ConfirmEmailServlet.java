package com.peertutorconnect.controller;

import com.peertutorconnect.dao.UserDAO;
import com.peertutorconnect.dao.UserDAO.EmailChangeRequest;
import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "ConfirmEmailServlet", urlPatterns = {"/confirm-email"})
public class ConfirmEmailServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String token = request.getParameter("token");
        if (token == null || token.trim().isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/login.jsp?error=invalidtoken");
            return;
        }

        UserDAO userDAO = new UserDAO();

        try {
            EmailChangeRequest req = userDAO.findByEmailChangeToken(token);
            if (req == null) {
                response.sendRedirect(request.getContextPath() + "/login.jsp?error=invalidtoken");
                return;
            }

            userDAO.confirmEmailChange(req.userId, req.pendingEmail);

            // If the confirming browser happens to still hold the old
            // session, keep it in sync so the sidebar/header don't show
            // a stale email anywhere that displays it.
            HttpSession session = request.getSession(false);
            if (session != null && session.getAttribute("userId") != null
                    && ((Integer) session.getAttribute("userId")) == req.userId) {
                response.sendRedirect(request.getContextPath() + "/profile?emailChanged=true");
                return;
            }

            response.sendRedirect(request.getContextPath() + "/login.jsp?emailChanged=true");

        } catch (SQLException e) {
            response.sendRedirect(request.getContextPath() + "/login.jsp?error=db");
        }
    }
}