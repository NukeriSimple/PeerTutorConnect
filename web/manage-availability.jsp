<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.AvailabilityDAO" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
<%
    if (session.getAttribute("role") == null || !"TUTOR".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    int userId = (int) session.getAttribute("userId");
    AvailabilityDAO dao = new AvailabilityDAO();
    Integer tutorId = dao.getTutorIdForUser(userId);

    TutorDAO tutorDAO = new TutorDAO();

    if (tutorId != null && !tutorDAO.isApplicationComplete(tutorId)) {
        response.sendRedirect(request.getContextPath() + "/complete-tutor-application.jsp");
        return;
    }

    if (tutorId != null && !tutorDAO.isVerified(tutorId)) {
        response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp");
        return;
    }

    List<AvailabilityDAO.Slot> slots = null;
    if (tutorId != null) {
        slots = dao.getSlotsForTutor(tutorId);
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Manage Availability</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .avail-form {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 20px;
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            align-items: end;
            margin-bottom: 28px;
        }

        .avail-form .field {
            flex: 1;
            min-width: 140px;
        }

        .avail-form input[readonly] {
            background: var(--cream);
            cursor: not-allowed;
        }

        .slot-table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            overflow: hidden;
        }

        .slot-table th, .slot-table td {
            text-align: left;
            padding: 12px 16px;
            font-size: 14px;
            border-bottom: 1px solid var(--border-light);
        }

        .slot-table th {
            background: var(--cream);
            color: var(--navy);
            font-size: 12px;
            text-transform: uppercase;
        }

        .badge {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 3px;
            font-size: 12px;
            font-weight: 600;
        }

        .badge-open {
            background: #eaf5ee;
            color: var(--success);
        }

        .badge-booked {
            background: #fbeae7;
            color: var(--error);
        }

        .form-success {
            background: #eaf5ee;
            border: 1px solid var(--success);
            color: var(--success);
            padding: 10px 14px;
            border-radius: 4px;
            font-size: 13px;
            margin-bottom: 18px;
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
    </style>
</head>
<body>

    <div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

    <div class="page-heading">
        <h1>Manage Availability</h1>
        <p>Add one-hour time slots students can book, or remove ones you no longer want open.</p>
    </div>

    <div class="page-wrap">

        <% if ("true".equals(request.getParameter("success"))) { %>
            <div class="form-success">Saved.</div>
        <% } %>
        <% if ("missing".equals(request.getParameter("error"))) { %>
            <div class="form-error">Please fill in all fields.</div>
        <% } %>
        <% if ("db".equals(request.getParameter("error"))) { %>
            <div class="form-error">Something went wrong saving that. Try again.</div>
        <% } %>
        <% if ("hours".equals(request.getParameter("error"))) { %>
            <div class="form-error">Slots are exactly one hour long, and the start time can be no later than 23:00 so the slot ends on the same day.</div>
        <% } %>
        <% if ("notutor".equals(request.getParameter("error"))) { %>
            <div class="form-error">No tutor profile found for this account.</div>
        <% } %>

        <form method="post" action="<%= request.getContextPath() %>/availability" class="avail-form">
            <input type="hidden" name="action" value="add">
            <div class="field">
                <label for="date">Date</label>
                <input type="date" id="date" name="date" required>
            </div>
            <div class="field">
                <label for="startTime">Start Time</label>
                <input type="time" id="startTime" name="startTime" max="23:00" required>
            </div>
            <div class="field">
                <label for="endTime">End Time (1 hour later)</label>
                <input type="time" id="endTime" name="endTime" readonly tabindex="-1">
            </div>
            <button type="submit" class="btn btn-primary">Add Slot</button>
        </form>

        <% if (tutorId == null) { %>
            <div class="empty-state">No tutor profile found for this account.</div>
        <% } else if (slots.isEmpty()) { %>
            <div class="empty-state">No availability slots yet. Add one above.</div>
        <% } else { %>
            <table class="slot-table">
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Start</th>
                        <th>End</th>
                        <th>Status</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    <% for (AvailabilityDAO.Slot s : slots) { %>
                        <tr>
                            <td><%= s.date %></td>
                            <td><%= s.startTime %></td>
                            <td><%= s.endTime %></td>
                            <td>
                                <% if (s.isBooked) { %>
                                    <span class="badge badge-booked">Booked</span>
                                <% } else { %>
                                    <span class="badge badge-open">Open</span>
                                <% } %>
                            </td>
                            <td>
                                <% if (!s.isBooked) { %>
                                    <form method="post" action="<%= request.getContextPath() %>/availability" style="display:inline;">
                                        <input type="hidden" name="action" value="delete">
                                        <input type="hidden" name="availabilityId" value="<%= s.availabilityId %>">
                                        <button type="submit" class="btn btn-outline" style="color: var(--error); border-color: var(--error); padding: 6px 14px; font-size: 12px;">Remove</button>
                                    </form>
                                <% } %>
                            </td>
                        </tr>
                    <% } %>
                </tbody>
            </table>
        <% } %>

    </div>

        </main>
</div>

<script>
    // End time is always start + 1 hour (e.g. 11:50 -> 12:50).
    (function () {
        var startInput = document.getElementById('startTime');
        var endInput = document.getElementById('endTime');

        function updateEnd() {
            var value = startInput.value;
            if (!value) {
                endInput.value = '';
                return;
            }
            var parts = value.split(':');
            var hours = parseInt(parts[0], 10);
            var minutes = parseInt(parts[1], 10);
            if (hours >= 23 && minutes > 0) {
                endInput.value = '';
                startInput.setCustomValidity('Start time can be no later than 23:00.');
                return;
            }
            startInput.setCustomValidity('');
            var endHours = (hours + 1) % 24;
            endInput.value = String(endHours).padStart(2, '0') + ':' + String(minutes).padStart(2, '0');
        }

        startInput.addEventListener('input', updateEnd);
        startInput.addEventListener('change', updateEnd);
        updateEnd();
    })();
</script>

</body>
</html>