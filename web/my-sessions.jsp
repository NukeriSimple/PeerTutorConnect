<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.time.Duration" %>
<%@ page import="java.time.LocalDate" %>
<%@ page import="java.time.LocalDateTime" %>
<%@ page import="java.time.LocalTime" %>
<%@ page import="com.peertutorconnect.dao.BookingDAO" %>
<%@ page import="com.peertutorconnect.dao.NoShowDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"STUDENT".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    int userId = (int) session.getAttribute("userId");
    BookingDAO bookingDAO = new BookingDAO();
    Integer studentId = bookingDAO.getStudentIdForUser(userId);

    List<BookingDAO.BookingRow> allBookings = null;
    List<BookingDAO.BookingRow> upcoming = new ArrayList<>();
    List<BookingDAO.BookingRow> ongoing = new ArrayList<>();
    List<BookingDAO.BookingRow> past = new ArrayList<>();

    LocalDateTime nowTime = LocalDateTime.now();

    int myStrikes = 0;
    try {
        myStrikes = new NoShowDAO().getStrikes(userId);
    } catch (Exception e) {
        myStrikes = 0;
    }

    if (studentId != null) {
        allBookings = bookingDAO.getBookingsForStudent(studentId);

        for (BookingDAO.BookingRow b : allBookings) {
            boolean isFinishedStatus = "COMPLETED".equals(b.status)
                    || "DECLINED".equals(b.status)
                    || "CANCELLED_STUDENT".equals(b.status)
                    || "CANCELLED_TUTOR".equals(b.status)
                    || "NO_SHOW_STUDENT".equals(b.status)
                    || "NO_SHOW_TUTOR".equals(b.status)
                    || "EXPIRED".equals(b.status);

            if (isFinishedStatus) {
                past.add(b);
                continue;
            }

            // PENDING or CONFIRMED — classify by actual date/time
            try {
                LocalDate date = LocalDate.parse(b.bookingDate);
                LocalDateTime start = LocalDateTime.of(date, LocalTime.parse(b.startTime));
                LocalDateTime end = LocalDateTime.of(date, LocalTime.parse(b.endTime));

                if (nowTime.isBefore(start)) {
                    upcoming.add(b);
                } else if (nowTime.isBefore(end)) {
                    ongoing.add(b);
                } else {
                    // time has passed but status was never updated to COMPLETED
                    past.add(b);
                }
            } catch (Exception ex) {
                upcoming.add(b);
            }
        }
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
        .status-NO_SHOW_STUDENT { background: #fbeae7; color: var(--error); }
        .pay-form { display: flex; flex-direction: column; gap: 6px; margin-bottom: 8px; max-width: 220px; }
        .pay-form input[type=file] { font-size: 12px; width: 100%; }
        .pay-btn { background: var(--orange); color: white; border: none; padding: 6px 12px; border-radius: 4px; font-size: 12px; font-weight: 600; font-family: inherit; cursor: pointer; }
        .pay-note { font-size: 12px; color: var(--text-muted); margin-bottom: 6px; }
        .status-NO_SHOW_TUTOR { background: #fdf1de; color: #a2670e; }

        .strike-banner {
            background: #fbeae7;
            border: 1px solid var(--error);
            color: var(--error);
            padding: 10px 14px;
            border-radius: 4px;
            font-size: 13px;
            margin-bottom: 18px;
        }

        .noshow-btn {
            background: transparent;
            color: #a2670e;
            border: 1px solid #a2670e;
            padding: 6px 14px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            font-family: inherit;
            cursor: pointer;
        }

        .noshow-btn:hover {
            background: #a2670e;
            color: white;
        }

        .noshow-stars {
            display: flex;
            flex-direction: row-reverse;
            justify-content: flex-end;
            gap: 2px;
            margin: 6px 0 10px;
        }

        .noshow-stars input { display: none; }

        .noshow-stars label {
            font-size: 26px;
            color: var(--border-light);
            cursor: pointer;
        }

        .noshow-stars label:hover,
        .noshow-stars label:hover ~ label,
        .noshow-stars input:checked ~ label {
            color: var(--orange);
        }

        .rate-form {
            display: flex;
            flex-direction: column;
            gap: 6px;
            align-items: flex-start;
            max-width: 240px;
        }

        /* The written review only appears once a star rating is chosen. */
        .rate-review-wrap {
            display: none;
            width: 100%;
        }

        .star-rating:has(input:checked) ~ .rate-review-wrap {
            display: block;
        }

        .rate-review-wrap textarea {
            width: 100%;
            box-sizing: border-box;
            font-family: inherit;
            font-size: 12px;
            padding: 6px 8px;
        }

        .rate-form select {
            width: auto;
            padding: 6px 8px;
            font-size: 12px;
        }

        .rate-form button {
            background: var(--orange);
            color: white;
            border: none;
            padding: 6px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
        }

        .star-rating {
            display: flex;
            flex-direction: row-reverse;
            gap: 2px;
        }

        .star-rating input {
            display: none;
        }

        .star-rating label {
            font-size: 22px;
            color: var(--border-light);
            cursor: pointer;
            transition: color 0.15s ease;
        }

        .star-rating label:hover,
        .star-rating label:hover ~ label,
        .star-rating input:checked ~ label {
            color: var(--orange);
        }

        .join-link {
            display: inline-block;
            background: var(--navy);
            color: white;
            padding: 6px 14px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }

        .cancel-booking-btn {
            background: transparent;
            color: var(--error);
            border: 1px solid var(--error);
            padding: 6px 14px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
            font-family: inherit;
            cursor: pointer;
            transition: background-color 0.2s ease, color 0.2s ease;
        }

        .cancel-booking-btn:hover {
            background: var(--error);
            color: white;
        }

        .session-tabs {
            display: flex;
            gap: 8px;
            margin-bottom: 20px;
            border-bottom: 1px solid var(--border-light);
        }

        .session-tab {
            background: none;
            border: none;
            font-family: inherit;
            font-size: 14px;
            font-weight: 600;
            color: var(--text-muted);
            padding: 10px 16px;
            cursor: pointer;
            border-bottom: 3px solid transparent;
            margin-bottom: -1px;
        }

        .session-tab:hover {
            color: var(--navy);
        }

        .session-tab.active {
            color: var(--navy);
            border-bottom-color: var(--orange);
        }

        .session-tab .count {
            display: inline-block;
            background: var(--border-light);
            color: var(--navy);
            font-size: 11px;
            font-weight: 700;
            padding: 1px 7px;
            border-radius: 10px;
            margin-left: 6px;
        }

        .session-tab.active .count {
            background: var(--orange);
            color: white;
        }

        .session-section {
            display: none;
        }

        .session-section.active {
            display: block;
        }
    </style>
</head>
<body>

    <div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

    <div class="page-heading">
        <h1>My Sessions</h1>
        <p>Your upcoming, ongoing, and past tutoring sessions.</p>
    </div>

    <div class="page-wrap">

        <% if (myStrikes > 0) { %>
            <div class="strike-banner">
                You have <strong><%= myStrikes %> of <%= NoShowDAO.MAX_STRIKES %></strong> strikes for missed sessions.
                At <%= NoShowDAO.MAX_STRIKES %> strikes your account will be removed.
            </div>
        <% } %>

        <% if (studentId == null) { %>
            <div class="empty-state">No student profile found for this account.</div>
        <% } else { %>

            <div class="session-tabs">
                <button type="button" class="session-tab active" data-target="upcoming-section">
                    Upcoming <span class="count"><%= upcoming.size() %></span>
                </button>
                <button type="button" class="session-tab" data-target="ongoing-section">
                    Ongoing <span class="count"><%= ongoing.size() %></span>
                </button>
                <button type="button" class="session-tab" data-target="past-section">
                    Past <span class="count"><%= past.size() %></span>
                </button>
            </div>

            <%
                // Reused for each of the three sections below.
                java.util.Map<String, List<BookingDAO.BookingRow>> sections = new java.util.LinkedHashMap<>();
                sections.put("upcoming-section", upcoming);
                sections.put("ongoing-section", ongoing);
                sections.put("past-section", past);

                for (java.util.Map.Entry<String, List<BookingDAO.BookingRow>> entry : sections.entrySet()) {
                    String sectionId = entry.getKey();
                    List<BookingDAO.BookingRow> list = entry.getValue();
                    boolean isFirst = "upcoming-section".equals(sectionId);
            %>
                <div id="<%= sectionId %>" class="session-section <%= isFirst ? "active" : "" %>">
                    <% if (list.isEmpty()) { %>
                        <div class="empty-state">Nothing here yet.</div>
                    <% } else { %>
                        <div class="table-wrapper">
                        <table class="dash-table">
                            <thead>
                                <tr>
                                    <th>Tutor</th>
                                    <th>Date</th>
                                    <th>Time</th>
                                    <th>Status</th>
                                    <th>Meeting Link</th>
                                    <th>Rating</th>
                                    <th>Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% for (BookingDAO.BookingRow b : list) {
                                    String statusLabel = b.status;
                                    if ("CANCELLED_STUDENT".equals(b.status)) statusLabel = "Cancelled by you";
                                    else if ("CANCELLED_TUTOR".equals(b.status)) statusLabel = "Cancelled by tutor";
                                    else if ("NO_SHOW_STUDENT".equals(b.status)) statusLabel = "You didn't attend";
                                    else if ("NO_SHOW_TUTOR".equals(b.status)) statusLabel = "Tutor didn't attend";
                                    else if ("PENDING".equals(b.status)) statusLabel = "Waiting for tutor";
                                    else if ("AWAITING_PAYMENT".equals(b.status)) statusLabel = "Approved - upload payment";
                                    else if ("PAYMENT_SUBMITTED".equals(b.status)) statusLabel = "Payment sent - waiting for link";

                                    boolean canCancel = false;          // still before the 8-hour deadline
                                    boolean cancelClosed = false;       // deadline passed, session not started yet
                                    boolean canReportTutor = false;     // session started 15+ min ago, tutor never showed
                                    double cancelFee = 0;
                                    if (BookingDAO.isCancellableStatus(b.status)) {
                                        try {
                                            LocalDateTime start = LocalDateTime.of(
                                                    LocalDate.parse(b.bookingDate),
                                                    LocalTime.parse(b.startTime));
                                            if (start.isAfter(nowTime)) {
                                                if (!start.isBefore(nowTime.plusHours(BookingDAO.CANCEL_DEADLINE_HOURS))) {
                                                    canCancel = true;
                                                    if (BookingDAO.isFeeStatus(b.status)) {
                                                        long mins = Duration.between(LocalTime.parse(b.startTime), LocalTime.parse(b.endTime)).toMinutes();
                                                        cancelFee = b.hourlyRate * mins / 60.0 * BookingDAO.CANCEL_FEE_PERCENT;
                                                    }
                                                } else {
                                                    cancelClosed = true;
                                                }
                                            } else if ("CONFIRMED".equals(b.status) && !b.hasRating
                                                    && start.plusMinutes(NoShowDAO.GRACE_MINUTES).isBefore(nowTime)) {
                                                canReportTutor = true;
                                            }
                                        } catch (Exception ex) {
                                            canCancel = false;
                                        }
                                    }

                                    double sessionPrice = 0;
                                    try {
                                        sessionPrice = b.hourlyRate
                                                * Duration.between(LocalTime.parse(b.startTime), LocalTime.parse(b.endTime)).toMinutes() / 60.0;
                                    } catch (Exception ex) {
                                        sessionPrice = 0;
                                    }

                                    String shortStart = (b.startTime != null && b.startTime.length() >= 5) ? b.startTime.substring(0, 5) : b.startTime;
                                %>
                                    <tr>
                                        <td><%= EscapeUtil.html(b.otherPartyName) %></td>
                                        <td><%= b.bookingDate %></td>
                                        <td><%= b.startTime %> &ndash; <%= b.endTime %></td>
                                        <td>
                                            <span class="status-pill status-<%= b.status %>"><%= statusLabel %></span>
                                            <% if ("PENDING".equals(b.status) && b.description != null && !b.description.isEmpty()) { %>
                                                <div style="font-size:12px;color:var(--text-muted);margin-top:4px;max-width:220px;">
                                                    Your request: <%= EscapeUtil.html(b.description) %>
                                                </div>
                                            <% } %>
                                            <% if ("CANCELLED_STUDENT".equals(b.status)) { %>
                                                <div style="font-size:12px;color:var(--text-muted);margin-top:4px;">
                                                    <% if (b.cancelReason != null && !b.cancelReason.isEmpty()) { %>
                                                        Reason: <%= EscapeUtil.html(b.cancelReason) %><br>
                                                    <% } %>
                                                    <% if (b.cancellationFee > 0) { %>
                                                        Cancellation fee: R<%= String.format("%.2f", b.cancellationFee) %><br>
                                                        Refund: R<%= String.format("%.2f", b.refundAmount) %> to
                                                        <%= EscapeUtil.html(b.refundPaysharp == null ? "" : b.refundPaysharp) %>
                                                    <% } %>
                                                </div>
                                            <% } %>
                                        </td>
                                        <td>
                                            <% if ("CONFIRMED".equals(b.status)) { %>
                                                <% if (b.meetingLink != null && !b.meetingLink.trim().isEmpty()) { %>
                                                    <a href="<%= EscapeUtil.html(b.meetingLink) %>" target="_blank" class="join-link">Join Session</a>
                                                <% } else { %>
                                                    <span style="color: var(--text-muted); font-size: 12px;">Not added yet</span>
                                                <% } %>
                                            <% } else { %>
                                                <span style="color: var(--text-muted); font-size: 12px;">&mdash;</span>
                                            <% } %>
                                        </td>
                                        <td>
                                            <% if ("COMPLETED".equals(b.status) && !b.hasRating) { %>
                                                <form method="post" action="<%= request.getContextPath() %>/rate-session" class="rate-form">
                                                    <input type="hidden" name="bookingId" value="<%= b.bookingId %>">
                                                    <div class="star-rating">
                                                        <input type="radio" id="star5-<%= b.bookingId %>" name="stars" value="5" required>
                                                        <label for="star5-<%= b.bookingId %>">&#9733;</label>
                                                        <input type="radio" id="star4-<%= b.bookingId %>" name="stars" value="4">
                                                        <label for="star4-<%= b.bookingId %>">&#9733;</label>
                                                        <input type="radio" id="star3-<%= b.bookingId %>" name="stars" value="3">
                                                        <label for="star3-<%= b.bookingId %>">&#9733;</label>
                                                        <input type="radio" id="star2-<%= b.bookingId %>" name="stars" value="2">
                                                        <label for="star2-<%= b.bookingId %>">&#9733;</label>
                                                        <input type="radio" id="star1-<%= b.bookingId %>" name="stars" value="1">
                                                        <label for="star1-<%= b.bookingId %>">&#9733;</label>
                                                    </div>
                                                    <div class="rate-review-wrap">
                                                        <textarea name="comment" required maxlength="500" rows="3"
                                                                  placeholder="Write a short review of your session"></textarea>
                                                    </div>
                                                    <button type="submit">Submit rating &amp; review</button>
                                                </form>
                                            <% } else if (b.hasRating) { %>
                                                <span style="font-size: 12px; color: var(--text-muted);">Rated</span>
                                            <% } %>
                                        </td>
                                        <td>
                                            <% if ("AWAITING_PAYMENT".equals(b.status) || "PAYMENT_SUBMITTED".equals(b.status)) { %>
                                                <div class="pay-note" style="color:var(--navy);">
                                                    <strong>Amount to pay: R<%= String.format(java.util.Locale.US, "%.2f", sessionPrice) %></strong><br>
                                                    Pay to PaySharp:
                                                    <strong><%= (b.tutorPaysharp != null && !b.tutorPaysharp.trim().isEmpty())
                                                            ? EscapeUtil.html(b.tutorPaysharp) : "not provided yet - contact your tutor" %></strong>
                                                </div>
                                                <% if ("AWAITING_PAYMENT".equals(b.status)) { %>
                                                    <div class="pay-note">Your tutor approved this session. Pay using the details above, then upload your proof of payment (PDF, JPG or PNG, max 5 MB).</div>
                                                <% } else { %>
                                                    <div class="pay-note">Proof sent. <a href="<%= request.getContextPath() %>/payment-proof?bookingId=<%= b.bookingId %>" target="_blank">View</a>.
                                                        Wrong file? Upload again below.</div>
                                                <% } %>
                                                <form method="post" action="<%= request.getContextPath() %>/payment-proof"
                                                      enctype="multipart/form-data" class="pay-form">
                                                    <input type="hidden" name="bookingId" value="<%= b.bookingId %>">
                                                    <input type="file" name="proof" accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png" required>
                                                    <button type="submit" class="pay-btn"><%= "AWAITING_PAYMENT".equals(b.status) ? "Upload proof of payment" : "Replace proof" %></button>
                                                </form>
                                            <% } %>
                                            <% if (canCancel) { %>
                                                <button type="button" class="cancel-booking-btn"
                                                        data-booking-id="<%= b.bookingId %>"
                                                        data-tutor="<%= EscapeUtil.html(b.otherPartyName) %>"
                                                        data-date="<%= b.bookingDate %>"
                                                        data-time="<%= EscapeUtil.html(shortStart) %>"
                                                        data-late="<%= cancelFee > 0 %>"
                                                        data-fee="<%= String.format(java.util.Locale.US, "%.2f", cancelFee) %>">Cancel</button>
                                            <% } else if (cancelClosed) { %>
                                                <span style="color: var(--text-muted); font-size: 12px;">Cancellation closed<br>(less than <%= BookingDAO.CANCEL_DEADLINE_HOURS %>h to start)</span>
                                            <% } else if (canReportTutor) { %>
                                                <button type="button" class="noshow-btn"
                                                        data-booking-id="<%= b.bookingId %>"
                                                        data-tutor="<%= EscapeUtil.html(b.otherPartyName) %>">Tutor didn't show up</button>
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
            <% } %>

        <% } %>

    </div>

        </main>
</div>

<!-- Cancel booking confirmation popup -->
<div id="cancel-booking-modal" class="modal-overlay" role="dialog" aria-modal="true"
     aria-labelledby="cancel-booking-title" aria-describedby="cancel-booking-text">
    <div class="modal-box">
        <h3 id="cancel-booking-title">Cancel this session?</h3>
        <p id="cancel-booking-text"></p>
        <form id="cancel-booking-form" method="post" action="<%= request.getContextPath() %>/book">
            <input type="hidden" name="action" value="cancel">
            <input type="hidden" name="bookingId" id="cancel-booking-id" value="">
            <p id="cancel-fee-warning" style="display:none;color:var(--error);font-size:13px;font-weight:600;margin:10px 0;"></p>
            <label for="cancel-reason" style="display:block;font-size:13px;font-weight:600;margin:10px 0 4px;">
                Reason for cancelling <span style="color:var(--error);">*</span>
            </label>
            <div id="cancel-refund-wrap" style="display:none;">
                <label for="cancel-refund-payshap" style="display:block;font-size:13px;font-weight:600;margin:10px 0 4px;">
                    Your PaySharp details for the refund <span style="color:var(--error);">*</span>
                </label>
                <input type="text" id="cancel-refund-payshap" name="refundPayshap" maxlength="255"
                       style="width:100%;box-sizing:border-box;font-family:inherit;padding:8px;"
                       placeholder="Where should your 50% refund be sent?">
            </div>
            <textarea id="cancel-reason" name="reason" required maxlength="500" rows="3"
                      style="width:100%;box-sizing:border-box;font-family:inherit;padding:8px;"
                      placeholder="Please tell the tutor why you're cancelling"></textarea>
            <div class="modal-actions">
                <button type="button" id="cancel-booking-keep" class="btn btn-secondary">Keep booking</button>
                <button type="submit" id="cancel-booking-confirm" class="btn btn-danger">Yes, cancel booking</button>
            </div>
        </form>
    </div>
</div>

<!-- Tutor did not show up: rating + review are required -->
<div id="noshow-modal" class="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="noshow-title">
    <div class="modal-box">
        <h3 id="noshow-title">Tutor didn't show up?</h3>
        <p id="noshow-text"></p>
        <form id="noshow-form" method="post" action="<%= request.getContextPath() %>/no-show">
            <input type="hidden" name="action" value="tutor-absent">
            <input type="hidden" name="bookingId" id="noshow-booking-id" value="">
            <label style="display:block;font-size:13px;font-weight:600;margin-top:10px;">
                Your rating <span style="color:var(--error);">*</span>
            </label>
            <div class="noshow-stars">
                <input type="radio" id="ns5" name="stars" value="5" required><label for="ns5">&#9733;</label>
                <input type="radio" id="ns4" name="stars" value="4"><label for="ns4">&#9733;</label>
                <input type="radio" id="ns3" name="stars" value="3"><label for="ns3">&#9733;</label>
                <input type="radio" id="ns2" name="stars" value="2"><label for="ns2">&#9733;</label>
                <input type="radio" id="ns1" name="stars" value="1"><label for="ns1">&#9733;</label>
            </div>
            <label for="noshow-review" style="display:block;font-size:13px;font-weight:600;margin:4px 0;">
                Your review <span style="color:var(--error);">*</span>
            </label>
            <textarea id="noshow-review" name="review" required maxlength="500" rows="3"
                      style="width:100%;box-sizing:border-box;font-family:inherit;padding:8px;"
                      placeholder="Describe what happened"></textarea>
            <div class="modal-actions">
                <button type="button" id="noshow-cancel" class="btn btn-secondary">Back</button>
                <button type="submit" class="btn btn-danger">Submit report &amp; review</button>
            </div>
        </form>
    </div>
</div>

<script>
(function () {
    // --- Tutor no-show modal ---
    var nsModal = document.getElementById('noshow-modal');
    document.addEventListener('click', function (e) {
        var btn = e.target.closest ? e.target.closest('.noshow-btn') : null;
        if (btn) {
            document.getElementById('noshow-booking-id').value = btn.getAttribute('data-booking-id');
            document.getElementById('noshow-text').textContent = 'You are reporting that ' + btn.getAttribute('data-tutor')
                + ' did not attend your session. You must leave a rating and a short review.';
            document.getElementById('noshow-form').reset();
            nsModal.classList.add('open');
        }
    });
    document.getElementById('noshow-cancel').addEventListener('click', function () {
        nsModal.classList.remove('open');
    });
    nsModal.addEventListener('click', function (e) {
        if (e.target === nsModal) nsModal.classList.remove('open');
    });

    // --- Tab switching ---
    var tabs = document.querySelectorAll('.session-tab');
    tabs.forEach(function (tab) {
        tab.addEventListener('click', function () {
            tabs.forEach(function (t) { t.classList.remove('active'); });
            document.querySelectorAll('.session-section').forEach(function (s) { s.classList.remove('active'); });

            tab.classList.add('active');
            document.getElementById(tab.getAttribute('data-target')).classList.add('active');
        });
    });

    // --- Cancel booking modal (shared across all three tabs) ---
    var modal = document.getElementById('cancel-booking-modal');
    var text = document.getElementById('cancel-booking-text');
    var idField = document.getElementById('cancel-booking-id');
    var keepBtn = document.getElementById('cancel-booking-keep');
    var confirmBtn = document.getElementById('cancel-booking-confirm');
    var lastFocused = null;

    function openModal(btn) {
        lastFocused = btn;
        idField.value = btn.getAttribute('data-booking-id');
        text.textContent = 'Your session with ' + btn.getAttribute('data-tutor')
            + ' on ' + btn.getAttribute('data-date')
            + ' at ' + btn.getAttribute('data-time')
            + ' will be cancelled and the tutor will be notified.';

        var warn = document.getElementById('cancel-fee-warning');
        if (btn.getAttribute('data-late') === 'true') {
            warn.textContent = 'Cancelling after you have paid costs 50% of the session price: R'
                + btn.getAttribute('data-fee') + ' will be charged.';
            warn.style.display = 'block';
        } else {
            warn.style.display = 'none';
        }

        // A refund is only owed when the student already paid, so only then ask for PaySharp details.
        var refundWrap = document.getElementById('cancel-refund-wrap');
        var refundInput = document.getElementById('cancel-refund-paysharp');
        var paid = btn.getAttribute('data-late') === 'true';
        refundWrap.style.display = paid ? 'block' : 'none';
        refundInput.required = paid;
        refundInput.value = '';

        document.getElementById('cancel-reason').value = '';
        modal.classList.add('open');
        keepBtn.focus();
    }

    function closeModal() {
        modal.classList.remove('open');
        idField.value = '';
        if (lastFocused && lastFocused.focus) {
            lastFocused.focus();
        }
    }

    document.addEventListener('click', function (e) {
        var btn = e.target.closest ? e.target.closest('.cancel-booking-btn') : null;
        if (btn) {
            openModal(btn);
        }
    });

    keepBtn.addEventListener('click', closeModal);

    modal.addEventListener('click', function (e) {
        if (e.target === modal) closeModal();
    });

    document.getElementById('cancel-booking-form').addEventListener('submit', function () {
        confirmBtn.disabled = true;
        confirmBtn.textContent = 'Cancelling...';
    });

    document.addEventListener('keydown', function (e) {
        if (!modal.classList.contains('open')) return;

        if (e.key === 'Escape') {
            closeModal();
            return;
        }

        if (e.key === 'Tab') {
            if (e.shiftKey && document.activeElement === keepBtn) {
                e.preventDefault();
                confirmBtn.focus();
            } else if (!e.shiftKey && document.activeElement === confirmBtn) {
                e.preventDefault();
                keepBtn.focus();
            }
        }
    });
})();

function notify(message, type) {
    if (typeof showToast === 'function') {
        showToast(message, type);
    } else {
        alert(message);
    }
}
</script>

<% if ("true".equals(request.getParameter("paid"))) { %>
    <script>notify('Proof of payment sent. Your tutor will confirm the booking by sending the Teams link.', 'success');</script>
<% } %>

<%
    String payError = request.getParameter("payerror");
    if (payError != null) {
        String payMsg;
        switch (payError) {
            case "nofile":     payMsg = "Please choose a file to upload."; break;
            case "badfile":    payMsg = "Only PDF, JPG or PNG files up to 5 MB are allowed."; break;
            case "notallowed": payMsg = "Payment can't be uploaded for this booking right now."; break;
            case "invalid":    payMsg = "Invalid request."; break;
            default:           payMsg = "Something went wrong. Please try again."; break;
        }
%>
    <script>notify('<%= payMsg.replace("'", "\\'") %>', 'error');</script>
<% } %>

<% if ("true".equals(request.getParameter("rated"))) { %>
    <script>notify('Thanks for your rating and review.', 'success');</script>
<% } %>

<%
    String rateError = request.getParameter("rateerror");
    if (rateError != null) {
        String rateMsg;
        switch (rateError) {
            case "noreview":   rateMsg = "Please write a short review along with your rating."; break;
            case "badstars":   rateMsg = "Please choose a rating from 1 to 5 stars."; break;
            case "cannotrate": rateMsg = "This session can't be rated (it may already be rated)."; break;
            default:           rateMsg = "Something went wrong. Please try again."; break;
        }
%>
    <script>notify('<%= rateMsg.replace("'", "\\'") %>', 'error');</script>
<% } %>

<% if ("true".equals(request.getParameter("cancelled"))) {
       String feeParam = request.getParameter("fee");
       boolean hasFee = feeParam != null && feeParam.matches("\\d+\\.\\d{2}") && !"0.00".equals(feeParam);
%>
    <script>notify('Your booking has been cancelled.<%= hasFee ? " A cancellation fee of R" + feeParam + " applies." : "" %>', 'success');</script>
<% } %>

<% if ("true".equals(request.getParameter("tutorabsent"))) { %>
    <script>notify('Thanks. Your report and review were submitted.', 'success');</script>
<% } %>

<%
    String noShowError = request.getParameter("noshowerror");
    if (noShowError != null) {
        String nsMsg;
        switch (noShowError) {
            case "norating":     nsMsg = "Please choose a star rating."; break;
            case "noreview":     nsMsg = "Please write a short review."; break;
            case "toosoon":      nsMsg = "You can report a no-show " + NoShowDAO.GRACE_MINUTES + " minutes after the session starts."; break;
            case "alreadyrated": nsMsg = "You already rated this session."; break;
            case "notflaggable": nsMsg = "This session can't be reported."; break;
            default:             nsMsg = "Something went wrong. Please try again."; break;
        }
%>
    <script>notify('<%= nsMsg.replace("'", "\\'") %>', 'error');</script>
<% } %>

<%
    String cancelError = request.getParameter("cancelerror");
    if (cancelError != null) {
        String cancelErrorMsg;
        switch (cancelError) {
            case "notfound":       cancelErrorMsg = "That booking could not be found."; break;
            case "notcancellable": cancelErrorMsg = "This booking can no longer be cancelled."; break;
            case "started":        cancelErrorMsg = "This session has already started, so it can't be cancelled."; break;
            case "tooclose":       cancelErrorMsg = "Sessions can only be cancelled at least " + BookingDAO.CANCEL_DEADLINE_HOURS + " hours before they start."; break;
            case "norefund":       cancelErrorMsg = "Please enter your PaySharp details so we can send your refund."; break;
            case "noreason":       cancelErrorMsg = "Please give a reason for cancelling."; break;
            case "invalid":        cancelErrorMsg = "Invalid cancellation request."; break;
            default:               cancelErrorMsg = "Something went wrong. Please try again."; break;
        }
%>
    <script>notify('<%= cancelErrorMsg.replace("'", "\\'") %>', 'error');</script>
<% } %>

</body>
</html>