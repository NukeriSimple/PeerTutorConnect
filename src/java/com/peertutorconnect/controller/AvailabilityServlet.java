package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AvailabilityDAO;
import com.peertutorconnect.dao.TutorDAO;
import java.io.IOException;
import java.sql.SQLException;
import java.time.LocalTime;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "AvailabilityServlet", urlPatterns = {"/availability"})
public class AvailabilityServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || !"TUTOR".equals(session.getAttribute("role"))) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        int userId = (int) session.getAttribute("userId");
        String action = request.getParameter("action");

        try {
            AvailabilityDAO dao = new AvailabilityDAO();
            Integer tutorId = dao.getTutorIdForUser(userId);

            if (tutorId == null) {
                response.sendRedirect(request.getContextPath() + "/manage-availability.jsp?error=notutor");
                return;
            }

            // A tutor can only manage availability once an admin has approved
            // their application. This blocks a direct POST to this servlet
            // from an unapproved tutor, even if they never visit the page.
            if (!new TutorDAO().isVerified(tutorId)) {
                response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?error=notverified");
                return;
            }

            if ("add".equals(action)) {
                String date = request.getParameter("date");
                String startTime = request.getParameter("startTime");

                if (date == null || date.trim().isEmpty() ||
                    startTime == null || startTime.trim().isEmpty()) {
                    response.sendRedirect(request.getContextPath() + "/manage-availability.jsp?error=missing");
                    return;
                }

                // Every slot is exactly one hour. The end time is calculated
                // here from the start time; any end time sent by the browser
                // is ignored so it can't be tampered with.
                LocalTime start;
                try {
                    start = LocalTime.parse(startTime.trim());
                } catch (Exception e) {
                    response.sendRedirect(request.getContextPath() + "/manage-availability.jsp?error=hours");
                    return;
                }

                // A start after 23:00 would run past midnight.
                if (start.isAfter(LocalTime.of(23, 0))) {
                    response.sendRedirect(request.getContextPath() + "/manage-availability.jsp?error=hours");
                    return;
                }

                String cleanStart = start.withSecond(0).withNano(0).toString();
                String cleanEnd = start.plusHours(1).withSecond(0).withNano(0).toString();

                if (!AvailabilityDAO.isOneHour(cleanStart, cleanEnd)) {
                    response.sendRedirect(request.getContextPath() + "/manage-availability.jsp?error=hours");
                    return;
                }

                dao.addSlot(tutorId, date, cleanStart, cleanEnd);

            } else if ("delete".equals(action)) {
                int availabilityId = Integer.parseInt(request.getParameter("availabilityId"));
                dao.deleteSlot(availabilityId, tutorId);
            }

            response.sendRedirect(request.getContextPath() + "/manage-availability.jsp?success=true");

        } catch (SQLException e) {
            response.sendRedirect(request.getContextPath() + "/manage-availability.jsp?error=db");
        }
    }
}