<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.*" %>
<%@ page import="java.time.LocalDate" %>
<%@ page import="java.time.LocalDateTime" %>
<%@ page import="java.time.LocalTime" %>
<%@ page import="com.peertutorconnect.dao.BookingDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"STUDENT".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    int userId = (int) session.getAttribute("userId");
    BookingDAO bookingDAO = new BookingDAO();
    Integer studentId = bookingDAO.getStudentIdForUser(userId);

    List<BookingDAO.BookingRow> allBookings = new ArrayList<>();
    if (studentId != null) {
        allBookings = bookingDAO.getBookingsForStudent(studentId);
    }

    String studentName = (String) session.getAttribute("name");
    LocalDateTime nowTime = LocalDateTime.now();

    int totalSessions = 0;
    List<BookingDAO.BookingRow> upcomingList = new ArrayList<>();

    // tutorId -> [display name, session count]
    Map<Integer, Object[]> tutorCounts = new LinkedHashMap<>();

    for (BookingDAO.BookingRow b : allBookings) {

        if ("CONFIRMED".equals(b.status) || "COMPLETED".equals(b.status)) {
            totalSessions++;

            Object[] entry = tutorCounts.get(b.tutorId);
            if (entry == null) {
                tutorCounts.put(b.tutorId, new Object[]{ b.otherPartyName, 1 });
            } else {
                entry[1] = ((Integer) entry[1]) + 1;
            }
        }

        if ("PENDING".equals(b.status) || "AWAITING_PAYMENT".equals(b.status)
                || "PAYMENT_SUBMITTED".equals(b.status) || "CONFIRMED".equals(b.status)) {
            try {
                LocalDateTime start = LocalDateTime.of(
                        LocalDate.parse(b.bookingDate),
                        LocalTime.parse(b.startTime));
                if (start.isAfter(nowTime)) {
                    upcomingList.add(b);
                }
            } catch (Exception ex) {
                // skip unparsable rows rather than miscounting
            }
        }
    }

    // Soonest first, cap the preview at 3
    upcomingList.sort((a, c) -> (a.bookingDate + a.startTime).compareTo(c.bookingDate + c.startTime));
    List<BookingDAO.BookingRow> upcomingPreview = upcomingList.subList(0, Math.min(3, upcomingList.size()));

    // Top 3 most-booked tutors, by session count descending
    List<Map.Entry<Integer, Object[]>> tutorList = new ArrayList<>(tutorCounts.entrySet());
    tutorList.sort((a, c) -> ((Integer) c.getValue()[1]).compareTo((Integer) a.getValue()[1]));
    List<Map.Entry<Integer, Object[]>> topTutors = tutorList.subList(0, Math.min(3, tutorList.size()));
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; My Dashboard</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .dash-top {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 28px;
            gap: 16px;
            flex-wrap: wrap;
        }

        .dash-top h1 {
            color: var(--navy);
            font-size: 1.5rem;
            margin-bottom: 4px;
        }

        .dash-top p {
            color: var(--text-muted);
            font-size: 0.9rem;
        }

        .stat-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 16px;
            margin-bottom: 32px;
        }

        /* Every card is a link: no underline, keep the card's own colours, lift slightly on hover. */
        a.stat-card,
        a.session-preview-row,
        a.go-to-tutor-row {
            text-decoration: none;
            color: inherit;
            cursor: pointer;
            transition: border-color 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
        }

        a.stat-card:hover,
        a.session-preview-row:hover,
        a.go-to-tutor-row:hover {
            border-color: var(--orange);
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            transform: translateY(-1px);
        }

        .stat-card {
            display: block;
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 8px;
            padding: 20px 22px;
        }

        .stat-card .stat-number {
            font-size: 1.8rem;
            font-weight: 700;
            color: var(--navy);
            margin-bottom: 4px;
        }

        .stat-card .stat-label {
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.03em;
            color: var(--text-muted);
            font-weight: 600;
        }

        .dash-section {
            margin-bottom: 36px;
        }

        .dash-section-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid var(--border-light);
            padding-bottom: 10px;
            margin-bottom: 14px;
        }

        .dash-section-header h2 {
            color: var(--navy);
            font-size: 1.15rem;
        }

        .dash-section-more {
            width: 30px;
            height: 30px;
            border-radius: 50%;
            background: #cfd6de;
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 14px;
            font-weight: 700;
            flex-shrink: 0;
        }

        .dash-section-more:hover {
            background: var(--navy);
        }

        .session-preview-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 14px 18px;
            margin-bottom: 10px;
            font-size: 14px;
            gap: 12px;
            flex-wrap: wrap;
        }

        .session-preview-row .sp-tutor {
            font-weight: 600;
            color: var(--navy);
        }

        .session-preview-row .sp-when {
            color: var(--text-muted);
            font-size: 13px;
        }

        .status-pill {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 3px;
            font-size: 12px;
            font-weight: 600;
        }

        .status-PENDING { background: #fdf1de; color: #a2670e; }
        .status-AWAITING_PAYMENT { background: #fdf1de; color: #a2670e; }
        .status-PAYMENT_SUBMITTED { background: #e6edf5; color: var(--navy); }
        .status-CONFIRMED { background: #eaf5ee; color: var(--success); }

        .go-to-tutor-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 14px 18px;
            margin-bottom: 10px;
            font-size: 14px;
        }

        .go-to-tutor-row .gt-name {
            font-weight: 600;
            color: var(--navy);
        }

        .go-to-tutor-row .gt-count {
            color: var(--text-muted);
            font-size: 13px;
        }

        .empty-inline {
            padding: 24px 0;
            text-align: center;
            color: var(--text-muted);
            font-size: 14px;
        }

        .empty-inline a {
            color: var(--orange);
            font-weight: 600;
        }
    </style>
</head>
<body>

    <div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

    <div class="page-wrap" style="padding-top: 32px;">

        <div class="dash-top">
            <div>
                <h1>Welcome back, <%= EscapeUtil.html(studentName) %></h1>
                <p>Ready for your next learning session?</p>
            </div>
            <a href="<%= request.getContextPath() %>/search-tutors.jsp" class="btn btn-primary">+ Book a session</a>
        </div>

        <div class="stat-cards">
            <a class="stat-card" href="<%= request.getContextPath() %>/my-sessions.jsp" title="View all sessions">
                <div class="stat-number"><%= totalSessions %></div>
                <div class="stat-label">Total Sessions</div>
            </a>
            <a class="stat-card" href="<%= request.getContextPath() %>/my-sessions.jsp" title="View upcoming sessions">
                <div class="stat-number"><%= upcomingList.size() %></div>
                <div class="stat-label">Upcoming</div>
            </a>
        </div>

        <div class="dash-section">
            <div class="dash-section-header">
                <h2>Upcoming sessions</h2>
                <a href="<%= request.getContextPath() %>/my-sessions.jsp" class="dash-section-more" title="View all sessions">&rsaquo;</a>
            </div>

            <% if (upcomingPreview.isEmpty()) { %>
                <div class="empty-inline">
                    No upcoming sessions. <a href="<%= request.getContextPath() %>/search-tutors.jsp">Find a tutor</a> to book one.
                </div>
            <% } else { %>
                <% for (BookingDAO.BookingRow b : upcomingPreview) {
                    String shortStart = (b.startTime != null && b.startTime.length() >= 5) ? b.startTime.substring(0, 5) : b.startTime;
                    String shortEnd = (b.endTime != null && b.endTime.length() >= 5) ? b.endTime.substring(0, 5) : b.endTime;
                %>
                    <a class="session-preview-row" href="<%= request.getContextPath() %>/my-sessions.jsp" title="Open this session in My Sessions">
                        <div>
                            <div class="sp-tutor"><%= EscapeUtil.html(b.otherPartyName) %></div>
                            <div class="sp-when"><%= b.bookingDate %> &middot; <%= shortStart %>&ndash;<%= shortEnd %></div>
                        </div>
                        <span class="status-pill status-<%= b.status %>"><%= b.status.replace('_', ' ') %></span>
                    </a>
                <% } %>
            <% } %>
        </div>

        <div class="dash-section">
            <div class="dash-section-header">
                <h2>Your go-to tutors</h2>
            </div>

            <% if (topTutors.isEmpty()) { %>
                <div class="empty-inline">
                    Once you've booked a few sessions, your most-booked tutors will show up here.
                </div>
            <% } else { %>
                <% for (Map.Entry<Integer, Object[]> entry : topTutors) {
                    int tId = entry.getKey();
                    String tName = (String) entry.getValue()[0];
                    int tCount = (Integer) entry.getValue()[1];
                %>
                    <a class="go-to-tutor-row" href="<%= request.getContextPath() %>/book-session.jsp?tutorId=<%= tId %>" title="Book another session with this tutor">
                        <span class="gt-name"><%= EscapeUtil.html(tName) %></span>
                        <span class="gt-count"><%= tCount %> session<%= tCount == 1 ? "" : "s" %></span>
                    </a>
                <% } %>
            <% } %>
        </div>

    </div>

        </main>
</div>

</body>
</html>