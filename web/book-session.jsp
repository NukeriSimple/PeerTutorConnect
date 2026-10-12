<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
<%@ page import="com.peertutorconnect.dao.AvailabilityDAO" %>
<%@ page import="com.peertutorconnect.dao.RatingDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    String tutorIdParam = request.getParameter("tutorId");
    if (tutorIdParam == null || tutorIdParam.trim().isEmpty()) {
        response.sendRedirect(request.getContextPath() + "/search-tutors.jsp");
        return;
    }
    int tutorId = Integer.parseInt(tutorIdParam);

    TutorDAO tutorDAO = new TutorDAO();
    TutorDAO.TutorSearchResult tutor = tutorDAO.getTutorById(tutorId);

    if (tutor == null || !tutor.isVerified) {
        response.sendRedirect(request.getContextPath() + "/search-tutors.jsp");
        return;
    }

    AvailabilityDAO availDAO = new AvailabilityDAO();
    List<AvailabilityDAO.Slot> openSlots = availDAO.getOpenSlotsForTutor(tutorId);

    // Only whole-hour slots can be booked
    List<AvailabilityDAO.Slot> hourSlots = new ArrayList<>();
    for (AvailabilityDAO.Slot sl : openSlots) {
        if (AvailabilityDAO.isWholeHours(sl.startTime, sl.endTime)) {
            hourSlots.add(sl);
        }
    }
    openSlots = hourSlots;

    List<RatingDAO.Review> reviews = new RatingDAO().getReviewsForTutor(tutorId);
    int reviewCount = reviews.size();

    boolean isLoggedInStudent = session.getAttribute("role") != null && "STUDENT".equals(session.getAttribute("role"));
