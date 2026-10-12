package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AuditLogDAO;
import com.peertutorconnect.dao.BookingDAO;
import com.peertutorconnect.dao.NotificationDAO;
import com.peertutorconnect.dao.UserDAO;
import com.peertutorconnect.util.EmailUtil;
import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "BookingServlet", urlPatterns = {"/book"})
public class BookingServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || !"STUDENT".equals(session.getAttribute("role"))) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        if ("cancel".equals(request.getParameter("action"))) {
            handleCancel(request, response, session);
            return;
        }

        int userId = (int) session.getAttribute("userId");
        String studentName = (String) session.getAttribute("name");
        int tutorId = Integer.parseInt(request.getParameter("tutorId"));
        String backUrl = request.getContextPath() + "/book-session.jsp?tutorId=" + tutorId;

        // One or more slot checkboxes, all named "availabilityId".
        String[] slotParams = request.getParameterValues("availabilityId");
        int[] availabilityIds;
        try {
            availabilityIds = new int[slotParams == null ? 0 : slotParams.length];
            for (int i = 0; i < availabilityIds.length; i++) {
                availabilityIds[i] = Integer.parseInt(slotParams[i].trim());
            }
        } catch (NumberFormatException e) {
            response.sendRedirect(backUrl + "&error=noslots");
            return;
        }
        if (availabilityIds.length == 0) {
            response.sendRedirect(backUrl + "&error=noslots");
            return;
        }

        // What the student needs help with - required, so the tutor can decide.
        String description = request.getParameter("description");
        description = (description == null) ? "" : description.trim();
        if (description.isEmpty()) {
            response.sendRedirect(backUrl + "&error=nodescription");
            return;
        }
        if (description.length() > 1000) {
            description = description.substring(0, 1000);
        }

        BookingDAO bookingDAO = new BookingDAO();
        AuditLogDAO auditDAO = new AuditLogDAO();

        try {
            Integer studentId = bookingDAO.getStudentIdForUser(userId);
            if (studentId == null) {
                response.sendRedirect(request.getContextPath() + "/book-session.jsp?tutorId=" + tutorId + "&error=nostudent");
                return;
            }

            if (new com.peertutorconnect.dao.SubscriptionDAO().isFrozen(tutorId)) {
                response.sendRedirect(request.getContextPath() + "/search-tutors.jsp");
                return;
            }

            int newBookingId = bookingDAO.createBooking(studentId, tutorId, availabilityIds, description);

            auditDAO.log(userId, studentName, "BOOKING_CREATED", "Booked tutorId=" + tutorId + " slots=" + java.util.Arrays.toString(availabilityIds));

            Integer tutorUserId = bookingDAO.getUserIdForTutorId(tutorId);
            if (tutorUserId != null) {
                new NotificationDAO().create(tutorUserId,
                    "New booking request from " + studentName,
                    "/tutor-dashboard.jsp");
            }

            sendBookingConfirmationEmails(newBookingId, userId, tutorUserId, studentName);

            response.sendRedirect(request.getContextPath() + "/book-session.jsp?tutorId=" + tutorId + "&success=true");

        } catch (IllegalStateException e) {
            // e.g. "wholehour", "notconsecutive", "toomany", "wrongtutor"
            response.sendRedirect(request.getContextPath() + "/book-session.jsp?tutorId=" + tutorId + "&error=" + e.getMessage());
        } catch (SQLException e) {
            response.sendRedirect(request.getContextPath() + "/book-session.jsp?tutorId=" + tutorId + "&error=slottaken");
        }
    }

    /**
     * Emails both parties once a booking is created. Looks up the exact
     * booking row by its ID (returned from createBooking), rather than
     * assuming it's "the most recent" in a date-sorted list — a student
     * with an existing later-dated booking would otherwise get the wrong
     * session's details in their confirmation email. A failure here never
     * fails the booking itself — EmailUtil already logs and swallows its
     * own errors.
     */
    private void sendBookingConfirmationEmails(int bookingId, int studentUserId, Integer tutorUserId, String studentName) {
        try {
            UserDAO userDAO = new UserDAO();
            BookingDAO bookingDAO = new BookingDAO();

            UserDAO.BasicInfo studentInfo = userDAO.getBasicInfo(studentUserId);
            UserDAO.BasicInfo tutorInfo = (tutorUserId != null) ? userDAO.getBasicInfo(tutorUserId) : null;

            BookingDAO.BookingRow created = bookingDAO.getBookingById(bookingId);
            if (created == null || studentInfo == null || tutorInfo == null) {
                return;
            }

            EmailUtil.sendBookingConfirmationEmail(
                    studentInfo.email, studentInfo.name, tutorInfo.name,
                    created.bookingDate, created.startTime, created.endTime, false);

            EmailUtil.sendBookingConfirmationEmail(
                    tutorInfo.email, tutorInfo.name, studentName,
                    created.bookingDate, created.startTime, created.endTime, true);

        } catch (SQLException e) {
            // Booking already succeeded; a lookup failure here should not surface to the user.
        }
    }

    private void handleCancel(HttpServletRequest request, HttpServletResponse response, HttpSession session)
            throws IOException {

        String base = request.getContextPath() + "/my-sessions.jsp";
        int userId = (int) session.getAttribute("userId");
        String studentName = (String) session.getAttribute("name");

        int bookingId;
        try {
            bookingId = Integer.parseInt(request.getParameter("bookingId"));
        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?cancelerror=invalid");
            return;
        }

        // PaySharp account the student's refund should be sent to (required when they already paid;
        // the DAO enforces that and answers "norefund").
        String refundPaysharp = request.getParameter("refundPaysharp");
        refundPaysharp = (refundPaysharp == null) ? "" : refundPaysharp.trim();
        if (refundPaysharp.length() > 255) {
            refundPaysharp = refundPaysharp.substring(0, 255);
        }

        String reason = request.getParameter("reason");
        reason = (reason == null) ? "" : reason.trim();
        if (reason.isEmpty()) {
            response.sendRedirect(base + "?cancelerror=noreason");
            return;
        }
        if (reason.length() > 500) {
            reason = reason.substring(0, 500);
        }

        BookingDAO bookingDAO = new BookingDAO();
        AuditLogDAO auditDAO = new AuditLogDAO();

        try {
            Integer studentId = bookingDAO.getStudentIdForUser(userId);
            if (studentId == null) {
                response.sendRedirect(base + "?cancelerror=invalid");
                return;
            }

            BookingDAO.BookingRow cancelled = bookingDAO.cancelBookingByStudent(bookingId, studentId, reason, refundPaysharp);
            String feeText = String.format(java.util.Locale.US, "%.2f", cancelled.cancellationFee);

            auditDAO.log(userId, studentName, "BOOKING_CANCELLED",
                    "Cancelled bookingId=" + bookingId + " with tutorId=" + cancelled.tutorId
                    + (cancelled.cancellationFee > 0 ? " (fee R" + feeText + ")" : " (no fee)")
                    + " reason=" + reason);

            // Notify the tutor. A notification failure must not make the cancellation look failed.
            try {
                Integer tutorUserId = bookingDAO.getUserIdForTutorId(cancelled.tutorId);
                if (tutorUserId != null) {
                    String time = (cancelled.startTime != null && cancelled.startTime.length() >= 5)
                            ? cancelled.startTime.substring(0, 5) : cancelled.startTime;
                    new NotificationDAO().create(tutorUserId,
                        studentName + " cancelled their session on " + cancelled.bookingDate + " at " + time
                        + ". Reason: " + reason
                        + (cancelled.cancellationFee > 0 ? " (cancellation fee R" + feeText + "). Please refund R"
                            + String.format(java.util.Locale.US, "%.2f", cancelled.refundAmount)
                            + " to the student's PaySharp: " + cancelled.refundPaysharp : ""),
                        "/tutor-dashboard.jsp");
                }
            } catch (SQLException ignored) {
                // cancellation already committed
            }

            response.sendRedirect(base + "?cancelled=true&fee=" + feeText);

        } catch (IllegalStateException e) {
            // Business-rule failures from the DAO: notfound, notcancellable, started, tooclose, norefund
            response.sendRedirect(base + "?cancelerror=" + e.getMessage());
        } catch (SQLException e) {
            response.sendRedirect(base + "?cancelerror=server");
        }
    }
}