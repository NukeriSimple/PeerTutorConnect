package com.peertutorconnect.controller;

import com.peertutorconnect.dao.UserDAO;
import java.io.IOException;
import java.sql.SQLException;
import java.util.regex.Pattern;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import com.peertutorconnect.util.EmailUtil;
import com.peertutorconnect.util.TokenUtil;

@WebServlet(name = "RegisterServlet", urlPatterns = {"/register"})
public class RegisterServlet extends HttpServlet {

    // Server-side validation is the real security boundary — the JSP's
    // client-side checks are just for UX. Never trust the client alone.
    private static final Pattern NAME_PATTERN =
            Pattern.compile("^[A-Za-z]+([ '\\-][A-Za-z]+)+$"); // at least two words, letters only
    private static final Pattern EMAIL_PATTERN =
            Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$");
    private static final Pattern PHONE_PATTERN =
            Pattern.compile("^\\d{10}$");
    private static final Pattern DEPARTMENT_PATTERN =
            Pattern.compile("^[A-Za-z]+(\\s[A-Za-z]+)*$"); // words and spaces only

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String name = request.getParameter("name");
        String email = request.getParameter("email");
        String phone = request.getParameter("phone");
        String password = request.getParameter("password");
        String confirmPassword = request.getParameter("confirmPassword");
        String role = request.getParameter("role");

        if (name == null || name.trim().isEmpty() ||
            email == null || email.trim().isEmpty() ||
            phone == null || phone.trim().isEmpty() ||
            password == null || password.isEmpty() ||
            role == null) {
            request.setAttribute("error", "Please fill in all required fields.");
            forwardToRegister(request, response);
            return;
        }

        name = name.trim();
        email = email.trim();
        phone = phone.trim();

        if (!NAME_PATTERN.matcher(name).matches()) {
            request.setAttribute("error", "Please enter your full name (first and last name, letters only).");
            forwardToRegister(request, response);
            return;
        }

        if (!EMAIL_PATTERN.matcher(email).matches()) {
            request.setAttribute("error", "Please enter a valid email address.");
            forwardToRegister(request, response);
            return;
        }

        if (!PHONE_PATTERN.matcher(phone).matches()) {
            request.setAttribute("error", "Phone number must be exactly 10 digits.");
            forwardToRegister(request, response);
            return;
        }

        if (!password.equals(confirmPassword)) {
            request.setAttribute("error", "Passwords do not match.");
            forwardToRegister(request, response);
            return;
        }

        if (password.length() < 8) {
            request.setAttribute("error", "Password must be at least 8 characters.");
            forwardToRegister(request, response);
            return;
        }

        UserDAO userDAO = new UserDAO();
        String verifyToken = TokenUtil.newToken();

        try {
            if (userDAO.emailExists(email)) {
                request.setAttribute("error", "An account with this email already exists.");
                forwardToRegister(request, response);
                return;
            }

            if ("STUDENT".equals(role)) {
                String department = request.getParameter("department");
                String yearOfStudyStr = request.getParameter("yearOfStudy");

                if (department == null || department.trim().isEmpty() ||
                    yearOfStudyStr == null || yearOfStudyStr.trim().isEmpty()) {
                    request.setAttribute("error", "Please fill in all student details.");
                    forwardToRegister(request, response);
                    return;
                }

                department = department.trim();

                if (!DEPARTMENT_PATTERN.matcher(department).matches()) {
                    request.setAttribute("error", "Department must contain letters only (no numbers or symbols).");
                    forwardToRegister(request, response);
                    return;
                }

                int yearOfStudy;
                try {
                    yearOfStudy = Integer.parseInt(yearOfStudyStr);
                } catch (NumberFormatException e) {
                    request.setAttribute("error", "Please enter a valid number for year of study.");
                    forwardToRegister(request, response);
                    return;
                }

                if (yearOfStudy < 1 || yearOfStudy > 4) {
                    request.setAttribute("error", "Year of study must be between 1 and 4.");
                    forwardToRegister(request, response);
                    return;
                }

                userDAO.registerStudent(name, email, phone, password, department, yearOfStudy, verifyToken);

            } else if ("TUTOR".equals(role)) {
                // Basic account only — rate, bio, subjects, and documents are
                // collected afterward on complete-tutor-application.jsp.
                userDAO.registerTutorBasic(name, email, phone, password, verifyToken);

            } else {
                request.setAttribute("error", "Please select a role.");
                forwardToRegister(request, response);
                return;
            }

            // The account stays inactive until the user clicks this link.
            String baseUrl = request.getScheme() + "://" + request.getServerName()
                    + ":" + request.getServerPort() + request.getContextPath();
            EmailUtil.sendVerificationEmail(email, name, role, baseUrl + "/verify-email?token=" + verifyToken);
            response.sendRedirect(request.getContextPath() + "/login.jsp?registered=true");

        } catch (SQLException e) {
            java.util.logging.Logger.getLogger(RegisterServlet.class.getName()).log(java.util.logging.Level.SEVERE, "Registration failed", e);
            request.setAttribute("error", "Registration failed. Please try again later.");
            forwardToRegister(request, response);
        }
    }

    private void forwardToRegister(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        request.getRequestDispatcher("/register.jsp").forward(request, response);
    }
}