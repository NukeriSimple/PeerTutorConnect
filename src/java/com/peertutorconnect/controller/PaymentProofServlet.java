package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AuditLogDAO;
import com.peertutorconnect.dao.BookingDAO;
import com.peertutorconnect.dao.NotificationDAO;
import com.peertutorconnect.util.FileStorageUtil;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.Part;

/**
 * Proof of payment for an approved booking.
 *  POST (student): upload the file; booking moves AWAITING_PAYMENT -> PAYMENT_SUBMITTED.
 *  GET  ?bookingId=N: view the proof - only the student who uploaded it,
 *       the booking's tutor, or an admin.
 */
@WebServlet(name = "PaymentProofServlet", urlPatterns = {"/payment-proof"})
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,
    maxFileSize = 1024 * 1024 * 6,
    maxRequestSize = 1024 * 1024 * 7
)
public class PaymentProofServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || !"STUDENT".equals(session.getAttribute("role"))) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String base = request.getContextPath() + "/my-sessions.jsp";
        int userId = (int) session.getAttribute("userId");
        String studentName = (String) session.getAttribute("name");

        int bookingId;
        try {
            bookingId = Integer.parseInt(request.getParameter("bookingId"));
        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?payerror=invalid");
            return;
        }

        Part proofPart = request.getPart("proof");
        if (proofPart == null || proofPart.getSize() == 0) {
            response.sendRedirect(base + "?payerror=nofile");
            return;
        }

        try {
            FileStorageUtil.validate(proofPart);
        } catch (IllegalArgumentException e) {
            response.sendRedirect(base + "?payerror=badfile");
            return;
        }

        try {
            BookingDAO bookingDAO = new BookingDAO();
            Integer studentId = bookingDAO.getStudentIdForUser(userId);
            if (studentId == null) {
                response.sendRedirect(base + "?payerror=invalid");
                return;
            }

            String path = FileStorageUtil.saveFile(proofPart, "payment_" + bookingId);
            if (!bookingDAO.submitPaymentProof(bookingId, studentId, path)) {
                response.sendRedirect(base + "?payerror=notallowed");
                return;
            }

            new AuditLogDAO().log(userId, studentName, "PAYMENT_PROOF_SUBMITTED", "bookingId=" + bookingId);

            // Tell the tutor to check the proof and send the Teams link.
            try {
                BookingDAO.BookingRow row = bookingDAO.getBookingById(bookingId);
                Integer tutorUserId = (row == null) ? null : bookingDAO.getUserIdForTutorId(row.tutorId);
                if (tutorUserId != null) {
                    new NotificationDAO().create(tutorUserId,
                        studentName + " uploaded proof of payment. Review it and send the Teams link to confirm the booking.",
                        "/tutor-dashboard.jsp");
                }
            } catch (SQLException ignored) {
                // upload already saved
            }

            response.sendRedirect(base + "?paid=true");

        } catch (SQLException e) {
            response.sendRedirect(base + "?payerror=server");
        }
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("role") == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String role = (String) session.getAttribute("role");
        int userId = (int) session.getAttribute("userId");

        int bookingId;
        try {
            bookingId = Integer.parseInt(request.getParameter("bookingId"));
        } catch (NumberFormatException e) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST);
            return;
        }

        try {
            String[] info = new BookingDAO().getPaymentProofInfo(bookingId);
            if (info == null) {
                response.sendError(HttpServletResponse.SC_NOT_FOUND);
                return;
            }

            boolean allowed = "ADMIN".equals(role)
                    || ("STUDENT".equals(role) && Integer.parseInt(info[0]) == userId)
                    || ("TUTOR".equals(role) && Integer.parseInt(info[1]) == userId);
            if (!allowed) {
                response.sendError(HttpServletResponse.SC_FORBIDDEN);
                return;
            }

            File file = new File(info[2]);
            if (!file.exists()) {
                response.sendError(HttpServletResponse.SC_NOT_FOUND);
                return;
            }

            String contentType = getServletContext().getMimeType(file.getName());
            if (contentType == null) {
                contentType = "application/octet-stream";
            }
            response.setContentType(contentType);
            response.setHeader("Content-Disposition", "inline; filename=\"" + file.getName() + "\"");
            response.setHeader("X-Content-Type-Options", "nosniff");

            try (InputStream in = new FileInputStream(file);
                 OutputStream out = response.getOutputStream()) {
                byte[] buffer = new byte[4096];
                int bytesRead;
                while ((bytesRead = in.read(buffer)) != -1) {
                    out.write(buffer, 0, bytesRead);
                }
            }

        } catch (SQLException e) {
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }
}