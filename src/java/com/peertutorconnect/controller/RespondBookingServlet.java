package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AuditLogDAO;
import com.peertutorconnect.dao.AvailabilityDAO;
import com.peertutorconnect.dao.BookingDAO;
import com.peertutorconnect.dao.NotificationDAO;
import com.peertutorconnect.dao.TutorDAO;
import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "RespondBookingServlet", urlPatterns = {"/respond-booking"})
public class RespondBookingServlet extends HttpServlet {

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
        int bookingId = Integer.parseInt(request.getParameter("bookingId"));
        String action = request.getParameter("action");
        String declineReason = request.getParameter("declineReason");

        try {
            AvailabilityDAO availDAO = new AvailabilityDAO();
            Integer tutorId = availDAO.getTutorIdForUser(userId);

            if (tutorId == null) {
                response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?error=notutor");
                return;
            }

            BookingDAO bookingDAO = new BookingDAO();
            NotificationDAO notifyDAO = new NotificationDAO();
            AuditLogDAO auditDAO = new AuditLogDAO();
            Integer studentUserId = bookingDAO.getStudentUserIdForBooking(bookingId);

            if ("accept".equals(action)) {
                // Students pay into the tutor's PaySharp, so it must be set before approving.
                String paysharp = new TutorDAO().getPaysharpDetails(tutorId);
                if (paysharp == null || paysharp.trim().isEmpty()) {
                    response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?error=nopaysharp");
                    return;
                }
                bookingDAO.respondToBooking(bookingId, tutorId, true, null);
                auditDAO.log(userId, tutorName, "BOOKING_ACCEPTED", "Accepted bookingId=" + bookingId);
                if (studentUserId != null) {
                    notifyDAO.create(studentUserId,
                        tutorName + " approved your booking request. Please upload your proof of payment to confirm it.",
                        "/my-sessions.jsp");
                }
            } else if ("send-link".equals(action)) {
                // Tutor has seen the proof of payment and confirms the booking by sending the Teams link.
                String meetingLink = request.getParameter("meetingLink");
                meetingLink = (meetingLink == null) ? "" : meetingLink.trim();
                if (meetingLink.isEmpty()) {
                    response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?error=missinglink");
                    return;
                }
                if (!bookingDAO.confirmWithLink(bookingId, tutorId, meetingLink)) {
                    response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?error=notconfirmable");
                    return;
                }
                auditDAO.log(userId, tutorName, "BOOKING_CONFIRMED", "Confirmed bookingId=" + bookingId + " with meeting link");
                if (studentUserId != null) {
                    notifyDAO.create(studentUserId,
                        "Your booking with " + tutorName + " is confirmed. Your meeting link is ready.",
                        "/my-sessions.jsp");
                }
            } else if ("decline".equals(action)) {
                bookingDAO.respondToBooking(bookingId, tutorId, false, declineReason);
                auditDAO.log(userId, tutorName, "BOOKING_DECLINED", "Declined bookingId=" + bookingId);
                if (studentUserId != null) {
                    notifyDAO.create(studentUserId, "Your booking with " + tutorName + " was declined", "/student-dashboard.jsp");
                }
            } else if ("complete".equals(action)) {
                // A session can only be marked completed once it has ended, so a tutor
                // cannot close it before the student is able to report a no-show.
                BookingDAO.BookingRow row = bookingDAO.getBookingById(bookingId);
                boolean ended = false;
                if (row != null && row.tutorId == tutorId) {
                    try {
                        ended = !java.time.LocalDateTime.of(
                                java.time.LocalDate.parse(row.bookingDate),
                                java.time.LocalTime.parse(row.endTime))
                                .isAfter(java.time.LocalDateTime.now());
                    } catch (Exception ex) {
                        ended = false;
                    }
                }
                if (!ended) {
                    response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?error=toosoon");
                    return;
                }
                bookingDAO.markCompleted(bookingId, tutorId);
                auditDAO.log(userId, tutorName, "SESSION_COMPLETED", "Marked bookingId=" + bookingId + " completed");
                if (studentUserId != null) {
                    notifyDAO.create(studentUserId, "Your session with " + tutorName + " is complete. Leave a rating!", "/student-dashboard.jsp");
                }
            }

            response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?success=true");

        } catch (SQLException e) {
            response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?error=db");
        }
    }
}