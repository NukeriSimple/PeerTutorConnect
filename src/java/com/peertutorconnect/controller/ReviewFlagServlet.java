package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AuditLogDAO;
import com.peertutorconnect.dao.AvailabilityDAO;
import com.peertutorconnect.dao.NotificationDAO;
import com.peertutorconnect.dao.ReviewDAO;
import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

/**
 * action=flag    (TUTOR)  tutor reports a review about them, with a reason
 * action=keep    (ADMIN)  admin keeps the review
 * action=remove  (ADMIN)  admin removes the review (tutor's average is recalculated)
 */
@WebServlet(name = "ReviewFlagServlet", urlPatterns = {"/review-flag"})
public class ReviewFlagServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("role") == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }
        String role = (String) session.getAttribute("role");
        String action = request.getParameter("action");
        if (action == null) action = "";

        if ("flag".equals(action) && "TUTOR".equals(role)) { flag(request, response, session); return; }
        if (("keep".equals(action) || "remove".equals(action)) && "ADMIN".equals(role)) {
            resolve(request, response, session, "remove".equals(action));
            return;
        }
        response.sendError(HttpServletResponse.SC_FORBIDDEN, "Not allowed.");
    }

    private void flag(HttpServletRequest request, HttpServletResponse response, HttpSession session)
            throws IOException {
        String base = request.getContextPath() + "/tutor-reviews.jsp";
        int userId = (int) session.getAttribute("userId");
        String tutorName = (String) session.getAttribute("name");

        int ratingId;
        try {
            ratingId = Integer.parseInt(request.getParameter("ratingId"));
        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?reviewerror=invalid");
            return;
        }
        String reason = request.getParameter("reason");
        reason = (reason == null) ? "" : reason.trim();
        if (reason.length() < ReviewDAO.MIN_REASON) {
            response.sendRedirect(base + "?reviewerror=noreason");
            return;
        }
        if (reason.length() > ReviewDAO.MAX_REASON) reason = reason.substring(0, ReviewDAO.MAX_REASON);

        try {
            Integer tutorId = new AvailabilityDAO().getTutorIdForUser(userId);
            if (tutorId == null) {
                response.sendRedirect(base + "?reviewerror=invalid");
                return;
            }
            ReviewDAO dao = new ReviewDAO();
            ReviewDAO.FlagResult r = dao.flag(ratingId, tutorId, userId, reason);

            new AuditLogDAO().log(userId, tutorName, "REVIEW_REPORTED",
                    "ratingId=" + ratingId + " by tutor " + tutorName + " (awaiting admin review)");
            try {
                NotificationDAO notify = new NotificationDAO();
                for (int adminId : dao.getAdminUserIds()) {
                    notify.create(adminId, tutorName + " reported a review written by " + r.studentName
                            + ". Please review it.", "/admin-reviews.jsp");
                }
            } catch (SQLException ignored) {
                // report already saved
            }
            response.sendRedirect(base + "?reviewreported=true");
        } catch (IllegalStateException e) {
            response.sendRedirect(base + "?reviewerror=" + e.getMessage());
        } catch (SQLException e) {
            response.sendRedirect(base + "?reviewerror=server");
        }
    }

    private void resolve(HttpServletRequest request, HttpServletResponse response, HttpSession session, boolean remove)
            throws IOException {
        String base = request.getContextPath() + "/admin-reviews.jsp";
        int adminId = (int) session.getAttribute("userId");
        String adminName = (String) session.getAttribute("name");
        try {
            int flagId = Integer.parseInt(request.getParameter("flagId"));
            ReviewDAO dao = new ReviewDAO();
            ReviewDAO.Flag f = remove ? dao.remove(flagId, adminId) : dao.keep(flagId, adminId);

            new AuditLogDAO().log(adminId, adminName, remove ? "REVIEW_REMOVED" : "REVIEW_KEPT",
                    "flagId=" + flagId + " ratingId=" + f.ratingId + " tutor=" + f.tutorName + " student=" + f.studentName);

            try {
                NotificationDAO notify = new NotificationDAO();
                if (remove) {
                    notify.create(f.tutorUserId, "The review you reported was removed by an admin. Your average rating was updated.",
                            "/tutor-reviews.jsp");
                    notify.create(f.studentUserId, "Your review of " + f.tutorName
                            + " was removed by an admin after it was reported.", "/notifications.jsp");
                } else {
                    notify.create(f.tutorUserId, "An admin reviewed your report and decided the review stays.",
                            "/tutor-reviews.jsp");
                }
            } catch (SQLException ignored) {
            }
            response.sendRedirect(base + (remove ? "?removed=true" : "?kept=true"));
        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?error=invalid");
        } catch (IllegalStateException e) {
            response.sendRedirect(base + "?error=" + e.getMessage());
        } catch (SQLException e) {
            response.sendRedirect(base + "?error=server");
        }
    }
}