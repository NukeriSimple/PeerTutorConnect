<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.NoShowDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"ADMIN".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    List<NoShowDAO.Report> reports = new NoShowDAO().getAllReports();
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; No-Show Reports</title>
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
            vertical-align: top;
        }

        .dash-table th {
            background: var(--cream);
            color: var(--navy);
            font-size: 12px;
            text-transform: uppercase;
        }

        .pill {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 3px;
            font-size: 12px;
            font-weight: 600;
        }

        .pill-PENDING { background: #fdf1de; color: #a2670e; }
        .pill-STRIKE_ISSUED { background: #fbeae7; color: var(--error); }
        .pill-DISMISSED { background: #eee; color: var(--text-muted); }
        .pill-RECORDED { background: #e6edf5; color: var(--navy); }

        .btn-strike {
            background: var(--error);
            color: white;
            border: none;
            padding: 7px 14px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            font-family: inherit;
            cursor: pointer;
        }

        .btn-dismiss {
            background: transparent;
            color: var(--text-muted);
            border: 1px solid var(--border-light);
            padding: 7px 14px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            font-family: inherit;
            cursor: pointer;
        }

        .note-text {
            font-size: 12px;
            color: var(--text-muted);
            margin-top: 4px;
            max-width: 280px;
        }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

        <div class="page-heading">
            <h1>No-Show Reports</h1>
            <p>When a tutor or a student reports a no-show, it waits here for you. Confirming it gives the absent
               person a strike; <%= NoShowDAO.MAX_STRIKES %> strikes removes their account. A strike that was
               issued by mistake can be revoked.</p>
        </div>

        <div class="page-wrap">

            <% if (reports.isEmpty()) { %>
                <div class="empty-state">No no-show reports yet.</div>
            <% } else { %>
                <div class="table-wrapper">
                <table class="dash-table">
                    <thead>
                        <tr>
                            <th>Absent</th>
                            <th>Reported by</th>
                            <th>Session</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <% for (NoShowDAO.Report r : reports) {
                            boolean studentAbsent = "STUDENT".equals(r.absentRole);
                            String statusLabel = r.status;
                            if ("STRIKE_ISSUED".equals(r.status)) statusLabel = "Strike issued";
                            else if ("RECORDED".equals(r.status)) statusLabel = "Review recorded";
                            else if ("DISMISSED".equals(r.status)) statusLabel = "Dismissed";
                            else if ("PENDING".equals(r.status)) statusLabel = "Awaiting review";
                        %>
                            <tr>
                                <td>
                                    <strong><%= EscapeUtil.html(r.absentName == null ? "(removed account)" : r.absentName) %></strong>
                                    <div class="note-text"><%= studentAbsent ? "Student" : "Tutor" %>
                                        <% if (r.absentName != null) { %>
                                            &middot; <%= r.absentStrikes %> / <%= NoShowDAO.MAX_STRIKES %> strikes
                                        <% } %>
                                    </div>
                                </td>
                                <td>
                                    <%= EscapeUtil.html(r.reporterName == null ? "(removed account)" : r.reporterName) %>
                                    <% if (r.note != null && !r.note.trim().isEmpty()) { %>
                                        <div class="note-text"><%= studentAbsent ? "Note" : "Review" %>: <%= EscapeUtil.html(r.note) %></div>
                                    <% } %>
                                    <% if (!studentAbsent && ("PENDING".equals(r.status) || "STRIKE_ISSUED".equals(r.status))) { %>
                                        <div class="note-text" style="color: var(--error); font-weight: 600;">
                                            Refund due to student if confirmed: R<%= String.format(java.util.Locale.US, "%.2f", r.sessionPrice) %>
                                        </div>
                                    <% } %>
                                </td>
                                <td>
                                    <%= r.bookingDate %><br>
                                    <span class="note-text"><%= r.startTime %> &ndash; <%= r.endTime %></span>
                                </td>
                                <td><span class="pill pill-<%= r.status %>"><%= statusLabel %></span></td>
                                <td>
                                    <% if ("PENDING".equals(r.status)) { %>
                                        <form method="post" action="<%= request.getContextPath() %>/no-show" style="display:inline;"
                                              onsubmit="return confirm('Issue a strike to this <%= studentAbsent ? "student" : "tutor" %>? <%= r.absentStrikes + 1 >= NoShowDAO.MAX_STRIKES ? "This is their final strike and their account will be removed." : "" %>');">
                                            <input type="hidden" name="action" value="strike">
                                            <input type="hidden" name="reportId" value="<%= r.reportId %>">
                                            <button type="submit" class="btn-strike">Confirm &amp; issue strike</button>
                                        </form>
                                        <form method="post" action="<%= request.getContextPath() %>/no-show" style="display:inline;">
                                            <input type="hidden" name="action" value="dismiss">
                                            <input type="hidden" name="reportId" value="<%= r.reportId %>">
                                            <button type="submit" class="btn-dismiss">Dismiss</button>
                                        </form>
                                    <% } else if ("STRIKE_ISSUED".equals(r.status) && r.absentName != null) { %>
                                        <form method="post" action="<%= request.getContextPath() %>/no-show" style="display:inline;"
                                              onsubmit="return confirm('Revoke this strike? The user loses one strike and the report is closed.');">
                                            <input type="hidden" name="action" value="revoke">
                                            <input type="hidden" name="reportId" value="<%= r.reportId %>">
                                            <button type="submit" class="btn-dismiss">Revoke strike</button>
                                        </form>
                                    <% } else { %>
                                        <span style="color: var(--text-muted); font-size: 12px;">&mdash;</span>
                                    <% } %>
                                </td>
                            </tr>
                        <% } %>
                    </tbody>
                </table>
                </div>
            <% } %>

        </div>
    </main>
</div>

<%
    String struck = request.getParameter("struck");
    String removed = request.getParameter("removed");
    String err = request.getParameter("error");
%>
<% if (struck != null) { %>
    <script>showToast('Strike issued (<%= EscapeUtil.html(struck) %> of <%= NoShowDAO.MAX_STRIKES %>).', 'success');</script>
<% } %>
<% if (removed != null) { %>
    <script>showToast('Final strike issued. The <%= "tutor".equals(removed) ? "tutor" : "student" %> account has been removed.', 'success');</script>
<% } %>
<% if (request.getParameter("revoked") != null) { %>
    <script>showToast('Strike revoked. The user now has <%= EscapeUtil.html(request.getParameter("revoked")) %> of <%= NoShowDAO.MAX_STRIKES %> strikes.', 'success');</script>
<% } %>
<% if ("true".equals(request.getParameter("removalfailed"))) { %>
    <script>showToast('Strike saved, but the account could not be removed automatically. Remove it in Manage Users.', 'error');</script>
<% } %>
<% if ("true".equals(request.getParameter("dismissed"))) { %>
    <script>showToast('Report dismissed. No strike was given.', 'success');</script>
<% } %>
<% if (err != null) {
       String errMsg;
       if ("resolved".equals(err)) errMsg = "That report was already handled.";
       else if ("notissued".equals(err)) errMsg = "Only a report with an issued strike can be revoked.";
       else if ("accountgone".equals(err)) errMsg = "That account has already been removed, so the strike can't be revoked.";
       else errMsg = "Something went wrong. Please try again.";
%>
    <script>showToast('<%= errMsg %>', 'error');</script>
<% } %>

</body>
</html>