<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.ReviewDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"ADMIN".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }
    List<ReviewDAO.Flag> flags = new java.util.ArrayList<>();
    String loadError = null;
    try {
        flags = new ReviewDAO().getAllFlags();
    } catch (Exception e) {
        application.log("admin-reviews.jsp: could not load flags", e);
        loadError = e.getMessage();
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Reported Reviews</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .dash-table {
            width: 100%; border-collapse: collapse; background: white;
            border: 1px solid var(--border-light); border-radius: 6px; overflow: hidden;
        }
        .dash-table th, .dash-table td {
            text-align: left; padding: 12px 16px; font-size: 14px;
            border-bottom: 1px solid var(--border-light); vertical-align: top;
        }
        .dash-table th { background: var(--cream); color: var(--navy); font-size: 12px; text-transform: uppercase; }
        .pill { display: inline-block; padding: 3px 10px; border-radius: 3px; font-size: 12px; font-weight: 600; }
        .pill-PENDING { background: #fdf1de; color: #a2670e; }
        .pill-REMOVED { background: #fbeae7; color: var(--error); }
        .pill-KEPT { background: #e6edf5; color: var(--navy); }
        .btn-remove {
            background: var(--error); color: white; border: none; padding: 7px 14px; border-radius: 4px;
            font-size: 12px; font-weight: 600; font-family: inherit; cursor: pointer;
        }
        .btn-keep {
            background: transparent; color: var(--text-muted); border: 1px solid var(--border-light);
            padding: 7px 14px; border-radius: 4px; font-size: 12px; font-weight: 600; font-family: inherit; cursor: pointer;
        }
        .note-text { font-size: 12px; color: var(--text-muted); margin-top: 4px; max-width: 320px; white-space: pre-wrap; }
        .stars { color: var(--orange); }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">
        <div class="page-heading">
            <h1>Reported Reviews</h1>
            <p>A tutor can report a review about them. Keeping it leaves it visible. Removing it deletes the review
               and recalculates the tutor's average rating. A copy of every reported review is kept here.</p>
        </div>

        <div class="page-wrap">
            <% if (loadError != null) { %>
                <div class="empty-state">Could not load reported reviews: <%= EscapeUtil.html(loadError) %></div>
            <% } else if (flags.isEmpty()) { %>
                <div class="empty-state">No reported reviews.</div>
            <% } else { %>
                <div class="table-wrapper">
                <table class="dash-table">
                    <thead>
                        <tr>
                            <th>Review</th>
                            <th>Tutor's reason</th>
                            <th>Reported</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                    <% for (ReviewDAO.Flag f : flags) {
                        String label = "PENDING".equals(f.status) ? "Awaiting review"
                                : "REMOVED".equals(f.status) ? "Removed" : "Kept"; %>
                        <tr>
                            <td>
                                <strong><%= EscapeUtil.html(f.studentName == null ? "(removed account)" : f.studentName) %></strong>
                                &rarr; <%= EscapeUtil.html(f.tutorName == null ? "(removed account)" : f.tutorName) %>
                                <div class="stars"><% for (int i = 1; i <= 5; i++) { %><%= i <= f.stars ? "&#9733;" : "&#9734;" %><% } %></div>
                                <div class="note-text"><%= EscapeUtil.html(f.comment == null ? "" : f.comment) %></div>
                            </td>
                            <td><div class="note-text"><%= EscapeUtil.html(f.reason) %></div></td>
                            <td><%= f.createdAt %></td>
                            <td><span class="pill pill-<%= f.status %>"><%= label %></span></td>
                            <td>
                                <% if ("PENDING".equals(f.status)) { %>
                                    <form method="post" action="<%= request.getContextPath() %>/review-flag" style="display:inline;"
                                          onsubmit="return confirm('Remove this review? It will be deleted and the tutor\'s average will be recalculated.');">
                                        <input type="hidden" name="action" value="remove">
                                        <input type="hidden" name="flagId" value="<%= f.flagId %>">
                                        <button type="submit" class="btn-remove">Remove review</button>
                                    </form>
                                    <form method="post" action="<%= request.getContextPath() %>/review-flag" style="display:inline;">
                                        <input type="hidden" name="action" value="keep">
                                        <input type="hidden" name="flagId" value="<%= f.flagId %>">
                                        <button type="submit" class="btn-keep">Keep review</button>
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

<% if ("true".equals(request.getParameter("removed"))) { %>
    <script>showToast('Review removed and the average rating updated.', 'success');</script>
<% } %>
<% if ("true".equals(request.getParameter("kept"))) { %>
    <script>showToast('Review kept.', 'success');</script>
<% } %>
<%
    String err = request.getParameter("error");
    if (err != null) {
        String errMsg = "resolved".equals(err) ? "That report was already handled."
                : "Something went wrong. Please try again.";
%>
    <script>showToast('<%= errMsg %>', 'error');</script>
<% } %>
</body>
</html>