%>
<!DOCTYPE html>
<html>
    <head>
        <title>Book a Session &mdash; <%= EscapeUtil.html(tutor.name)%></title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="css/style.css">
        <style>
            .book-layout {
                display: flex;
                gap: 28px;
                flex-wrap: wrap;
            }

            .tutor-summary {
                flex: 1;
                min-width: 240px;
                background: white;
                border: 1px solid var(--border-light);
                border-radius: 6px;
                padding: 22px;
                height: fit-content;
            }

            .tutor-summary .tutor-avatar {
                width: 56px;
                height: 56px;
                font-size: 1.1rem;
            }

            .booking-panel {
                flex: 2;
                min-width: 280px;
            }

            .slot-option {
                display: block;
                background: white;
                border: 1px solid var(--border-light);
                border-radius: 6px;
                padding: 14px 18px;
                margin-bottom: 10px;
                cursor: pointer;
            }

            .slot-option input {
                width: auto;
                display: inline-block;
                margin-right: 10px;
            }

            .slot-option:has(input:checked) {
                border-color: var(--navy);
                background: var(--cream);
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

            .tab-bar {
                display: flex;
                gap: 4px;
                border-bottom: 2px solid var(--border-light);
                margin-bottom: 18px;
            }

            .tab-btn {
                background: none;
                border: none;
                border-bottom: 3px solid transparent;
                margin-bottom: -2px;
                padding: 10px 18px;
                font-size: 14px;
                font-weight: 600;
                font-family: inherit;
                color: var(--text-muted);
                cursor: pointer;
            }

            .tab-btn:hover { color: var(--navy); }

            .tab-btn.active {
                color: var(--navy);
                border-bottom-color: var(--orange);
            }

            .tab-panel { display: none; }
            .tab-panel.active { display: block; }

            .review-summary {
                display: flex;
                align-items: center;
                gap: 10px;
                margin-bottom: 8px;
                padding-bottom: 14px;
                border-bottom: 1px solid var(--border-light);
                font-size: 13px;
                color: var(--text-muted);
            }

            .review-summary .big {
                font-size: 1.6rem;
                font-weight: bold;
                color: var(--navy);
            }

            .review-card {
                background: white;
                border: 1px solid var(--border-light);
                border-radius: 6px;
                padding: 14px 18px;
                margin-bottom: 10px;
            }

            .review-head {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 6px;
            }

            .review-name { font-weight: 600; font-size: 13px; color: var(--text-dark); }
            .review-stars { color: var(--orange); font-size: 14px; }
            .review-date { font-size: 11px; color: var(--text-muted); }
            .review-comment { font-size: 13px; color: var(--text-dark); margin-top: 4px; }
        </style>
    </head>
    <body>

        <% boolean navIsLoggedIn = session.getAttribute("role") != null; %>
        <% if (navIsLoggedIn) { %>
        <div class="app-shell">
            <jsp:include page="includes/sidebar.jsp" />
            <main class="app-main">
                <% } else { %>
                <jsp:include page="includes/header.jsp" />
                <% } %>

                <div class="page-heading">
                    <h1>Book a Session</h1>
                    <p>Choose an available time slot with this tutor.</p>
                </div>

                <div class="page-wrap">

                    <% if ("true".equals(request.getParameter("success"))) { %>
                    <div class="form-success">Booking request sent. The tutor will approve or decline it. If approved, you'll be asked to upload proof of payment in My Sessions, and the booking is confirmed once the tutor sends the Teams link.</div>
                    <% } %>
                    <% if ("slottaken".equals(request.getParameter("error"))) { %>
                    <div class="form-error">That slot was just booked by someone else. Please choose another.</div>
                    <% } %>
                    <% if ("wholehour".equals(request.getParameter("error"))) { %>
                    <div class="form-error">Sessions can only be booked in whole hours.</div>
                    <% } %>
                    <% if ("noslots".equals(request.getParameter("error"))) { %>
                    <div class="form-error">Please select at least one time slot.</div>
                    <% } %>
                    <% if ("nodescription".equals(request.getParameter("error"))) { %>
                    <div class="form-error">Please describe what you need help with.</div>
                    <% } %>
                    <% if ("notconsecutive".equals(request.getParameter("error"))) { %>
                    <div class="form-error">The slots you chose must be on the same day and follow each other without gaps.</div>
                    <% } %>
                    <% if ("toomany".equals(request.getParameter("error"))) { %>
                    <div class="form-error">You can book at most <%= com.peertutorconnect.dao.BookingDAO.MAX_SLOTS_PER_BOOKING %> slots at a time.</div>
                    <% } %>
                    <% if ("wrongtutor".equals(request.getParameter("error")) || "notfound".equals(request.getParameter("error"))) { %>
                    <div class="form-error">One of those slots is no longer available. Please choose again.</div>
                    <% } %>
                    <% if ("nostudent".equals(request.getParameter("error"))) { %>
                    <div class="form-error">No student profile found for this account.</div>
                    <% } %>

                    <div class="book-layout">

                        <div class="tutor-summary">
                            <%
                                String initials = "";
                                for (String part : tutor.name.trim().split("\\s+")) {
                                    if (!part.isEmpty()) {
                                        initials += part.charAt(0);
                                    }
                                }
                            %>
                            <div class="tutor-avatar"><%= EscapeUtil.html(initials.toUpperCase())%></div>
                            <h3 style="color: var(--navy); margin-bottom: 6px;">
                                <%= EscapeUtil.html(tutor.name)%>
                                <% if (tutor.isVerified) { %>
                                    <span style="display:inline-flex;align-items:center;justify-content:center;width:15px;height:15px;background:#1a73e8;border-radius:50%;margin-left:4px;vertical-align:middle;flex-shrink:0;">
                                        <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
                                    </span>
                                <% } %>
                            </h3>
                            <div class="tutor-rating" style="margin: 10px 0;">
                                <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.5 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.5 12 2"/></svg>
                                <%= String.format("%.2f", tutor.averageRating)%> (<%= reviewCount %>)
                            </div>
                            <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 10px;"><%= tutor.subjects%></p>
                            <% if (tutor.bio != null && !tutor.bio.trim().isEmpty()) {%>
                            <p style="font-size: 13px; margin-bottom: 14px;"><%= EscapeUtil.html(tutor.bio)%></p>
                            <% }%>
                            <div class="tutor-rate" style="font-size: 1.1rem;">R<%= String.format("%.2f", tutor.hourlyRate)%>/hr</div>
                        </div>

                        <div class="booking-panel">
                            <div class="tab-bar" role="tablist">
                                <button type="button" class="tab-btn active" id="tabBtnBook" role="tab"
                                        aria-selected="true" aria-controls="tabBook" data-tab="tabBook">Book Session</button>
                                <button type="button" class="tab-btn" id="tabBtnReviews" role="tab"
                                        aria-selected="false" aria-controls="tabReviews" data-tab="tabReviews">Reviews (<%= reviewCount %>)</button>
                            </div>

                            <div class="tab-panel active" id="tabBook" role="tabpanel" aria-labelledby="tabBtnBook">
                            <% if (!isLoggedInStudent) { %>
                            <div class="empty-state">
                                You need to be logged in as a student to book a session.
                                <br><br>
                                <a href="login.jsp" class="btn btn-primary">Log In</a>
                            </div>
                            <% } else if (openSlots.isEmpty()) { %>
                            <div class="empty-state">This tutor has no open time slots right now. Check back later.</div>
                            <% } else {%>
                            <form method="post" action="<%= request.getContextPath()%>/book">
                                <input type="hidden" name="tutorId" value="<%= tutorId%>">
                                <% for (AvailabilityDAO.Slot s : openSlots) {
                                    long slotHours = java.time.Duration.between(
                                        java.time.LocalTime.parse(s.startTime),
                                        java.time.LocalTime.parse(s.endTime)).toHours();
                                %>
                                <label class="slot-option">
                                    <input type="checkbox" name="availabilityId" class="slot-check" value="<%= s.availabilityId%>"
                                           data-date="<%= s.date%>" data-start="<%= s.startTime%>" data-end="<%= s.endTime%>"
                                           data-price="<%= String.format(java.util.Locale.US, "%.2f", tutor.hourlyRate * slotHours)%>">
                                    <%= s.date%> &middot; <%= s.startTime%> &ndash; <%= s.endTime%>
                                    (<%= slotHours %> hr &middot; R<%= String.format("%.2f", tutor.hourlyRate * slotHours)%>)
                                </label>
                                <% } %>
                                <p style="font-size:12px;color:var(--text-muted);margin:0 0 10px;">
                                    Tick one or more slots. Several slots must be on the same day and back to back
                                    (up to <%= com.peertutorconnect.dao.BookingDAO.MAX_SLOTS_PER_BOOKING %>).
                                </p>
                                <div id="slotSummary" style="font-size:13px;font-weight:600;color:var(--navy);margin:6px 0;"></div>
                                <div id="slotWarning" class="form-error" style="display:none;"></div>

                                <label for="description" style="display:block;font-size:13px;font-weight:600;margin:14px 0 4px;">
                                    What do you need help with? <span style="color:var(--error);">*</span>
                                </label>
                                <textarea id="description" name="description" required maxlength="1000" rows="4"
                                          style="width:100%;box-sizing:border-box;font-family:inherit;padding:8px;"
                                          placeholder="e.g. Chapter 4 on integration, and last year's exam question 3"></textarea>

                                <p style="font-size:12px;color:var(--text-muted);margin-top:8px;">
                                    How it works: the tutor reviews your request. If approved, you upload proof of payment
                                    and the tutor confirms the booking by sending the Teams link.
                                </p>
                                <p style="font-size:12px;color:var(--text-muted);margin-top:8px;">
                                    Cancellation policy: you can only cancel at least 8 hours before the session,
                                    and cancelling after you have paid is charged at 50% of the session price.
                                    After that you can no longer cancel; missing a session can earn you a strike
                                    (3 strikes = account removed).
                                </p>
                                <button type="submit" id="requestBtn" class="btn btn-primary" style="margin-top: 10px;">Request Booking</button>
                            </form>
                            <% } %>
                            </div>

                            <div class="tab-panel" id="tabReviews" role="tabpanel" aria-labelledby="tabBtnReviews">
                                <% if (reviews.isEmpty()) { %>
                                <div class="empty-state">No reviews yet. This tutor hasn't been rated by any students.</div>
                                <% } else { %>
                                <div class="review-summary">
                                    <span class="big"><%= String.format("%.2f", tutor.averageRating) %></span>
                                    <span class="review-stars">&#9733;</span>
                                    <span>from <%= reviewCount %> review<%= reviewCount == 1 ? "" : "s" %></span>
                                </div>
                                <% for (RatingDAO.Review r : reviews) { %>
                                <div class="review-card">
                                    <div class="review-head">
                                        <span class="review-name"><%= EscapeUtil.html(r.studentName) %></span>
                                        <span class="review-date"><%= r.createdAt %></span>
                                    </div>
                                    <div class="review-stars">
                                        <% for (int i = 0; i < r.stars; i++) { %>&#9733;<% } %><% for (int i = r.stars; i < 5; i++) { %>&#9734;<% } %>
                                    </div>
                                    <% if (r.comment != null && !r.comment.trim().isEmpty()) { %>
                                    <p class="review-comment"><%= EscapeUtil.html(r.comment) %></p>
                                    <% } %>
                                </div>
                                <% } %>
                                <% } %>
                            </div>
                        </div>

                    </div>

                </div>

                <% if (navIsLoggedIn) { %>
            </main>
        </div>
        <% } else { %>
        <jsp:include page="includes/footer.jsp" />
        <% }%>

        <script>
            // Tabs: Book Session / Reviews. Opening with #reviews in the URL lands on Reviews.
            (function () {
                var btns = document.querySelectorAll('.tab-btn');
                function show(id) {
                    btns.forEach(function (b) {
                        var on = b.dataset.tab === id;
                        b.classList.toggle('active', on);
                        b.setAttribute('aria-selected', on ? 'true' : 'false');
                        document.getElementById(b.dataset.tab).classList.toggle('active', on);
                    });
                }
                btns.forEach(function (b) {
                    b.addEventListener('click', function () { show(b.dataset.tab); });
                });
                if (location.hash === '#reviews') show('tabReviews');
            })();
        </script>

        <script>
            // Client-side check only: the server enforces the same rules (same day, back to back, max slots).
            (function () {
                var checks = document.querySelectorAll('.slot-check');
                if (!checks.length) return;
                var MAX = <%= com.peertutorconnect.dao.BookingDAO.MAX_SLOTS_PER_BOOKING %>;
                var summary = document.getElementById('slotSummary');
                var warning = document.getElementById('slotWarning');
                var btn = document.getElementById('requestBtn');

                function toMin(t) { var p = t.split(':'); return parseInt(p[0], 10) * 60 + parseInt(p[1], 10); }

                function update() {
                    var chosen = [];
                    checks.forEach(function (c) { if (c.checked) chosen.push(c); });
                    chosen.sort(function (a, b) {
                        return (a.dataset.date + a.dataset.start).localeCompare(b.dataset.date + b.dataset.start);
                    });

                    var problem = '';
                    if (chosen.length > MAX) {
                        problem = 'You can book at most ' + MAX + ' slots at a time.';
                    }
                    for (var i = 1; i < chosen.length && !problem; i++) {
                        if (chosen[i].dataset.date !== chosen[i - 1].dataset.date
                                || toMin(chosen[i].dataset.start) !== toMin(chosen[i - 1].dataset.end)) {
                            problem = 'Slots must be on the same day and follow each other without gaps.';
                        }
                    }

                    var total = 0;
                    chosen.forEach(function (c) { total += parseFloat(c.dataset.price); });
                    summary.textContent = chosen.length
                        ? chosen.length + ' hour(s) selected · total R' + total.toFixed(2)
                        : '';
                    warning.style.display = problem ? 'block' : 'none';
                    warning.textContent = problem;
                    btn.disabled = !!problem || chosen.length === 0;
                }

                checks.forEach(function (c) { c.addEventListener('change', update); });
                update();
            })();
        </script>

    </body>
</html>