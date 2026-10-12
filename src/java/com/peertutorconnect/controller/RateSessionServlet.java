package com.peertutorconnect.controller;

import com.peertutorconnect.dao.BookingDAO;
import com.peertutorconnect.dao.RatingDAO;
import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "RateSessionServlet", urlPatterns = {"/rate-session"})
public class RateSessionServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || !"STUDENT".equals(session.getAttribute("role"))) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        int userId = (int) session.getAttribute("userId");
        int bookingId = Integer.parseInt(request.getParameter("bookingId"));
        String base = request.getContextPath() + "/my-sessions.jsp";

        int stars;
        try {
            stars = Integer.parseInt(request.getParameter("stars"));
        } catch (NumberFormatException e) {
            response.sendRedirect(base + "?rateerror=badstars");
            return;
        }

        // A written review is required with every rating.
        String comment = request.getParameter("comment");
        comment = (comment == null) ? "" : comment.trim();
        if (comment.isEmpty()) {
            response.sendRedirect(base + "?rateerror=noreview");
            return;
        }
        if (comment.length() > 500) {
            comment = comment.substring(0, 500);
        }

        try {
            BookingDAO bookingDAO = new BookingDAO();
            Integer studentId = bookingDAO.getStudentIdForUser(userId);

            if (studentId == null) {
                response.sendRedirect(base + "?rateerror=server");
                return;
            }

            RatingDAO ratingDAO = new RatingDAO();

            if (!ratingDAO.canRate(bookingId, studentId)) {
                response.sendRedirect(base + "?rateerror=cannotrate");
                return;
            }

            if (stars < 1 || stars > 5) {
                response.sendRedirect(base + "?rateerror=badstars");
                return;
            }

            ratingDAO.submitRating(bookingId, studentId, stars, comment);
            response.sendRedirect(base + "?rated=true");

        } catch (SQLException e) {
            response.sendRedirect(base + "?rateerror=server");
        }
    }
}