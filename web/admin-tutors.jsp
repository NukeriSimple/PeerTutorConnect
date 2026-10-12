<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.AdminDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"ADMIN".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    List<AdminDAO.TutorSummary> tutors = new AdminDAO().getActiveTutors();
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Active Tutors</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .dash-table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            overflow: hidden;
        }

        .dash-table th, .dash-table td {
            text-align: left;
            padding: 12px 16px;
            font-size: 14px;
            border-bottom: 1px solid var(--border-light);
        }

        .dash-table th {
            background: var(--cream);
            color: var(--navy);
            font-size: 12px;
            text-transform: uppercase;
        }

        .name-link {
            color: var(--navy);
            font-weight: 600;
        }

        .name-link:hover {
            color: var(--orange);
        }

        .back-link {
            font-size: 13px;
            color: var(--text-muted);
            display: inline-block;
            margin-bottom: 16px;
        }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

        <div class="page-heading">
            <a href="<%= request.getContextPath() %>/admin-dashboard.jsp" class="back-link">&larr; Back to Dashboard</a>
            <h1>Active Tutors</h1>
            <p><%= tutors.size() %> approved tutor<%= tutors.size() == 1 ? "" : "s" %> currently on the platform.</p>
        </div>

        <div class="page-wrap">

            <% if (tutors.isEmpty()) { %>
                <div class="empty-state">No active tutors yet.</div>
            <% } else { %>
                <table class="dash-table">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Email</th>
                            <th>Rate</th>
                            <th>Rating</th>
                            <th>Subjects</th>
                        </tr>
                    </thead>
                    <tbody>
                        <% for (AdminDAO.TutorSummary t : tutors) { %>
                            <tr>
                                <td>
                                    <a href="<%= request.getContextPath() %>/manage-users.jsp#user-<%= t.userId %>" class="name-link">
                                        <%= EscapeUtil.html(t.name) %>
                                    </a>
                                </td>
                                <td><%= EscapeUtil.html(t.email) %></td>
                                <td>R<%= String.format("%.2f", t.hourlyRate) %>/hr</td>
                                <td><%= t.averageRating > 0 ? String.format("%.1f", t.averageRating) : "No ratings yet" %></td>
                                <td><%= t.subjects.isEmpty() ? "None listed" : t.subjects %></td>
                            </tr>
                        <% } %>
                    </tbody>
                </table>
            <% } %>

        </div>
    </main>
</div>
</body>
</html>