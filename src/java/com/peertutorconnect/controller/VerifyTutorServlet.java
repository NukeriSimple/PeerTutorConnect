package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AdminDAO;
import com.peertutorconnect.dao.AuditLogDAO;
import com.peertutorconnect.dao.NotificationDAO;
import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "VerifyTutorServlet", urlPatterns = {"/verify-tutor"})
public class VerifyTutorServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || !"ADMIN".equals(session.getAttribute("role"))) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        int adminUserId = (int) session.getAttribute("userId");
        String adminName = (String) session.getAttribute("name");
        int tutorId = Integer.parseInt(request.getParameter("tutorId"));
        String action = request.getParameter("action");

        AdminDAO adminDAO = new AdminDAO();
        NotificationDAO notifyDAO = new NotificationDAO();
        AuditLogDAO auditDAO = new AuditLogDAO();

        try {
            // Only a tutor with a submitted, still-unverified application can be
            // approved or rejected here. This blocks a forged request against an
            // account that only just registered, or one already decided on.
            if (adminDAO.getPendingTutorById(tutorId) == null) {
                response.sendRedirect(request.getContextPath() + "/admin-dashboard.jsp?error=notpending");
                return;
            }

            Integer tutorUserId = adminDAO.getUserIdForTutor(tutorId);

            if ("approve".equals(action)) {
                adminDAO.approveTutor(tutorId);
                auditDAO.log(adminUserId, adminName, "TUTOR_APPROVED", "Approved tutorId=" + tutorId);
                if (tutorUserId != null) {
                    notifyDAO.create(tutorUserId, "Your tutor application has been approved. Please add your PaySharp details on your dashboard so students can pay you.", "/tutor-dashboard.jsp");
                }
            } else if ("reject".equals(action)) {
                auditDAO.log(adminUserId, adminName, "TUTOR_REJECTED", "Rejected tutorId=" + tutorId);
                if (tutorUserId != null) {
                    notifyDAO.create(tutorUserId, "Your tutor application was not approved.", "/index.jsp");
                }
                adminDAO.rejectTutor(tutorId);
            }
            response.sendRedirect(request.getContextPath() + "/admin-dashboard.jsp?success=true");
        } catch (SQLException e) {
            response.sendRedirect(request.getContextPath() + "/admin-dashboard.jsp?error=db");
        }
    }
}