<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.peertutorconnect.dao.AdminDAO" %>
<%@ page import="com.peertutorconnect.dao.DocumentDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"ADMIN".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    int tutorId = Integer.parseInt(request.getParameter("tutorId"));
    AdminDAO.PendingTutor tutor = new AdminDAO().getPendingTutorById(tutorId);

    if (tutor == null) {
        response.sendRedirect(request.getContextPath() + "/admin-dashboard.jsp");
        return;
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>Tutor Application &mdash; <%= EscapeUtil.html(tutor.name) %></title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .detail-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 8px;
            padding: 28px;
            max-width: 640px;
        }

        .detail-card h2 { color: var(--navy); margin-bottom: 4px; }
        .detail-card .sub { color: var(--text-muted); font-size: 13px; margin-bottom: 20px; }

        .detail-row {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid var(--border-light);
            font-size: 14px;
        }

        .detail-row .lbl { color: var(--text-muted); }
        .detail-row .val { font-weight: 600; color: var(--text-dark); }

        .doc-links {
            margin-top: 16px;
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }

        .doc-links a {
            font-size: 13px;
            font-weight: 600;
            color: var(--navy);
            background: var(--cream);
            border: 1px solid var(--border-light);
            padding: 8px 14px;
            border-radius: 4px;
        }

        .doc-links a:hover { background: var(--orange); color: white; border-color: var(--orange); }

        .app-actions { display: flex; gap: 10px; margin-top: 24px; }

        .app-actions button {
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
        }

        .btn-approve { background: var(--success); color: white; }
        .btn-reject { background: var(--error); color: white; }

        .back-link { font-size: 13px; color: var(--text-muted); display: inline-block; margin-bottom: 16px; }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">
        <div class="page-heading">
            <a href="<%= request.getContextPath() %>/admin-dashboard.jsp" class="back-link">&larr; Back to Dashboard</a>
            <h1>Tutor Application</h1>
        </div>
        <div class="page-wrap">
            <div class="detail-card">
                <h2><%= EscapeUtil.html(tutor.name) %></h2>
                <p class="sub"><%= EscapeUtil.html(tutor.email) %></p>

                <div class="detail-row"><span class="lbl">Hourly Rate</span><span class="val">R<%= String.format("%.2f", tutor.hourlyRate) %>/hr</span></div>
                <div class="detail-row"><span class="lbl">Subjects</span><span class="val"><%= tutor.subjects.isEmpty() ? "None listed" : tutor.subjects %></span></div>
                <div class="detail-row"><span class="lbl">Bio</span><span class="val"><%= (tutor.bio != null && !tutor.bio.trim().isEmpty()) ? EscapeUtil.html(tutor.bio) : "Not provided" %></span></div>

                <% if (tutor.documents == null || tutor.documents.isEmpty()) { %>
                    <p style="color: var(--error); margin-top: 16px;">No documents uploaded.</p>
                <% } else { %>
                    <div class="doc-links">
                        <% for (DocumentDAO.Document d : tutor.documents) { %>
                            <a href="<%= request.getContextPath() %>/document?id=<%= d.documentId %>" target="_blank">
                                View <%= d.documentType.replace("_", " ") %>
                            </a>
                        <% } %>
                    </div>
                <% } %>

                <div class="app-actions">
                    <form method="post" action="<%= request.getContextPath() %>/verify-tutor">
                        <input type="hidden" name="tutorId" value="<%= tutor.tutorId %>">
                        <input type="hidden" name="action" value="approve">
                        <button type="submit" class="btn-approve">Approve Tutor</button>
                    </form>
                    <form method="post" action="<%= request.getContextPath() %>/verify-tutor">
                        <input type="hidden" name="tutorId" value="<%= tutor.tutorId %>">
                        <input type="hidden" name="action" value="reject">
                        <button type="submit" class="btn-reject">Reject Application</button>
                    </form>
                </div>
            </div>
        </div>
    </main>
</div>
</body>
</html>