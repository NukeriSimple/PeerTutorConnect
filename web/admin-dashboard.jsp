<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.AdminDAO" %>
<%@ page import="com.peertutorconnect.dao.DocumentDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"ADMIN".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    AdminDAO adminDAO = new AdminDAO();
    List<AdminDAO.PendingTutor> pending = adminDAO.getPendingTutors();
    AdminDAO.SystemStats stats = adminDAO.getStats();
    String adminName = (String) session.getAttribute("name");
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Admin Dashboard</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .stat-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
            gap: 16px;
            margin-bottom: 32px;
        }

        .stat-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 18px;
            display: flex;
            align-items: center;
            gap: 14px;
            text-decoration: none;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            cursor: pointer;
        }

        .stat-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 6px 18px rgba(0,0,0,0.08);
        }

        .stat-icon {
            width: 42px;
            height: 42px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }

        .stat-icon svg {
            width: 22px;
            height: 22px;
            stroke: white;
        }

        .stat-icon.icon-users { background-color: var(--navy); }
        .stat-icon.icon-tutors { background-color: var(--success); }
        .stat-icon.icon-pending { background-color: #c97f2a; }
        .stat-icon.icon-bookings { background-color: var(--navy-light); }
        .stat-icon.icon-completed { background-color: var(--orange); }

        .stat-card .num {
            font-size: 1.6rem;
            font-weight: bold;
            color: var(--navy);
            line-height: 1.2;
        }

        .stat-card .lbl {
            font-size: 12px;
            color: var(--text-muted);
            text-transform: uppercase;
        }

        .app-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 18px;
            margin-bottom: 12px;
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            flex-wrap: wrap;
            gap: 12px;
        }

        .app-details h4 {
            color: var(--navy);
            margin-bottom: 4px;
        }

        .app-details p {
            font-size: 13px;
            color: var(--text-muted);
            margin-bottom: 4px;
        }

        .doc-links {
            margin-top: 8px;
            display: flex;
            gap: 10px;
        }

        .doc-links a {
            font-size: 12px;
            font-weight: 600;
            color: var(--navy);
            background: var(--cream);
            border: 1px solid var(--border-light);
            padding: 4px 10px;
            border-radius: 4px;
        }

        .doc-links a:hover { background: var(--orange); color: white; border-color: var(--orange); }

        .app-actions { display: flex; gap: 8px; }

        .app-actions button {
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
        }

        .btn-approve { background: var(--success); color: white; }
        .btn-reject { background: var(--error); color: white; }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

        <div class="page-heading">
            <h1>Admin Dashboard</h1>
            <p>Welcome, <%= EscapeUtil.html(adminName) %>. System overview and pending tutor applications.</p>
        </div>

        <div class="page-wrap">

            <div style="margin-bottom: 20px;">
                <a href="<%= request.getContextPath() %>/manage-users.jsp" class="btn btn-primary">Manage Users</a>
            </div>

            <div class="stat-cards">
                <a class="stat-card" href="<%= request.getContextPath() %>/manage-users.jsp">
                    <div class="stat-icon icon-users">
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                            <circle cx="9" cy="7" r="4"/>
                            <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                            <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                        </svg>
                    </div>
                    <div>
                        <div class="num"><%= stats.totalUsers %></div>
                        <div class="lbl">Total Users</div>
                    </div>
                </a>
                <a class="stat-card" href="<%= request.getContextPath() %>/admin-tutors.jsp">
                    <div class="stat-icon icon-tutors">
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M22 10v6M2 10l10-5 10 5-10 5-10-5z"/>
                            <path d="M6 12v5c0 1.5 2.5 3 6 3s6-1.5 6-3v-5"/>
                        </svg>
                    </div>
                    <div>
                        <div class="num"><%= stats.activeTutors %></div>
                        <div class="lbl">Active Tutors</div>
                    </div>
                </a>
                <a class="stat-card" href="#pending-applications">
                    <div class="stat-icon icon-pending">
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="12" cy="12" r="10"/>
                            <path d="M12 6v6l4 2"/>
                        </svg>
                    </div>
                    <div>
                        <div class="num"><%= stats.pendingApplications %></div>
                        <div class="lbl">Pending</div>
                    </div>
                </a>
                <a class="stat-card" href="<%= request.getContextPath() %>/admin-bookings.jsp">
                    <div class="stat-icon icon-bookings">
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <rect x="3" y="4" width="18" height="18" rx="2"/>
                            <path d="M16 2v4M8 2v4M3 10h18"/>
                        </svg>
                    </div>
                    <div>
                        <div class="num"><%= stats.totalSessions %></div>
                        <div class="lbl">Total Bookings</div>
                    </div>
                </a>
                <a class="stat-card" href="<%= request.getContextPath() %>/admin-bookings.jsp?status=COMPLETED">
                    <div class="stat-icon icon-completed">
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
                            <path d="M22 4 12 14.01l-3-3"/>
                        </svg>
                    </div>
                    <div>
                        <div class="num"><%= stats.completedSessions %></div>
                        <div class="lbl">Completed</div>
                    </div>
                </a>
            </div>

            <h3 id="pending-applications" style="color: var(--navy); margin-bottom: 14px;">Pending Tutor Applications</h3>

            <% if (pending.isEmpty()) { %>
                <div class="empty-state">No pending applications.</div>
            <% } else { %>
                <% for (AdminDAO.PendingTutor p : pending) { %>
                    <div class="app-card" style="cursor:pointer;" onclick="window.location='<%= request.getContextPath() %>/tutor-application-detail.jsp?tutorId=<%= p.tutorId %>'">
                        <div class="app-details">
                            <h4><%= EscapeUtil.html(p.name) %></h4>
                            <p><%= EscapeUtil.html(p.email) %> &middot; R<%= String.format("%.2f", p.hourlyRate) %>/hr</p>
                            <p><%= p.subjects.isEmpty() ? "No subjects listed" : p.subjects %></p>
                            <% if (p.bio != null && !p.bio.trim().isEmpty()) { %>
                                <p><%= EscapeUtil.html(p.bio) %></p>
                            <% } %>

                            <% if (p.documents == null || p.documents.isEmpty()) { %>
                                <p style="color: var(--error);">No documents uploaded</p>
                            <% } else { %>
                                <div class="doc-links" onclick="event.stopPropagation();">
                                    <% for (DocumentDAO.Document d : p.documents) { %>
                                        <a href="<%= request.getContextPath() %>/document?id=<%= d.documentId %>" target="_blank">
                                            View <%= d.documentType.replace("_", " ") %>
                                        </a>
                                    <% } %>
                                </div>
                            <% } %>

                            <p style="font-size: 12px; color: var(--navy); font-weight: 600; margin-top: 8px;">View full application &rarr;</p>
                        </div>
                        <div class="app-actions" onclick="event.stopPropagation();">
                            <form method="post" action="<%= request.getContextPath() %>/verify-tutor">
                                <input type="hidden" name="tutorId" value="<%= p.tutorId %>">
                                <input type="hidden" name="action" value="approve">
                                <button type="submit" class="btn-approve">Approve</button>
                            </form>
                            <form method="post" action="<%= request.getContextPath() %>/verify-tutor">
                                <input type="hidden" name="tutorId" value="<%= p.tutorId %>">
                                <input type="hidden" name="action" value="reject">
                                <button type="submit" class="btn-reject">Reject</button>
                            </form>
                        </div>
                    </div>
                <% } %>
            <% } %>

        </div>

    </main>
</div>

<% if ("true".equals(request.getParameter("success"))) { %>
    <script>showToast('Done.', 'success');</script>
<% } %>

</body>
</html>