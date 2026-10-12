<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="com.peertutorconnect.dao.BookingDAO" %>
<%@ page import="com.peertutorconnect.dao.AvailabilityDAO" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
<%@ page import="com.peertutorconnect.dao.RatingDAO" %>
<%@ page import="com.peertutorconnect.dao.NoShowDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"TUTOR".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    int userId = (int) session.getAttribute("userId");
    AvailabilityDAO availDAO = new AvailabilityDAO();
    Integer tutorId = availDAO.getTutorIdForUser(userId);

    TutorDAO tutorDAO = new TutorDAO();

    if (tutorId != null && !tutorDAO.isApplicationComplete(tutorId)) {
        response.sendRedirect(request.getContextPath() + "/complete-tutor-application.jsp");
        return;
    }

    boolean tutorIsVerified = (tutorId != null) && tutorDAO.isVerified(tutorId);

    List<BookingDAO.BookingRow> bookings = new ArrayList<>();
    List<BookingDAO.BookingRow> pendingList = new ArrayList<>();
    List<BookingDAO.BookingRow> upcomingList = new ArrayList<>();
    List<BookingDAO.BookingRow> awaitingPaymentList = new ArrayList<>();
    List<BookingDAO.BookingRow> paymentList = new ArrayList<>();
    List<BookingDAO.BookingRow> refundList = new ArrayList<>();

    String myPaysharp = (tutorId != null) ? tutorDAO.getPaysharpDetails(tutorId) : null;
    boolean hasPaysharp = myPaysharp != null && !myPaysharp.trim().isEmpty();

    if (tutorId != null) {
        BookingDAO bookingDAO = new BookingDAO();
        bookings = bookingDAO.getBookingsForTutor(tutorId);
        for (BookingDAO.BookingRow b : bookings) {
            if ("PENDING".equals(b.status)) pendingList.add(b);
            else if ("AWAITING_PAYMENT".equals(b.status)) awaitingPaymentList.add(b);
            else if ("PAYMENT_SUBMITTED".equals(b.status)) paymentList.add(b);
            else if ("CONFIRMED".equals(b.status)) upcomingList.add(b);
            else if ("CANCELLED_STUDENT".equals(b.status) && b.refundAmount > 0
                    && b.refundPaysharp != null && !b.refundPaysharp.trim().isEmpty()) refundList.add(b);
        }
    }

    // NOTE: average rating pulled via RatingDAO.getAverageRatingForTutor,
    // which reads the tutor.averageRating column.
    double avgRating = 0.0;
    if (tutorId != null) {
        try {
            avgRating = new RatingDAO().getAverageRatingForTutor(tutorId);
        } catch (Exception e) {
            avgRating = 0.0;
        }
    }

    String tutorName = (String) session.getAttribute("name");
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Tutor Dashboard</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .tdash-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            flex-wrap: wrap;
            gap: 14px;
            margin-bottom: 24px;
        }

        .tdash-header h1 {
            color: var(--navy);
            font-size: 1.6rem;
            margin-bottom: 6px;
        }

        .tdash-header p {
            color: var(--text-muted);
            font-size: 0.9rem;
        }

        .tdash-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 16px;
            margin-bottom: 32px;
        }

        .tdash-stat-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 18px 20px;
        }

        .tdash-stat-card .num {
            font-size: 1.7rem;
            font-weight: 700;
            color: var(--navy);
            line-height: 1.2;
        }

        .tdash-stat-card .lbl {
            font-size: 11px;
            font-weight: 600;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.03em;
            margin-top: 4px;
        }

        .tdash-section {
            margin-bottom: 32px;
        }

        .tdash-section h2 {
            font-family: 'Playfair Display', 'Segoe UI', Arial, sans-serif;
            font-size: 1.1rem;
            color: var(--navy);
            padding-bottom: 12px;
            border-bottom: 1px solid var(--border-light);
            margin-bottom: 14px;
        }

        .booking-row {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 14px 18px;
            margin-bottom: 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 12px;
        }

        .booking-row .booking-info {
            font-size: 14px;
        }

        .booking-row .booking-info strong {
            color: var(--navy);
        }

        .booking-row .booking-meta {
            font-size: 12px;
            color: var(--text-muted);
            margin-top: 2px;
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
        .status-DECLINED { background: #fbeae7; color: var(--error); }
        .status-COMPLETED { background: #e6edf5; color: var(--navy); }
        .status-CANCELLED_STUDENT, .status-CANCELLED_TUTOR, .status-EXPIRED { background: #eee; color: var(--text-muted); }
        .status-NO_SHOW_STUDENT { background: #fbeae7; color: var(--error); }
        .status-NO_SHOW_TUTOR { background: #fdf1de; color: #a2670e; }
        .btn-noshow { background: transparent; color: var(--error); border: 1px solid var(--error); padding: 8px 14px; border-radius: 4px; font-size: 13px; font-weight: 600; font-family: inherit; cursor: pointer; }
        .btn-noshow:hover { background: var(--error); color: white; }

        .booking-desc {
            font-size: 13px;
            margin-top: 6px;
            max-width: 520px;
            white-space: pre-wrap;
        }

        .proof-link {
            font-size: 12px;
            font-weight: 600;
            color: var(--navy);
        }

        .paysharp-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 18px 20px;
            margin-bottom: 32px;
        }

        .paysharp-card h2 {
            font-family: 'Playfair Display', 'Segoe UI', Arial, sans-serif;
            font-size: 1.1rem;
            color: var(--navy);
            margin-bottom: 6px;
        }

        .paysharp-card p { font-size: 13px; color: var(--text-muted); margin-bottom: 12px; }

        .paysharp-card form { display: flex; gap: 8px; flex-wrap: wrap; }

        .paysharp-card input[type=text] {
            flex: 1;
            min-width: 220px;
            padding: 8px 10px;
            font-size: 14px;
            font-family: inherit;
            border: 1px solid var(--border-light);
            border-radius: 4px;
        }

        .paysharp-warn { border-color: var(--orange); }

        .refund-amount { font-weight: 700; color: var(--navy); }

        .action-btns { display: flex; gap: 6px; flex-wrap: wrap; }

        .action-btns button {
            border: none;
            padding: 6px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
        }

        .btn-accept { background: var(--success); color: white; }
        .btn-decline { background: var(--error); color: white; }
        .btn-complete { background: var(--navy); color: white; }
        .btn-link { background: var(--orange); color: white; }
        .btn-remove-link { background: transparent; color: var(--error); border: 1px solid var(--error) !important; }

        .link-form {
            display: flex;
            gap: 6px;
            align-items: center;
        }

        .link-form input {
            font-size: 12px;
            padding: 6px 8px;
            width: 180px;
        }

        .link-display {
            font-size: 12px;
            display: flex;
            align-items: center;
            gap: 8px;
            flex-wrap: wrap;
        }

        .link-display a {
            color: var(--navy);
            font-weight: 600;
        }

        /* NFR-PORT-03: on narrow screens the fixed 180px input above pushes
           the booking-row into horizontal overflow. Stack the link-form
           instead. This block must stay AFTER the .link-form rules above
           so it wins the cascade at matching widths. */
        @media (max-width: 480px) {
            .link-form {
                flex-direction: column;
                align-items: stretch;
                width: 100%;
            }

            .link-form input {
                width: 100%;
            }
        }
    </style>
</head>
<body>

    <div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

    <div class="page-wrap" style="padding-top: 40px;">

        <div class="tdash-header">
            <div>
                <h1>
                    Welcome back, <%= EscapeUtil.html(tutorName) %>
                    <% if (tutorIsVerified) { %>
                        <span style="display:inline-flex;align-items:center;justify-content:center;width:16px;height:16px;background:#1a73e8;border-radius:50%;margin-left:6px;vertical-align:middle;flex-shrink:0;">
                            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
                        </span>
                    <% } else { %>
                        <span class="pending-badge" style="font-size: 12px; vertical-align: middle; margin-left: 6px;">Pending Review</span>
                    <% } %>
                </h1>
                <p>Here's what's happening with your sessions.</p>
            </div>
            <% if (tutorIsVerified) { %>
                <a href="manage-availability.jsp" class="btn btn-primary">+ Set availability</a>
            <% } %>
        </div>

        <% if (!tutorIsVerified) { %>
            <div class="empty-state" style="margin-bottom: 32px;">
                Your application has been submitted and is awaiting admin approval. You'll be notified once it's reviewed, and availability management will unlock at that point.
            </div>
        <% } %>

        <% if (tutorIsVerified && tutorId != null && !hasPaysharp) { %>
            <div class="paysharp-card paysharp-warn">
                <h2>Your PaySharp details</h2>
                <p><strong>Required:</strong> add your PaySharp details before you can accept booking requests. Students will see these to pay you. You can change them later under Profile.</p>
                <form method="post" action="<%= request.getContextPath() %>/tutor-paysharp">
                    <input type="text" name="paysharp" required minlength="5" maxlength="255"
                           placeholder="e.g. your PaySharp number, email or username">
                    <button type="submit" class="btn btn-primary">Save</button>
                </form>
            </div>
        <% } %>

        <div class="tdash-stats">
            <div class="tdash-stat-card">
                <div class="num"><%= bookings.size() %></div>
                <div class="lbl">Total Sessions</div>
            </div>
            <div class="tdash-stat-card">
                <div class="num"><%= pendingList.size() %></div>
                <div class="lbl">Pending Requests</div>
            </div>
            <div class="tdash-stat-card">
                <div class="num"><%= String.format("%.2f", avgRating) %></div>
                <div class="lbl">Average Rating</div>
            </div>
        </div>

        <% if (tutorId == null) { %>
            <div class="empty-state">No tutor profile found for this account.</div>
        <% } else { %>

            <!-- Pending requests -->
            <div class="tdash-section">
                <h2>Pending requests</h2>
                <% if (pendingList.isEmpty()) { %>
                    <div class="empty-state">No pending requests right now.</div>
                <% } else { %>
                    <% for (BookingDAO.BookingRow b : pendingList) { %>
                        <div class="booking-row">
                            <div class="booking-info">
                                <strong><%= EscapeUtil.html(b.otherPartyName) %></strong>
                                <div class="booking-meta"><%= b.bookingDate %> &middot; <%= b.startTime %> &ndash; <%= b.endTime %></div>
                                <% if (b.description != null && !b.description.trim().isEmpty()) { %>
                                    <div class="booking-desc"><strong>Needs help with:</strong> <%= EscapeUtil.html(b.description) %></div>
                                <% } %>
                            </div>
                            <div class="action-btns">
                                <form method="post" action="<%= request.getContextPath() %>/respond-booking">
                                    <input type="hidden" name="bookingId" value="<%= b.bookingId %>">
                                    <input type="hidden" name="action" value="accept">
                                    <button type="submit" class="btn-accept">Accept</button>
                                </form>
                                <form method="post" action="<%= request.getContextPath() %>/respond-booking">
                                    <input type="hidden" name="bookingId" value="<%= b.bookingId %>">
                                    <input type="hidden" name="action" value="decline">
                                    <button type="submit" class="btn-decline">Decline</button>
                                </form>
                            </div>
                        </div>
                    <% } %>
                <% } %>
            </div>

            <!-- Payment received: tutor checks the proof, then sends the Teams link to confirm -->
            <div class="tdash-section">
                <h2>Payment received &mdash; send the Teams link</h2>
                <% if (paymentList.isEmpty()) { %>
                    <div class="empty-state">No payments waiting for you.</div>
                <% } else { %>
                    <% for (BookingDAO.BookingRow b : paymentList) { %>
                        <div class="booking-row">
                            <div class="booking-info">
                                <strong><%= EscapeUtil.html(b.otherPartyName) %></strong>
                                <div class="booking-meta"><%= b.bookingDate %> &middot; <%= b.startTime %> &ndash; <%= b.endTime %></div>
                                <% if (b.description != null && !b.description.trim().isEmpty()) { %>
                                    <div class="booking-desc"><strong>Needs help with:</strong> <%= EscapeUtil.html(b.description) %></div>
                                <% } %>
                                <div style="margin-top:6px;">
                                    <a class="proof-link" href="<%= request.getContextPath() %>/payment-proof?bookingId=<%= b.bookingId %>" target="_blank">View proof of payment</a>
                                </div>
                            </div>
                            <form method="post" action="<%= request.getContextPath() %>/respond-booking" class="link-form">
                                <input type="hidden" name="bookingId" value="<%= b.bookingId %>">
                                <input type="hidden" name="action" value="send-link">
                                <input type="url" name="meetingLink" placeholder="Teams link" required>
                                <button type="submit" class="btn-link">Send link &amp; confirm</button>
                            </form>
                        </div>
                    <% } %>
                <% } %>
            </div>

            <!-- Refunds the tutor must send after a student cancelled a paid session -->
            <% if (!refundList.isEmpty()) { %>
            <div class="tdash-section">
                <h2>Refunds to send</h2>
                <% for (BookingDAO.BookingRow b : refundList) { %>
                    <div class="booking-row">
                        <div class="booking-info">
                            <strong><%= EscapeUtil.html(b.otherPartyName) %></strong>
                            <div class="booking-meta"><%= b.bookingDate %> &middot; <%= b.startTime %> &ndash; <%= b.endTime %></div>
                            <div class="booking-desc">Send <span class="refund-amount">R<%= String.format(java.util.Locale.US, "%.2f", b.refundAmount) %></span>
                                (50% of the session price) to the student's PaySharp:
                                <strong><%= EscapeUtil.html(b.refundPaysharp) %></strong></div>
                        </div>
                        <span class="status-pill status-CANCELLED_STUDENT">Cancelled by student</span>
                    </div>
                <% } %>
            </div>
            <% } %>

            <!-- Approved, waiting for the student to upload proof of payment -->
            <% if (!awaitingPaymentList.isEmpty()) { %>
            <div class="tdash-section">
                <h2>Approved &mdash; waiting for payment</h2>
                <% for (BookingDAO.BookingRow b : awaitingPaymentList) { %>
                    <div class="booking-row">
                        <div class="booking-info">
                            <strong><%= EscapeUtil.html(b.otherPartyName) %></strong>
                            <div class="booking-meta"><%= b.bookingDate %> &middot; <%= b.startTime %> &ndash; <%= b.endTime %></div>
                        </div>
                        <span class="status-pill status-AWAITING_PAYMENT">Awaiting payment</span>
                    </div>
                <% } %>
            </div>
            <% } %>

            <!-- Upcoming sessions -->
            <div class="tdash-section">
                <h2>Upcoming sessions</h2>
                <% if (upcomingList.isEmpty()) { %>
                    <div class="empty-state">No confirmed sessions yet.</div>
                <% } else { %>
                    <% for (BookingDAO.BookingRow b : upcomingList) { %>
                        <div class="booking-row">
                            <div class="booking-info">
                                <strong><%= EscapeUtil.html(b.otherPartyName) %></strong>
                                <div class="booking-meta"><%= b.bookingDate %> &middot; <%= b.startTime %> &ndash; <%= b.endTime %></div>
                                <% if (b.description != null && !b.description.trim().isEmpty()) { %>
                                    <div class="booking-desc"><strong>Needs help with:</strong> <%= EscapeUtil.html(b.description) %></div>
                                <% } %>
                            </div>
                            <div style="display:flex; align-items:center; gap:14px; flex-wrap:wrap;">
                                <% if (b.meetingLink != null && !b.meetingLink.trim().isEmpty()) { %>
                                    <div class="link-display">
                                        <a href="<%= EscapeUtil.html(b.meetingLink) %>" target="_blank">Open link</a>
                                        <form method="post" action="<%= request.getContextPath() %>/session-link" style="display:inline;">
                                            <input type="hidden" name="bookingId" value="<%= b.bookingId %>">
                                            <input type="hidden" name="action" value="remove">
                                            <button type="submit" class="btn-remove-link">Remove</button>
                                        </form>
                                    </div>
                                <% } else { %>
                                    <form method="post" action="<%= request.getContextPath() %>/session-link" class="link-form">
                                        <input type="hidden" name="bookingId" value="<%= b.bookingId %>">
                                        <input type="hidden" name="action" value="set">
                                        <input type="url" name="meetingLink" placeholder="Teams/Zoom link" required>
                                        <button type="submit" class="btn-link">Save</button>
                                    </form>
                                <% } %>
                                <%
                                    boolean canFlagNoShow = false;
                                    boolean canComplete = false;
                                    try {
                                        java.time.LocalDateTime sessionStart = java.time.LocalDateTime.of(
                                                java.time.LocalDate.parse(b.bookingDate),
                                                java.time.LocalTime.parse(b.startTime));
                                        java.time.LocalDateTime sessionEnd = java.time.LocalDateTime.of(
                                                java.time.LocalDate.parse(b.bookingDate),
                                                java.time.LocalTime.parse(b.endTime));
                                        canFlagNoShow = sessionStart.plusMinutes(NoShowDAO.GRACE_MINUTES)
                                                .isBefore(java.time.LocalDateTime.now());
                                        canComplete = !sessionEnd.isAfter(java.time.LocalDateTime.now());
                                    } catch (Exception ex) {
                                        canFlagNoShow = false;
                                        canComplete = false;
                                    }
                                %>
                                <% if (canComplete) { %>
                                <form method="post" action="<%= request.getContextPath() %>/respond-booking">
                                    <input type="hidden" name="bookingId" value="<%= b.bookingId %>">
                                    <input type="hidden" name="action" value="complete">
                                    <button type="submit" class="btn-complete">Mark Completed</button>
                                </form>
                                <% } else { %>
                                    <span style="font-size:12px;color:var(--text-muted);">Can be marked completed after the session ends</span>
                                <% } %>
                                <% if (canFlagNoShow) { %>
                                <form method="post" action="<%= request.getContextPath() %>/no-show"
                                      onsubmit="return confirm('Report this student as a no-show? An admin will review the report before any strike is given.');">
                                    <input type="hidden" name="bookingId" value="<%= b.bookingId %>">
                                    <input type="hidden" name="action" value="flag-student">
                                    <input type="text" name="note" maxlength="500" placeholder="Note (optional)"
                                           style="padding:7px 8px;font-size:13px;border:1px solid var(--border-light);border-radius:4px;">
                                    <button type="submit" class="btn-noshow">Student didn't show (report)</button>
                                </form>
                                <% } %>
                            </div>
                        </div>
                    <% } %>
                <% } %>
            </div>

        <% } %>

    </div>

       </main>
</div>

<% if ("true".equals(request.getParameter("success"))) { %>
    <script>showToast('Saved.', 'success');</script>
<% } %>
<% if ("true".equals(request.getParameter("noshowreported"))) { %>
    <script>showToast('No-show reported. An admin will review it before any strike is given.', 'success');</script>
<% } %>
<%
    String noShowErr = request.getParameter("noshowerror");
    if (noShowErr != null) {
        String noShowMsg;
        switch (noShowErr) {
            case "toosoon":      noShowMsg = "You can flag a no-show " + NoShowDAO.GRACE_MINUTES + " minutes after the session starts."; break;
            case "notflaggable": noShowMsg = "This session can't be flagged."; break;
            case "notfound":     noShowMsg = "That booking could not be found."; break;
            default:             noShowMsg = "Something went wrong. Please try again."; break;
        }
%>
    <script>showToast('<%= noShowMsg.replace("'", "\\'") %>', 'error');</script>
<% } %>
<% if ("toosoon".equals(request.getParameter("error"))) { %>
    <script>showToast('You can only mark a session completed after it has ended.', 'error');</script>
<% } %>
<% if ("notconfirmable".equals(request.getParameter("error"))) { %>
    <script>showToast('That booking can no longer be confirmed (the student may have cancelled).', 'error');</script>
<% } %>
<% if ("missinglink".equals(request.getParameter("error"))) { %>
    <script>showToast('Please enter a link before saving.', 'error');</script>
<% } %>
<% if ("true".equals(request.getParameter("applicationSubmitted"))) { %>
    <script>showToast('Application submitted! An admin will review it shortly.', 'success');</script>
<% } %>
<% if ("true".equals(request.getParameter("paysharpsaved"))) { %>
    <script>showToast('PaySharp details saved.', 'success');</script>
<% } %>
<% if ("invalid".equals(request.getParameter("paysharperror"))) { %>
    <script>showToast('Please enter your PaySharp details (5 to 255 characters).', 'error');</script>
<% } else if (request.getParameter("paysharperror") != null) { %>
    <script>showToast('Could not save your PaySharp details. Please try again.', 'error');</script>
<% } %>
<% if ("nopaysharp".equals(request.getParameter("error"))) { %>
    <script>showToast('Add your PaySharp details before accepting bookings.', 'error');</script>
<% } %>
<% if ("notverified".equals(request.getParameter("error"))) { %>
    <script>showToast('Your application needs to be approved before you can manage availability.', 'error');</script>
<% } %>

</body>
</html>