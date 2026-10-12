package com.peertutorconnect.controller;

import com.peertutorconnect.dao.AvailabilityDAO;
import com.peertutorconnect.dao.DocumentDAO;
import com.peertutorconnect.dao.TutorDAO;
import com.peertutorconnect.util.FileStorageUtil;
import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.Part;

@WebServlet(name = "CompleteTutorApplicationServlet", urlPatterns = {"/complete-tutor-application"})
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,
    maxFileSize = 1024 * 1024 * 10,
    maxRequestSize = 1024 * 1024 * 15
)
public class CompleteTutorApplicationServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || !"TUTOR".equals(session.getAttribute("role"))) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        int userId = (int) session.getAttribute("userId");

        try {
            AvailabilityDAO availDAO = new AvailabilityDAO();
            Integer tutorId = availDAO.getTutorIdForUser(userId);

            if (tutorId == null) {
                response.sendRedirect(request.getContextPath() + "/login.jsp");
                return;
            }

            TutorDAO tutorDAO = new TutorDAO();
            if (tutorDAO.isApplicationComplete(tutorId)) {
                response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp");
                return;
            }

            String hourlyRateStr = request.getParameter("hourlyRate");
            String bio = request.getParameter("bio");

            if (hourlyRateStr == null || hourlyRateStr.trim().isEmpty()) {
                request.setAttribute("error", "Please enter your hourly rate.");
                request.getRequestDispatcher("/complete-tutor-application.jsp").forward(request, response);
                return;
            }

            Part idPart = request.getPart("idDocument");
            Part transcriptPart = request.getPart("transcriptDocument");

            if (idPart == null || idPart.getSize() == 0 ||
                transcriptPart == null || transcriptPart.getSize() == 0) {
                request.setAttribute("error", "Please upload both your student ID and academic transcript.");
                request.getRequestDispatcher("/complete-tutor-application.jsp").forward(request, response);
                return;
            }

            double hourlyRate;
            try {
                hourlyRate = Double.parseDouble(hourlyRateStr);
            } catch (NumberFormatException e) {
                request.setAttribute("error", "Please enter a valid hourly rate.");
                request.getRequestDispatcher("/complete-tutor-application.jsp").forward(request, response);
                return;
            }

            String[] subjectIdStrings = request.getParameterValues("subjectIds");
            int[] subjectIds = new int[0];
            if (subjectIdStrings != null) {
                subjectIds = new int[subjectIdStrings.length];
                for (int i = 0; i < subjectIdStrings.length; i++) {
                    subjectIds[i] = Integer.parseInt(subjectIdStrings[i]);
                }
            }

            // Validate uploads BEFORE writing anything, so a bad file leaves no half-finished application.
            FileStorageUtil.validate(idPart);
            FileStorageUtil.validate(transcriptPart);

            tutorDAO.completeApplication(tutorId, hourlyRate, bio, subjectIds);

            DocumentDAO documentDAO = new DocumentDAO();
            String idPath = FileStorageUtil.saveFile(idPart, "id_" + tutorId);
            if (idPath != null) {
                documentDAO.saveDocument(tutorId, "STUDENT_ID", idPath);
            }
            String transcriptPath = FileStorageUtil.saveFile(transcriptPart, "transcript_" + tutorId);
            if (transcriptPath != null) {
                documentDAO.saveDocument(tutorId, "TRANSCRIPT", transcriptPath);
            }

            response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp?applicationSubmitted=true");

        } catch (SQLException e) {
            request.setAttribute("error", "Something went wrong. Please try again.");
            request.getRequestDispatcher("/complete-tutor-application.jsp").forward(request, response);
        } catch (NumberFormatException e) {
            request.setAttribute("error", "Please enter valid numbers.");
            request.getRequestDispatcher("/complete-tutor-application.jsp").forward(request, response);
        } catch (IllegalArgumentException e) {
            // Upload validation failure (type/size/content): message is safe to show.
            request.setAttribute("error", e.getMessage());
            request.getRequestDispatcher("/complete-tutor-application.jsp").forward(request, response);
        }
    }
}