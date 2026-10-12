<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.UserDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"ADMIN".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }
    List<UserDAO.UserRow> users = new UserDAO().getAllUsers();
    int currentAdminId = (int) session.getAttribute("userId");
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Manage Users</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .add-user-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 22px;
            margin-bottom: 28px;
        }

        .add-user-card h3 {
            color: var(--navy);
            margin-bottom: 14px;
        }

        .form-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 14px;
            margin-bottom: 14px;
        }

        .role-toggle {
            display: flex;
            gap: 10px;
            margin-bottom: 16px;
        }

        .role-toggle label {
            flex: 1;
            text-align: center;
            padding: 10px;
            border: 1px solid var(--border-light);
            border-radius: 4px;
            cursor: pointer;
            font-size: 13px;
            font-weight: 600;
            color: var(--text-muted);
            margin-bottom: 0;
        }

        .role-toggle input[type="radio"] { display: none; }

        .role-toggle input[type="radio"]:checked + label {
            border-color: var(--navy);
            background-color: var(--navy);
            color: white;
        }

        .conditional-fields { display: none; }
        .conditional-fields.active { display: contents; }

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

        .dash-table tbody tr:target {
            background-color: #fdf1de;
            animation: row-highlight-fade 2.5s ease forwards;
        }

        @keyframes row-highlight-fade {
            0% { background-color: #fdf1de; }
            70% { background-color: #fdf1de; }
            100% { background-color: transparent; }
        }

        .role-badge {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 3px;
            font-size: 12px;
            font-weight: 600;
        }

        .role-STUDENT { background: #e6edf5; color: var(--navy); }
        .role-TUTOR { background: #fdf1de; color: #a2670e; }
        .role-ADMIN { background: #fbeae7; color: var(--error); }

        .row-actions {
            display: flex;
            gap: 8px;
        }

        .btn-edit {
            background: transparent;
            border: 1px solid var(--navy);
            color: var(--navy);
            padding: 5px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
        }

        .btn-edit:hover { background: var(--navy); color: white; }

        .btn-delete {
            background: transparent;
            border: 1px solid var(--error);
            color: var(--error);
            padding: 5px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
        }

        .btn-delete:hover { background: var(--error); color: white; }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

        <div class="page-heading">
            <h1>Manage Users</h1>
            <p>Add accounts manually, edit existing ones, or remove them.</p>
        </div>

        <div class="page-wrap">

            <div class="add-user-card">
                <h3>Add a User</h3>
                <form method="post" action="<%= request.getContextPath() %>/manage-users" id="addUserForm">
                    <input type="hidden" name="action" value="add">

                    <div class="role-toggle">
                        <input type="radio" name="role" id="rStudent" value="STUDENT" checked onclick="toggleRole()">
                        <label for="rStudent">Student</label>
                        <input type="radio" name="role" id="rTutor" value="TUTOR" onclick="toggleRole()">
                        <label for="rTutor">Tutor</label>
                        <input type="radio" name="role" id="rAdmin" value="ADMIN" onclick="toggleRole()">
                        <label for="rAdmin">Admin</label>
                    </div>

                    <div class="form-grid">
                        <div>
                            <label for="name">Full Name</label>
                            <input type="text" id="name" name="name" required>
                        </div>
                        <div>
                            <label for="email">Email</label>
                            <input type="email" id="email" name="email" required>
                        </div>
                        <div>
                            <label for="phone">Phone</label>
                            <input type="text" id="phone" name="phone">
                        </div>
                        <div>
                            <label for="password">Password</label>
                            <input type="password" id="password" name="password" minlength="8" required>
                        </div>
                    </div>

                    <div id="studentFields" class="form-grid conditional-fields active">
                        <div>
                            <label for="department">Department</label>
                            <input type="text" id="department" name="department">
                        </div>
                        <div>
                            <label for="yearOfStudy">Year of Study</label>
                            <select id="yearOfStudy" name="yearOfStudy">
                                <option value="1">1</option>
                                <option value="2">2</option>
                                <option value="3">3</option>
                                <option value="4">4</option>
                            </select>
                        </div>
                    </div>

                    <div id="tutorFields" class="form-grid conditional-fields">
                        <div>
                            <label for="hourlyRate">Hourly Rate (R)</label>
                            <input type="number" id="hourlyRate" name="hourlyRate" step="0.01" min="0">
                        </div>
                    </div>

                    <button type="submit" class="btn btn-primary">Add User</button>
                </form>
            </div>

            <table class="dash-table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Role</th>
                        <th>Joined</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    <% for (UserDAO.UserRow u : users) { %>
                        <tr id="user-<%= u.userId %>">
                            <td><%= EscapeUtil.html(u.name) %></td>
                            <td><%= EscapeUtil.html(u.email) %></td>
                            <td><span class="role-badge role-<%= u.role %>"><%= u.role %></span></td>
                            <td><%= u.createdAt %></td>
                            <td>
                                <div class="row-actions">
                                    <a href="<%= request.getContextPath() %>/manage-users?action=edit&userId=<%= u.userId %>" class="btn-edit">Edit</a>
                                    <% if (u.userId != currentAdminId) { %>
                                        <form method="post" action="<%= request.getContextPath() %>/manage-users"
                                              onsubmit="return confirm('Delete this user? This removes all their bookings, sessions, and data permanently.');">
                                            <input type="hidden" name="action" value="delete">
                                            <input type="hidden" name="userId" value="<%= u.userId %>">
                                            <button type="submit" class="btn-delete">Delete</button>
                                        </form>
                                    <% } else { %>
                                        <span style="font-size: 12px; color: var(--text-muted);">You</span>
                                    <% } %>
                                </div>
                            </td>
                        </tr>
                    <% } %>
                </tbody>
            </table>

        </div>
    </main>
</div>

<% if ("true".equals(request.getParameter("success"))) { %>
    <script>showToast('Done.', 'success');</script>
<% } %>
<% if ("invalid".equals(request.getParameter("error"))) { %>
    <script>showToast('Please fill in all required fields correctly.', 'error');</script>
<% } %>
<% if ("exists".equals(request.getParameter("error"))) { %>
    <script>showToast('A user with that email already exists.', 'error');</script>
<% } %>
<% if ("selfdelete".equals(request.getParameter("error"))) { %>
    <script>showToast("You can't delete your own account while logged in as it.", 'error');</script>
<% } %>
<% if ("db".equals(request.getParameter("error"))) { %>
    <script>showToast('Something went wrong. Try again.', 'error');</script>
<% } %>

<script>
    function toggleRole() {
        var isStudent = document.getElementById('rStudent').checked;
        var isTutor = document.getElementById('rTutor').checked;
        document.getElementById('studentFields').classList.toggle('active', isStudent);
        document.getElementById('tutorFields').classList.toggle('active', isTutor);
    }
</script>

</body>
</html>