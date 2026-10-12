<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.BookingDAO" %>
<%@ page import="com.peertutorconnect.dao.AvailabilityDAO" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"TUTOR".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    int userId = (int) session.getAttribute("userId");
    AvailabilityDAO availDAO = new AvailabilityDAO();
    Integer tutorId = availDAO.getTutorIdForUser(userId);

    if (tutorId != null && !new TutorDAO().isApplicationComplete(tutorId)) {
        response.sendRedirect(request.getContextPath() + "/complete-tutor-application.jsp");
        return;
    }

    List<BookingDAO.BookingRow> bookings = null;
    if (tutorId != null) {
        BookingDAO bookingDAO = new BookingDAO();
        bookings = bookingDAO.getBookingsForTutor(tutorId);
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; My Sessions</title>
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
            vertical-align: middle;
        }

        .dash-table th {
            background: var(--cream);
            color: var(--navy);
            font-size: 12px;
            text-transform: uppercase;
        }

        .dash-table tr.row-inactive td {
            color: var(--text-muted);
        }

        .dash-table tr:last-child td { border-bottom: none; }

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
    </style>
</head>
<body>

    <div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

    <div class="page-heading">
        <h1>My Sessions</h1>
        <p>Full history of your booking requests and sessions.</p>
    </div>

    <div class="page-wrap">

        <% if (tutorId == null) { %>
            <div class="empty-state">No tutor profile found for this account.</div>
        <% } else if (bookings.isEmpty()) { %>
            <div class="empty-state">No bookings yet.</div>
        <% } else { %>
            <div class="table-wrapper">
            <table class="dash-table">
                <thead>
                    <tr>
                        <th>Student</th>
                        <th>Date</th>
                        <th>Time</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    <% for (BookingDAO.BookingRow b : bookings) {
                        String statusLabel = b.status;
                        if ("CANCELLED_STUDENT".equals(b.status)) statusLabel = "Cancelled by student";
                        else if ("CANCELLED_TUTOR".equals(b.status)) statusLabel = "Cancelled by you";
                        else if ("AWAITING_PAYMENT".equals(b.status)) statusLabel = "Awaiting payment";
                        else if ("PAYMENT_SUBMITTED".equals(b.status)) statusLabel = "Payment received";

                        boolean inactive = "CANCELLED_STUDENT".equals(b.status)
                                || "CANCELLED_TUTOR".equals(b.status)
                                || "DECLINED".equals(b.status)
                                || "EXPIRED".equals(b.status);
                    %>
                        <tr class="<%= inactive ? "row-inactive" : "" %>">
                            <td><%= EscapeUtil.html(b.otherPartyName) %></td>
                            <td><%= b.bookingDate %></td>
                            <td><%= b.startTime %> &ndash; <%= b.endTime %></td>
                            <td>
                                <span class="status-pill status-<%= b.status %>"><%= statusLabel %></span>
                                <% if ("CANCELLED_STUDENT".equals(b.status) && b.refundAmount > 0) { %>
                                    <div style="font-size:12px;color:var(--text-muted);margin-top:4px;">
                                        Refund R<%= String.format(java.util.Locale.US, "%.2f", b.refundAmount) %> to PaySharp:
                                        <%= EscapeUtil.html(b.refundPaysharp == null ? "" : b.refundPaysharp) %>
                                    </div>
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

</body>
</html>