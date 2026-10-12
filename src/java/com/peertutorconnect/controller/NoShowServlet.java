package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AuditLogDAO;
import com.peertutorconnect.dao.AvailabilityDAO;
import com.peertutorconnect.dao.BookingDAO;
import com.peertutorconnect.dao.NoShowDAO;
import com.peertutorconnect.dao.NotificationDAO;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Locale;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

/**
 * action=flag-student   (TUTOR)   tutor reports a student who did not attend -> waits for an admin
 * action=tutor-absent   (STUDENT) student reports a tutor who did not attend (stars + review required) -> waits for an admin
 * action=strike         (ADMIN)   admin confirms a pending report -> strike (3 strikes = account removed)
 * action=dismiss        (ADMIN)   admin rejects a pending report -> no strike
 * action=revoke         (ADMIN)   admin undoes a strike that was already issued
 */
@WebServlet(name = "NoShowServlet", urlPatterns = {"/no-show"})
public class NoShowServlet extends HttpServlet {

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

        switch (action) {
            case "flag-student":
                if ("TUTOR".equals(role)) { flagStudent(request, response, session); return; }
                break;
            case "tutor-absent":
                if ("STUDENT".equals(role)) { tutorAbsent(request, response, session); return; }
                break;
            case "strike":
                if ("ADMIN".equals(role)) { strike(request, response, session); return; }
                break;
            case "dismiss":
                if ("ADMIN".equals(role)) { dismiss(request, response, session); return; }
                break;
            case "revoke":
                if ("ADMIN".equals(role)) { revoke(request, response, session); return; }
                break;
            default:
                break;
        }
        response.sendError(HttpServletResponse.SC_FORBIDDEN, "Not allowed.");
    }

    /** Text sent to someone who has just received a strike. Warns clearly at the second one. */
    private static String strikeMessage(int strikes) {
        String base = "You received a strike for missing a session (" + strikes + " of " + NoShowDAO.MAX_STRIKES + ").";
        if (strikes == NoShowDAO.MAX_STRIKES - 1) {
            return base + " FINAL WARNING: one more strike and your account will be removed.";
        }
        return base + " At " + NoShowDAO.MAX_STRIKES + " strikes your account is removed.";
    }

    // ---------------- tutor reports a student (admin decides) ----------------
    private void flagStudent(HttpServletRequest request, HttpServletResponse response, HttpSession session)
            throws IOException {
        String base = request.getContextPath() + "/tutor-dashboard.jsp";
        int userId = (int) session.getAttribute("userId");
        String tutorName = (String) session.getAttribute("name");

        int bookingId;
        try {
            bookingId = Integer.parseInt(request.getParameter("bookingId"));
        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?noshowerror=invalid");
            return;
        }

        String note = request.getParameter("note");
        note = (note == null) ? "" : note.trim();
        if (note.length() > 500) note = note.substring(0, 500);

        try {
            Integer tutorId = new AvailabilityDAO().getTutorIdForUser(userId);
            if (tutorId == null) {
                response.sendRedirect(base + "?noshowerror=invalid");
                return;
            }

            NoShowDAO dao = new NoShowDAO();
            NoShowDAO.FlagResult r = dao.flagStudentNoShow(bookingId, tutorId, userId, note);

            new AuditLogDAO().log(userId, tutorName, "NO_SHOW_REPORTED",
                    "bookingId=" + bookingId + " student=" + r.studentName + " (awaiting admin review)");

            try {
                NotificationDAO notify = new NotificationDAO();
                notify.create(r.studentUserId,
                        tutorName + " reported that you did not attend your session (booking #" + bookingId
                        + "). An admin will review the report. No strike has been given yet.",
                        "/my-sessions.jsp");
                for (int adminId : dao.getAdminUserIds()) {
                    notify.create(adminId,
                            tutorName + " reported that student " + r.studentName + " did not attend (booking #"
                            + bookingId + "). Please review it.",
                            "/admin-strikes.jsp");
                }
            } catch (SQLException ignored) {
                // report already saved
            }

            response.sendRedirect(base + "?noshowreported=true");

        } catch (IllegalStateException e) {
            response.sendRedirect(base + "?noshowerror=" + e.getMessage());
        } catch (SQLException e) {
            response.sendRedirect(base + "?noshowerror=server");
        }
    }

    // ---------------- student reports a tutor (admin decides) ----------------
    private void tutorAbsent(HttpServletRequest request, HttpServletResponse response, HttpSession session)
            throws IOException {
        String base = request.getContextPath() + "/my-sessions.jsp";
        int userId = (int) session.getAttribute("userId");
        String studentName = (String) session.getAttribute("name");

        int bookingId, stars;
        try {
            bookingId = Integer.parseInt(request.getParameter("bookingId"));
            stars = Integer.parseInt(request.getParameter("stars"));
        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?noshowerror=norating");
            return;
        }
        if (stars < 1 || stars > 5) {
            response.sendRedirect(base + "?noshowerror=norating");
            return;
        }

        String review = request.getParameter("review");
        review = (review == null) ? "" : review.trim();
        if (review.isEmpty()) {
            response.sendRedirect(base + "?noshowerror=noreview");
            return;
        }
        if (review.length() > 500) review = review.substring(0, 500);

        try {
            Integer studentId = new BookingDAO().getStudentIdForUser(userId);
            if (studentId == null) {
                response.sendRedirect(base + "?noshowerror=invalid");
                return;
            }

            NoShowDAO dao = new NoShowDAO();
            NoShowDAO.TutorReportResult r = dao.reportTutorNoShow(bookingId, studentId, userId, stars, review);

            new AuditLogDAO().log(userId, studentName, "TUTOR_NO_SHOW_REPORTED",
                    "bookingId=" + bookingId + " tutor=" + r.tutorName + " stars=" + stars + " (awaiting admin review)");

            try {
                NotificationDAO notify = new NotificationDAO();
                notify.create(r.tutorUserId,
                        studentName + " reported that you did not attend a session (booking #" + bookingId
                        + ") and left a review. An admin will review the report.",
                        "/tutor-dashboard.jsp");
                for (int adminId : dao.getAdminUserIds()) {
                    notify.create(adminId,
                            studentName + " reported that tutor " + r.tutorName + " did not attend (booking #" + bookingId
                            + "). If you confirm it, a refund of " + String.format(Locale.US, "R%.2f", r.refundAmount)
                            + " is due to the student.",
                            "/admin-strikes.jsp");
                }
            } catch (SQLException ignored) {
                // report already saved
            }

            response.sendRedirect(base + "?tutorabsent=true");

        } catch (IllegalStateException e) {
            response.sendRedirect(base + "?noshowerror=" + e.getMessage());
        } catch (SQLException e) {
            response.sendRedirect(base + "?noshowerror=server");
        }
    }

    // ---------------- admin ----------------
    private void strike(HttpServletRequest request, HttpServletResponse response, HttpSession session)
            throws IOException {
        String base = request.getContextPath() + "/admin-strikes.jsp";
        int adminId = (int) session.getAttribute("userId");
        String adminName = (String) session.getAttribute("name");

        try {
            int reportId = Integer.parseInt(request.getParameter("reportId"));
            NoShowDAO.StrikeResult r = new NoShowDAO().issueStrike(reportId, adminId);
            String who = "TUTOR".equals(r.role) ? "tutor" : "student";

            new AuditLogDAO().log(adminId, adminName, "STRIKE_ISSUED",
                    "reportId=" + reportId + " " + who + "=" + r.name + " strikes=" + r.strikes
                    + (r.removed ? " ACCOUNT REMOVED" : ""));

            if (r.removed) {
                // The account row is gone after this, so keep the email on record in the audit log.
                new AuditLogDAO().log(adminId, adminName, "ACCOUNT_REMOVED_STRIKES",
                        who + " " + r.name + " <" + r.email + "> removed at " + r.strikes + " strikes");
                response.sendRedirect(base + "?removed=" + who);
                return;
            }
            if (r.removalFailed) {
                response.sendRedirect(base + "?removalfailed=true");
                return;
            }

            try {
                String link = "TUTOR".equals(r.role) ? "/tutor-dashboard.jsp" : "/my-sessions.jsp";
                new NotificationDAO().create(r.userId, strikeMessage(r.strikes), link);
            } catch (SQLException ignored) {
            }

            response.sendRedirect(base + "?struck=" + r.strikes);

        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?error=invalid");
        } catch (IllegalStateException e) {
            response.sendRedirect(base + "?error=" + e.getMessage());
        } catch (SQLException e) {
            response.sendRedirect(base + "?error=server");
        }
    }

    private void dismiss(HttpServletRequest request, HttpServletResponse response, HttpSession session)
            throws IOException {
        String base = request.getContextPath() + "/admin-strikes.jsp";
        int adminId = (int) session.getAttribute("userId");
        String adminName = (String) session.getAttribute("name");
        try {
            int reportId = Integer.parseInt(request.getParameter("reportId"));
            NoShowDAO.DismissResult d = new NoShowDAO().dismiss(reportId, adminId);
            new AuditLogDAO().log(adminId, adminName, "NO_SHOW_DISMISSED", "reportId=" + reportId);

            try {
                NotificationDAO notify = new NotificationDAO();
                notify.create(d.absentUserId,
                        "A no-show report about you was reviewed and dismissed. No strike was given.",
                        "/profile.jsp");
                notify.create(d.reporterUserId,
                        "An admin reviewed your no-show report and dismissed it.",
                        "/notifications.jsp");
            } catch (SQLException ignored) {
            }

            response.sendRedirect(base + "?dismissed=true");
        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?error=invalid");
        } catch (IllegalStateException e) {
            response.sendRedirect(base + "?error=" + e.getMessage());
        } catch (SQLException e) {
            response.sendRedirect(base + "?error=server");
        }
    }

    private void revoke(HttpServletRequest request, HttpServletResponse response, HttpSession session)
            throws IOException {
        String base = request.getContextPath() + "/admin-strikes.jsp";
        int adminId = (int) session.getAttribute("userId");
        String adminName = (String) session.getAttribute("name");
        try {
            int reportId = Integer.parseInt(request.getParameter("reportId"));
            NoShowDAO.RevokeResult r = new NoShowDAO().revokeStrike(reportId, adminId);
            new AuditLogDAO().log(adminId, adminName, "STRIKE_REVOKED",
                    "reportId=" + reportId + " user=" + r.name + " strikes now=" + r.strikes);

            try {
                new NotificationDAO().create(r.userId,
                        "A strike was removed from your account. You now have " + r.strikes + " of "
                        + NoShowDAO.MAX_STRIKES + " strikes.",
                        "/notifications.jsp");
            } catch (SQLException ignored) {
            }

            response.sendRedirect(base + "?revoked=" + r.strikes);
        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?error=invalid");
        } catch (IllegalStateException e) {
            response.sendRedirect(base + "?error=" + e.getMessage());
        } catch (SQLException e) {
            response.sendRedirect(base + "?error=server");
        }
    }
}