<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.NotificationDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("userId") == null) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }
    int userId = (int) session.getAttribute("userId");
    List<NotificationDAO.Notification> notifications = new NotificationDAO().getForUser(userId);
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Notifications</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">
        <div class="page-heading">
            <h1>Notifications</h1>
            <p>Updates on your bookings and account.</p>
        </div>
        <div class="page-wrap">
            <% if (!notifications.isEmpty()) { %>
                <div style="margin-bottom: 16px;">
                    <a href="<%= request.getContextPath() %>/notification?action=markAll" class="btn btn-outline" style="color: var(--navy); border-color: var(--navy);">Mark all as read</a>
                </div>
            <% } %>
            <% if (notifications.isEmpty()) { %>
                <div class="empty-state">No notifications yet.</div>
            <% } else { %>
                <div class="notif-list">
                    <% for (NotificationDAO.Notification n : notifications) { %>
                        <div class="notif-item <%= n.isRead ? "" : "unread" %>">
                            <a href="<%= request.getContextPath() %>/notification?id=<%= n.notificationId %><%= n.link != null ? "&redirect=" + n.link : "" %>" style="color: inherit; flex: 1;">
                                <%= EscapeUtil.html(n.message) %>
                            </a>
                            <span class="notif-time"><%= n.createdAt %></span>
                        </div>
                    <% } %>
                </div>
            <% } %>
        </div>
    </main>
</div>
</body>
</html>