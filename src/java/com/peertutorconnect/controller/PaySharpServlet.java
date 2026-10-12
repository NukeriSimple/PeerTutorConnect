package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AuditLogDAO;
import com.peertutorconnect.dao.AvailabilityDAO;
import com.peertutorconnect.dao.TutorDAO;
import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

/**
 * Lets an approved tutor save the PaySharp details students pay into.
 * Used from the dashboard (first time) and from the Profile page (updates).
 */
@WebServlet(name = "PaySharpServlet", urlPatterns = {"/tutor-paysharp"})
public class PaySharpServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || !"TUTOR".equals(session.getAttribute("role"))) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        int userId = (int) session.getAttribute("userId");
        String tutorName = (String) session.getAttribute("name");

        // Where to go back to: the Profile page if the form was submitted from there.
        boolean fromProfile = "profile".equals(request.getParameter("from"));
        String base = request.getContextPath() + (fromProfile ? "/profile" : "/tutor-dashboard.jsp");

        String details = request.getParameter("paysharp");
        details = (details == null) ? "" : details.trim();
        if (details.length() < 5 || details.length() > 255) {
            response.sendRedirect(base + "?paysharperror=invalid");
            return;
        }

        try {
            Integer tutorId = new AvailabilityDAO().getTutorIdForUser(userId);
            TutorDAO tutorDAO = new TutorDAO();

            // Only a tutor an admin has approved can take payments.
            if (tutorId == null || !tutorDAO.isVerified(tutorId)) {
                response.sendRedirect(base + "?error=notverified");
                return;
            }

            tutorDAO.setPaysharpDetails(tutorId, details);
            new AuditLogDAO().log(userId, tutorName, "PAYSHARP_UPDATED", "Updated PaySharp details");
            response.sendRedirect(base + "?paysharpsaved=true");

        } catch (SQLException e) {
            response.sendRedirect(base + "?paysharperror=server");
        }
    }
}