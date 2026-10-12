package com.peertutorconnect.controller;

import com.peertutorconnect.dao.DocumentDAO;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "DocumentServlet", urlPatterns = {"/document"})
public class DocumentServlet extends HttpServlet {

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

        int documentId;
        try {
            documentId = Integer.parseInt(request.getParameter("id"));
        } catch (NumberFormatException e) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST);
            return;
        }

        try {
            DocumentDAO documentDAO = new DocumentDAO();
            DocumentDAO.Document doc = documentDAO.getById(documentId);

            if (doc == null) {
                response.sendError(HttpServletResponse.SC_NOT_FOUND);
                return;
            }

            boolean isAdmin = "ADMIN".equals(role);
            boolean isOwner = false;
            if ("TUTOR".equals(role)) {
                Integer ownerUserId = documentDAO.getUserIdForTutor(doc.tutorId);
                isOwner = ownerUserId != null && ownerUserId == userId;
            }

            if (!isAdmin && !isOwner) {
                response.sendError(HttpServletResponse.SC_FORBIDDEN);
                return;
            }

            File file = new File(doc.fileUrl);
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