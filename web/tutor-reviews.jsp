<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.AvailabilityDAO" %>
<%@ page import="com.peertutorconnect.dao.ReviewDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"TUTOR".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }
    int userId = (int) session.getAttribute("userId");
    Integer tutorId = new AvailabilityDAO().getTutorIdForUser(userId);
    List<ReviewDAO.TutorReview> reviews = (tutorId == null)
            ? new java.util.ArrayList<ReviewDAO.TutorReview>()
            : new ReviewDAO().getReviewsForTutor(tutorId);
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; My Reviews</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .rv-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 14px 18px;
            margin-bottom: 10px;
        }
        .rv-head { display: flex; justify-content: space-between; flex-wrap: wrap; gap: 8px; }
        .rv-name { font-weight: 600; font-size: 14px; color: var(--navy); }
        .rv-stars { color: var(--orange); font-size: 15px; }
        .rv-date { font-size: 11px; color: var(--text-muted); }
        .rv-comment { font-size: 14px; margin: 6px 0 10px; white-space: pre-wrap; }
        .rv-flag-form { display: flex; gap: 6px; flex-wrap: wrap; }
        .rv-flag-form input[type=text] {
            flex: 1; min-width: 200px; padding: 7px 8px; font-size: 13px;
            border: 1px solid var(--border-light); border-radius: 4px; font-family: inherit;
        }
        .btn-report {
            background: transparent; color: var(--error); border: 1px solid var(--error);
            padding: 7px 14px; border-radius: 4px; font-size: 12px; font-weight: 600;
            font-family: inherit; cursor: pointer;
        }
        .btn-report:hover { background: var(--error); color: white; }
        .rv-state { font-size: 12px; font-weight: 600; color: var(--text-muted); }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">
        <div class="page-wrap" style="padding-top: 40px;">
            <div class="page-heading">
                <h1>My Reviews</h1>
                <p>If a review is abusive, false or breaks the rules, report it. An admin will decide whether it stays.
                   Low ratings are not a reason to remove a review on their own.</p>
            </div>

            <% if (reviews.isEmpty()) { %>
                <div class="empty-state">You haven't received any reviews yet.</div>
            <% } else { %>
                <% for (ReviewDAO.TutorReview r : reviews) { %>
                    <div class="rv-card">
                        <div class="rv-head">
                            <span class="rv-name"><%= EscapeUtil.html(r.studentName) %></span>
                            <span class="rv-date"><%= r.createdAt %></span>
                        </div>
                        <div class="rv-stars">
                            <% for (int i = 1; i <= 5; i++) { %><%= i <= r.stars ? "&#9733;" : "&#9734;" %><% } %>
                        </div>
                        <p class="rv-comment"><%= EscapeUtil.html(r.comment == null ? "" : r.comment) %></p>

                        <% if (r.flagStatus == null) { %>
                            <form method="post" action="<%= request.getContextPath() %>/review-flag" class="rv-flag-form"
                                  onsubmit="return confirm('Report this review to an admin?');">
                                <input type="hidden" name="action" value="flag">
                                <input type="hidden" name="ratingId" value="<%= r.ratingId %>">
                                <input type="text" name="reason" required minlength="<%= ReviewDAO.MIN_REASON %>"
                                       maxlength="<%= ReviewDAO.MAX_REASON %>" placeholder="Why should this be removed?">
                                <button type="submit" class="btn-report">Report review</button>
                            </form>
                        <% } else if ("PENDING".equals(r.flagStatus)) { %>
                            <span class="rv-state">Reported &mdash; waiting for an admin.</span>
                        <% } else { %>
                            <span class="rv-state">Reported &mdash; an admin decided it stays.</span>
                        <% } %>
                    </div>
                <% } %>
            <% } %>
        </div>
    </main>
</div>

<% if ("true".equals(request.getParameter("reviewreported"))) { %>
    <script>showToast('Review reported. An admin will look at it.', 'success');</script>
<% } %>
<%
    String rvErr = request.getParameter("reviewerror");
    if (rvErr != null) {
        String rvMsg;
        if ("noreason".equals(rvErr)) rvMsg = "Please explain why you are reporting this review.";
        else if ("alreadyflagged".equals(rvErr)) rvMsg = "That review has already been reported.";
        else if ("notfound".equals(rvErr)) rvMsg = "That review could not be found.";
        else rvMsg = "Something went wrong. Please try again.";
%>
    <script>showToast('<%= rvMsg %>', 'error');</script>
<% } %>
</body>
</html>