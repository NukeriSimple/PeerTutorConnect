package com.peertutorconnect.controller;

import com.peertutorconnect.dao.UserDAO;
import com.peertutorconnect.dao.UserDAO.ProfileRow;
import com.peertutorconnect.util.EmailUtil;
import java.io.IOException;
import java.sql.SQLException;
import java.util.regex.Pattern;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet(name = "ManageUsersServlet", urlPatterns = {"/manage-users"})
public class ManageUsersServlet extends HttpServlet {

    private static final Pattern NAME_PATTERN =
            Pattern.compile("^[A-Za-z]+([ '\\-][A-Za-z]+)+$");
    private static final Pattern EMAIL_PATTERN =
            Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$");
    private static final Pattern PHONE_PATTERN =
            Pattern.compile("^\\d{10}$");
    private static final Pattern DEPARTMENT_PATTERN =
            Pattern.compile("^[A-Za-z]+(\\s[A-Za-z]+)*$");

    private final UserDAO userDAO = new UserDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || !"ADMIN".equals(session.getAttribute("role"))) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String action = request.getParameter("action");
        if ("edit".equals(action)) {
            try {
                int userId = Integer.parseInt(request.getParameter("userId"));
                ProfileRow editUser = userDAO.getProfile(userId);
                request.setAttribute("editUser", editUser);
                request.getRequestDispatcher("/edit-user.jsp").forward(request, response);
            } catch (NumberFormatException | SQLException e) {
                response.sendRedirect(request.getContextPath() + "/manage-users.jsp?error=db");
            }
            return;
        }

        response.sendRedirect(request.getContextPath() + "/manage-users.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || !"ADMIN".equals(session.getAttribute("role"))) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String action = request.getParameter("action");

        try {
            if ("delete".equals(action)) {
                int userId = Integer.parseInt(request.getParameter("userId"));
                int currentAdminId = (int) session.getAttribute("userId");
                if (userId == currentAdminId) {
                    response.sendRedirect(request.getContextPath() + "/manage-users.jsp?error=selfdelete");
                    return;
                }
                userDAO.deleteUser(userId);
                response.sendRedirect(request.getContextPath() + "/manage-users.jsp?success=true");
                return;
            }

            if ("add".equals(action)) {
                handleAdd(request, response);
                return;
            }

            if ("update".equals(action)) {
                handleUpdate(request, response);
                return;
            }

        } catch (SQLException e) {
            response.sendRedirect(request.getContextPath() + "/manage-users.jsp?error=db");
        } catch (NumberFormatException e) {
            response.sendRedirect(request.getContextPath() + "/manage-users.jsp?error=invalid");
        }
    }

    private void handleAdd(HttpServletRequest request, HttpServletResponse response)
            throws IOException, SQLException {

        String name = request.getParameter("name");
        String email = request.getParameter("email");
        String phone = request.getParameter("phone");
        String password = request.getParameter("password");
        String role = request.getParameter("role");

        if (name == null || name.trim().isEmpty() ||
            email == null || email.trim().isEmpty() ||
            password == null || password.length() < 8 || role == null) {
            response.sendRedirect(request.getContextPath() + "/manage-users.jsp?error=invalid");
            return;
        }

        if (userDAO.emailExists(email)) {
            response.sendRedirect(request.getContextPath() + "/manage-users.jsp?error=exists");
            return;
        }

        if ("STUDENT".equals(role)) {
            String department = request.getParameter("department");
            String yearOfStudyStr = request.getParameter("yearOfStudy");
            if (department == null || department.trim().isEmpty() ||
                yearOfStudyStr == null || yearOfStudyStr.trim().isEmpty()) {
                response.sendRedirect(request.getContextPath() + "/manage-users.jsp?error=invalid");
                return;
            }
            userDAO.registerStudent(name, email, phone, password, department,
                    Integer.parseInt(yearOfStudyStr));
            EmailUtil.sendWelcomeEmail(email, name, "STUDENT");

        } else if ("TUTOR".equals(role)) {
            String hourlyRateStr = request.getParameter("hourlyRate");
            if (hourlyRateStr == null || hourlyRateStr.trim().isEmpty()) {
                response.sendRedirect(request.getContextPath() + "/manage-users.jsp?error=invalid");
                return;
            }
            userDAO.registerTutor(name, email, phone, password,
                    Double.parseDouble(hourlyRateStr), "", new int[0], true);
            EmailUtil.sendWelcomeEmail(email, name, "TUTOR");

        } else if ("ADMIN".equals(role)) {
            userDAO.registerAdmin(name, email, phone, password);
            EmailUtil.sendWelcomeEmail(email, name, "ADMIN");
        } else {
            response.sendRedirect(request.getContextPath() + "/manage-users.jsp?error=invalid");
            return;
        }

        response.sendRedirect(request.getContextPath() + "/manage-users.jsp?success=true");
    }

    /**
     * Lets an admin correct fields that a user can no longer edit on
     * their own profile page: name, department, year
     * of study. Email and phone are included too, for convenience.
     */
    private void handleUpdate(HttpServletRequest request, HttpServletResponse response)
            throws IOException, SQLException, ServletException {

        int userId = Integer.parseInt(request.getParameter("userId"));
        String name = request.getParameter("name");
        String email = request.getParameter("email");
        String phone = request.getParameter("phone");

        if (name == null || name.trim().isEmpty() ||
            email == null || email.trim().isEmpty() ||
            phone == null || phone.trim().isEmpty()) {
            forwardEditError(request, response, userId, "Please fill in all required fields.");
            return;
        }

        name = name.trim();
        email = email.trim();
        phone = phone.trim();

        if (!NAME_PATTERN.matcher(name).matches()) {
            forwardEditError(request, response, userId, "Please enter a full name (first and last name, letters only).");
            return;
        }

        if (!EMAIL_PATTERN.matcher(email).matches()) {
            forwardEditError(request, response, userId, "Please enter a valid email address.");
            return;
        }

        if (!PHONE_PATTERN.matcher(phone).matches()) {
            forwardEditError(request, response, userId, "Phone number must be exactly 10 digits.");
            return;
        }

        if (userDAO.emailExists(email, userId)) {
            forwardEditError(request, response, userId, "Another account is already using this email.");
            return;
        }

        ProfileRow existing = userDAO.getProfile(userId);
        boolean isStudent = existing != null && "STUDENT".equals(existing.role);

        if (isStudent) {
            String department = request.getParameter("department");
            String yearOfStudyStr = request.getParameter("yearOfStudy");

            if (department == null || department.trim().isEmpty() ||
                yearOfStudyStr == null || yearOfStudyStr.trim().isEmpty()) {
                forwardEditError(request, response, userId, "Please fill in all student details.");
                return;
            }

            department = department.trim();

            if (!DEPARTMENT_PATTERN.matcher(department).matches()) {
                forwardEditError(request, response, userId, "Department must contain letters only.");
                return;
            }

            int yearOfStudy;
            try {
                yearOfStudy = Integer.parseInt(yearOfStudyStr);
            } catch (NumberFormatException e) {
                forwardEditError(request, response, userId, "Please select a valid year of study.");
                return;
            }

            userDAO.updateBasicInfo(userId, name, email, phone);
            userDAO.updateStudentInfo(userId, department, yearOfStudy);
        } else {
            userDAO.updateBasicInfo(userId, name, email, phone);
        }

        response.sendRedirect(request.getContextPath() + "/manage-users.jsp?success=true");
    }

    private void forwardEditError(HttpServletRequest request, HttpServletResponse response,
                                   int userId, String message)
            throws IOException, SQLException, ServletException {
        ProfileRow editUser = userDAO.getProfile(userId);
        request.setAttribute("editUser", editUser);
        request.setAttribute("editError", message);
        request.getRequestDispatcher("/edit-user.jsp").forward(request, response);
    }
}