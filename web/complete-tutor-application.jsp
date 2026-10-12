<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="com.peertutorconnect.util.DBConnection" %>
<%@ page import="com.peertutorconnect.dao.AvailabilityDAO" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
<%
    if (session.getAttribute("role") == null || !"TUTOR".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    int userId = (int) session.getAttribute("userId");
    AvailabilityDAO availDAO = new AvailabilityDAO();
    Integer tutorId = availDAO.getTutorIdForUser(userId);

    if (tutorId == null) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    if (new TutorDAO().isApplicationComplete(tutorId)) {
        response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp");
        return;
    }

    String tutorName = (String) session.getAttribute("name");
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Complete Your Application</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .form-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 8px;
            padding: 32px;
            max-width: 560px;
        }

        .form-card .subtext {
            font-size: 0.85rem;
            color: var(--text-muted);
            margin-bottom: 24px;
        }

        .form-error {
            background: #fbeae7;
            border: 1px solid var(--error);
            color: var(--error);
            padding: 10px 14px;
            border-radius: 4px;
            font-size: 13px;
            margin-bottom: 18px;
        }

        .form-row {
            margin-bottom: 16px;
        }

        .submit-btn {
            width: 100%;
            padding: 12px;
            margin-top: 8px;
        }

        .file-hint {
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 4px;
        }
    </style>
</head>
<body>

<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

        <div class="page-heading">
            <h1>Complete Your Tutor Application</h1>
            <p>Welcome, <%= tutorName %>. Just a few more details before you can start tutoring.</p>
        </div>

        <div class="page-wrap">
            <div class="form-card">

                <% String error = (String) request.getAttribute("error"); %>
                <% if (error != null) { %>
                    <div class="form-error"><%= error %></div>
                <% } %>

                <form method="post" action="<%= request.getContextPath() %>/complete-tutor-application" enctype="multipart/form-data">

                    <div class="form-row">
                        <label for="hourlyRate">Hourly Rate (R)</label>
                        <input type="number" id="hourlyRate" name="hourlyRate" step="0.01" min="0" required>
                    </div>

                    <div class="form-row">
                        <label for="bio">Short Bio</label>
                        <textarea id="bio" name="bio" rows="3"></textarea>
                    </div>

                    <div class="form-row">
                        <label>Subjects You Can Teach</label>
                        <%
                            try (Connection conn = DBConnection.getConnection();
                                 Statement st = conn.createStatement();
                                 ResultSet rs = st.executeQuery("SELECT subjectId, moduleCode, name FROM subject ORDER BY moduleCode")) {
                                while (rs.next()) {
                        %>
                            <div style="margin-bottom: 6px;">
                                <label style="display: inline; font-weight: normal; font-size: 13px;">
                                    <input type="checkbox" name="subjectIds" value="<%= rs.getInt("subjectId") %>" style="width: auto; display: inline;">
                                    <%= rs.getString("moduleCode") %> &mdash; <%= rs.getString("name") %>
                                </label>
                            </div>
                        <%
                                }
                            } catch (SQLException e) {
                                out.println("<p style='color:red;'>Could not load subjects.</p>");
                            }
                        %>
                    </div>

                    <div class="form-row">
                        <label for="idDocument">Student ID (PDF or image)</label>
                        <input type="file" id="idDocument" name="idDocument" accept=".pdf,.jpg,.jpeg,.png" required>
                        <div class="file-hint">Required for tutor verification.</div>
                    </div>

                    <div class="form-row">
                        <label for="transcriptDocument">Academic Transcript (PDF)</label>
                        <input type="file" id="transcriptDocument" name="transcriptDocument" accept=".pdf,.jpg,.jpeg,.png" required>
                        <div class="file-hint">Required for tutor verification.</div>
                    </div>

                    <p class="subtext">Your application will be reviewed by an admin before your profile goes live and you can accept bookings.</p>

                    <button type="submit" class="btn btn-primary submit-btn">Submit Application</button>
                </form>

            </div>
        </div>

    </main>
</div>

</body>
</html>