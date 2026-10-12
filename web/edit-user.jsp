<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.peertutorconnect.dao.UserDAO.ProfileRow" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"ADMIN".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }
    ProfileRow editUser = (ProfileRow) request.getAttribute("editUser");
    String editError = (String) request.getAttribute("editError");
    boolean editIsStudent = editUser != null && "STUDENT".equals(editUser.role);
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Edit User</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .form-page {
            max-width: 560px;
            margin: 0;
            padding: 0;
        }

        .form-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 8px;
            padding: 32px;
        }

        .form-card h1 {
            font-size: 1.4rem;
            color: var(--navy);
            margin-bottom: 6px;
        }

        .form-card .subtext {
            font-size: 0.85rem;
            color: var(--text-muted);
            margin-bottom: 24px;
        }

        .form-row {
            margin-bottom: 16px;
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

        .submit-row {
            display: flex;
            gap: 12px;
            margin-top: 8px;
        }

        .btn-cancel {
            padding: 10px 20px;
            border: 1px solid var(--border-light);
            border-radius: 4px;
            background: white;
            color: var(--text-muted);
            font-weight: 600;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
        }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

        <div class="page-heading">
            <h1>Edit User</h1>
            <p>Correct account details, including fields the user can't edit themselves.</p>
        </div>

        <div class="page-wrap">
        <div class="form-page">
            <div class="form-card">

                <% if (editUser == null) { %>
                    <div class="form-error">User not found.</div>
                    <a href="<%= request.getContextPath() %>/manage-users.jsp" class="btn-cancel">Back to Manage Users</a>
                <% } else { %>

                    <h1><%= EscapeUtil.html(editUser.name) %></h1>
                    <p class="subtext">Role: <%= editUser.role %></p>

                    <% if (editError != null) { %>
                        <div class="form-error"><%= editError %></div>
                    <% } %>

                    <form method="post" action="<%= request.getContextPath() %>/manage-users">
                        <input type="hidden" name="action" value="update">
                        <input type="hidden" name="userId" value="<%= editUser.userId %>">

                        <div class="form-row">
                            <label for="name">Full Name</label>
                            <input type="text" id="name" name="name" required
                                   value="<%= EscapeUtil.html(editUser.name) %>">
                        </div>

                        <div class="form-row">
                            <label for="email">Email</label>
                            <input type="email" id="email" name="email" required
                                   value="<%= EscapeUtil.html(editUser.email) %>">
                        </div>

                        <div class="form-row">
                            <label for="phone">Phone Number</label>
                            <input type="text" id="phone" name="phone" required
                                   inputmode="numeric" maxlength="10"
                                   value="<%= EscapeUtil.html(editUser.phone) %>">
                        </div>

                        <% if (editIsStudent) { %>
                        <div class="form-row">
                            <label for="department">Department</label>
                            <input type="text" id="department" name="department" required
                                   value="<%= editUser.department != null ? EscapeUtil.html(editUser.department) : "" %>">
                        </div>
                        <div class="form-row">
                            <label for="yearOfStudy">Year of Study</label>
                            <select id="yearOfStudy" name="yearOfStudy">
                                <% for (int y = 1; y <= 4; y++) { %>
                                    <option value="<%= y %>" <%= (editUser.yearOfStudy != null && editUser.yearOfStudy == y) ? "selected" : "" %>><%= y %></option>
                                <% } %>
                            </select>
                        </div>
                        <% } %>

                        <div class="submit-row">
                            <button type="submit" class="btn btn-primary">Save Changes</button>
                            <a href="<%= request.getContextPath() %>/manage-users.jsp" class="btn-cancel">Cancel</a>
                        </div>
                    </form>

                <% } %>
            </div>
        </div>
        </div>
    </main>
</div>
</body>
</html>