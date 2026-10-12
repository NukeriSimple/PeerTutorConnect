<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.AdminDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"ADMIN".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    String statusFilter = request.getParameter("status");
    List<AdminDAO.BookingSummary> bookings = new AdminDAO().getAllBookings(statusFilter);

    boolean isCompletedView = "COMPLETED".equals(statusFilter);
    String pageTitle = isCompletedView ? "Completed Bookings" : "All Bookings";
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; <%= pageTitle %></title>
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

        .status-pill {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 3px;
            font-size: 12px;
            font-weight: 600;
        }

        .status-PENDING { background: #fdf1de; color: #a2670e; }
        .status-CONFIRMED { background: #eaf5ee; color: var(--success); }
        .status-DECLINED { background: #fbeae7; color: var(--error); }
        .status-COMPLETED { background: #e6edf5; color: var(--navy); }
        .status-CANCELLED_STUDENT, .status-CANCELLED_TUTOR, .status-EXPIRED { background: #eee; color: var(--text-muted); }

        .back-link {
            font-size: 13px;
            color: var(--text-muted);
            display: inline-block;
            margin-bottom: 16px;
        }

        .filter-chip {
            display: inline-block;
            background: var(--navy);
            color: white;
            font-size: 12px;
            font-weight: 600;
            padding: 4px 12px;
            border-radius: 12px;
            margin-left: 10px;
        }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

        <div class="page-heading">
            <a href="<%= request.getContextPath() %>/admin-dashboard.jsp" class="back-link">&larr; Back to Dashboard</a>
            <h1>
                <%= pageTitle %>
                <% if (isCompletedView) { %><span class="filter-chip">Completed only</span><% } %>
            </h1>
            <p><%= bookings.size() %> booking<%= bookings.size() == 1 ? "" : "s" %><%= isCompletedView ? " completed" : " in total" %>.</p>
        </div>

        <div class="page-wrap">

            <% if (bookings.isEmpty()) { %>
                <div class="empty-state">No bookings to show.</div>
            <% } else { %>
                <div class="table-wrapper">
                <table class="dash-table">
                    <thead>
                        <tr>
                            <th>Student</th>
                            <th>Tutor</th>
                            <th>Date</th>
                            <th>Time</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        <% for (AdminDAO.BookingSummary b : bookings) { %>
                            <tr>
                                <td>
                                    <a href="<%= request.getContextPath() %>/manage-users.jsp#user-<%= b.studentUserId %>" class="name-link">
                                        <%= EscapeUtil.html(b.studentName) %>
                                    </a>
                                </td>
                                <td>
                                    <a href="<%= request.getContextPath() %>/manage-users.jsp#user-<%= b.tutorUserId %>" class="name-link">
                                        <%= EscapeUtil.html(b.tutorName) %>
                                    </a>
                                </td>
                                <td><%= b.bookingDate %></td>
                                <td><%= b.startTime %> &ndash; <%= b.endTime %></td>
                                <td><span class="status-pill status-<%= b.status %>"><%= b.status.replace('_', ' ') %></span></td>
                            </tr>
                        <% } %>
                    </tbody>
                </table>
                </div>
            <% } %>

        </div>
    </main>
</div>
</body>
</html>