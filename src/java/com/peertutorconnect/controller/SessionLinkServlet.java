package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AvailabilityDAO;
import com.peertutorconnect.dao.SessionDAO;
import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "SessionLinkServlet", urlPatterns = {"/session-link"})
public class SessionLinkServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || !"TUTOR".equals(session.getAttribute("role"))) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        int userId = (int) session.getAttribute("userId");
        int bookingId = Integer.parseInt(request.getParameter("bookingId"));
        String action = request.getParameter("action");
        String meetingLink = request.getParameter("meetingLink");

        try {
            AvailabilityDAO availDAO = new AvailabilityDAO();
            Integer tutorId = availDAO.getTutorIdForUser(userId);

            if (tutorId == null) {
                response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?error=notutor");
                return;
            }

            SessionDAO sessionDAO = new SessionDAO();

            if ("remove".equals(action)) {
                sessionDAO.removeMeetingLink(bookingId, tutorId);
            } else {
                if (meetingLink == null || meetingLink.trim().isEmpty()) {
                    response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?error=missinglink");
                    return;
                }
                sessionDAO.setMeetingLink(bookingId, tutorId, meetingLink.trim());
            }

            response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?success=true");

        } catch (SQLException e) {
            response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?error=db");
        }
    }
}