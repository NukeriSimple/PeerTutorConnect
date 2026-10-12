package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AuditLogDAO;
import com.peertutorconnect.dao.AvailabilityDAO;
import com.peertutorconnect.dao.NotificationDAO;
import com.peertutorconnect.dao.SubscriptionDAO;
import com.peertutorconnect.dao.TutorDAO;
import com.peertutorconnect.util.EmailUtil;
import com.peertutorconnect.util.FileStorageUtil;
import com.peertutorconnect.dao.UserDAO;
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
 * Tutor subscription.
 *  POST /tutor-subscription   (tutor): upload proof of the monthly payment
 *  POST /admin-subscriptions  (admin): action=approve|reject
 *  GET  /subscription-proof?paymentId=N : view a proof (the tutor who uploaded it, or an admin)
 */
@WebServlet(name = "SubscriptionServlet",
        urlPatterns = {"/tutor-subscription", "/admin-subscriptions", "/subscription-proof"})
@MultipartConfig(
        fileSizeThreshold = 1024 * 1024,
        maxFileSize = 1024 * 1024 * 6,
        maxRequestSize = 1024 * 1024 * 7
)
public class SubscriptionServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("role") == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }
        String role = (String) session.getAttribute("role");
        String path = request.getServletPath();

        if ("/tutor-subscription".equals(path) && "TUTOR".equals(role)) {
            handleTutorUpload(request, response, session);
        } else if ("/admin-subscriptions".equals(path) && "ADMIN".equals(role)) {
            handleAdminDecision(request, response, session);
        } else {
            response.sendError(HttpServletResponse.SC_FORBIDDEN);
        }
    }

    // ---------------- tutor uploads proof ----------------
    private void handleTutorUpload(HttpServletRequest request, HttpServletResponse response, HttpSession session)
            throws IOException, ServletException {

        String base = request.getContextPath() + "/tutor-subscription.jsp";
        int userId = (int) session.getAttribute("userId");
        String tutorName = (String) session.getAttribute("name");

        Part proof = request.getPart("proof");
        if (proof == null || proof.getSize() == 0) {
            response.sendRedirect(base + "?error=nofile");
            return;
        }
        try {
            FileStorageUtil.validate(proof);
        } catch (IllegalArgumentException e) {
            response.sendRedirect(base + "?error=badfile");
            return;
        }

        try {
            Integer tutorId = new AvailabilityDAO().getTutorIdForUser(userId);
            if (tutorId == null || !new TutorDAO().isVerified(tutorId)) {
                response.sendRedirect(base + "?error=notallowed");
                return;
            }

            String saved = FileStorageUtil.saveFile(proof, "subscription_" + tutorId);
            String period;
            try {
                period = new SubscriptionDAO().submit(tutorId, userId, tutorName, saved);
            } catch (IllegalStateException e) {
                response.sendRedirect(base + "?error=" + e.getMessage());
                return;
            }

            new AuditLogDAO().log(userId, tutorName, "SUBSCRIPTION_PROOF_SUBMITTED", "tutorId=" + tutorId + " period=" + period);

            try {
                NotificationDAO notify = new NotificationDAO();
                for (int adminId : new SubscriptionDAO().getAdminUserIds()) {
                    notify.create(adminId, tutorName + " uploaded proof of the " + SubscriptionDAO.formatFee()
                            + " subscription for " + SubscriptionDAO.prettyPeriod(period) + ".", "/admin-subscriptions.jsp");
                }
            } catch (SQLException ignored) {
                // upload already saved
            }
            response.sendRedirect(base + "?submitted=true");

        } catch (SQLException e) {
            response.sendRedirect(base + "?error=server");
        }
    }

    // ---------------- admin approves / rejects ----------------
    private void handleAdminDecision(HttpServletRequest request, HttpServletResponse response, HttpSession session)
            throws IOException {

        String base = request.getContextPath() + "/admin-subscriptions.jsp";
        int adminId = (int) session.getAttribute("userId");
        String adminName = (String) session.getAttribute("name");
        String action = request.getParameter("action");

        int paymentId;
        try {
            paymentId = Integer.parseInt(request.getParameter("paymentId"));
        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?error=invalid");
            return;
        }

        SubscriptionDAO dao = new SubscriptionDAO();
        NotificationDAO notify = new NotificationDAO();
        try {
            if ("approve".equals(action)) {
                SubscriptionDAO.Payment p = dao.approve(paymentId, adminId);
                new AuditLogDAO().log(adminId, adminName, "SUBSCRIPTION_APPROVED",
                        "paymentId=" + paymentId + " tutorId=" + p.tutorId + " period=" + p.period);

                String msg = "Your " + SubscriptionDAO.formatFee() + " payment for " + SubscriptionDAO.prettyPeriod(p.period)
                        + " was approved.";
                boolean frozen = dao.isFrozen(p.tutorId);
                msg += frozen
                        ? " Your account is still frozen because an earlier month is unpaid. Please pay the next month too."
                        : " Your account is active.";
                notify.create(p.tutorUserId, msg, "/tutor-subscription.jsp");
                UserDAO.BasicInfo info = new UserDAO().getBasicInfo(p.tutorUserId);
                if (info != null) {
                    EmailUtil.sendSimpleEmail(info.email, "Subscription payment approved",
                            "Hi " + info.name + ",\n\n" + msg + "\n\n- The PeerTutorConnect Team");
                }
                response.sendRedirect(base + "?approved=true");

            } else if ("reject".equals(action)) {
                String reason = request.getParameter("reason");
                reason = (reason == null) ? "" : reason.trim();
                if (reason.length() < 3) {
                    response.sendRedirect(base + "?error=noreason");
                    return;
                }
                if (reason.length() > 300) reason = reason.substring(0, 300);

                SubscriptionDAO.Payment p = dao.reject(paymentId, adminId, reason);
                new AuditLogDAO().log(adminId, adminName, "SUBSCRIPTION_REJECTED",
                        "paymentId=" + paymentId + " tutorId=" + p.tutorId + " reason=" + reason);

                String msg = "Your subscription payment for " + SubscriptionDAO.prettyPeriod(p.period)
                        + " was rejected: " + reason + ". Please upload a valid proof of payment.";
                notify.create(p.tutorUserId, msg, "/tutor-subscription.jsp");
                UserDAO.BasicInfo info = new UserDAO().getBasicInfo(p.tutorUserId);
                if (info != null) {
                    EmailUtil.sendSimpleEmail(info.email, "Subscription payment rejected",
                            "Hi " + info.name + ",\n\n" + msg + "\n\n- The PeerTutorConnect Team");
                }
                response.sendRedirect(base + "?rejected=true");

            } else {
                response.sendRedirect(base + "?error=invalid");
            }
        } catch (IllegalStateException e) {
            response.sendRedirect(base + "?error=" + e.getMessage());
        } catch (SQLException e) {
            response.sendRedirect(base + "?error=server");
        }
    }

    // ---------------- view a proof ----------------
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("role") == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }
        if (!"/subscription-proof".equals(request.getServletPath())) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        String role = (String) session.getAttribute("role");
        int userId = (int) session.getAttribute("userId");

        int paymentId;
        try {
            paymentId = Integer.parseInt(request.getParameter("paymentId"));
        } catch (NumberFormatException e) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST);
            return;
        }

        try {
            String[] info = new SubscriptionDAO().getProofInfo(paymentId);
            if (info == null) {
                response.sendError(HttpServletResponse.SC_NOT_FOUND);
                return;
            }
            boolean allowed = "ADMIN".equals(role)
                    || ("TUTOR".equals(role) && Integer.parseInt(info[0]) == userId);
            if (!allowed) {
                response.sendError(HttpServletResponse.SC_FORBIDDEN);
                return;
            }

            File file = new File(info[1]);
            if (!file.exists()) {
                response.sendError(HttpServletResponse.SC_NOT_FOUND);
                return;
            }
            String contentType = getServletContext().getMimeType(file.getName());
            if (contentType == null) contentType = "application/octet-stream";
            response.setContentType(contentType);
            response.setHeader("Content-Disposition", "inline; filename=\"" + file.getName() + "\"");
            response.setHeader("X-Content-Type-Options", "nosniff");

            try (InputStream in = new FileInputStream(file); OutputStream out = response.getOutputStream()) {
                byte[] buffer = new byte[4096];
                int n;
                while ((n = in.read(buffer)) != -1) {
                    out.write(buffer, 0, n);
                }
            }
        } catch (SQLException e) {
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }
}