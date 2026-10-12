package com.peertutorconnect.controller;

import com.peertutorconnect.dao.NotificationDAO;
import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "NotificationServlet", urlPatterns = {"/notification"})
public class NotificationServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("userId") == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        int userId = (int) session.getAttribute("userId");
        String action = request.getParameter("action");
        NotificationDAO dao = new NotificationDAO();

        try {
            if ("markAll".equals(action)) {
                dao.markAllAsRead(userId);
                response.sendRedirect(request.getContextPath() + "/notifications.jsp");
                return;
            }

            String idParam = request.getParameter("id");
            if (idParam != null) {
                dao.markAsRead(Integer.parseInt(idParam), userId);
            }

            String redirectTo = request.getParameter("redirect");
            if (redirectTo != null && redirectTo.startsWith("/")) {
                response.sendRedirect(request.getContextPath() + redirectTo);
            } else {
                response.sendRedirect(request.getContextPath() + "/notifications.jsp");
            }

        } catch (SQLException e) {
            response.sendRedirect(request.getContextPath() + "/notifications.jsp?error=db");
        }
    }
}