<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
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

    int completedSessions = tutorDAO.getCompletedSessionCount(tutorId);

    RatingDAO ratingDAO = new RatingDAO();
    List<RatingDAO.Review> reviews = ratingDAO.getReviewsForTutor(tutorId);
    int reviewCount = reviews.size();

    boolean navIsLoggedIn = session.getAttribute("role") != null;

    String initials = "";
    for (String part : tutor.name.trim().split("\\s+")) {
        if (!part.isEmpty()) initials += part.charAt(0);
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title><%= EscapeUtil.html(tutor.name) %> &mdash; PeerTutorConnect</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .profile-layout {
            display: flex;
            gap: 28px;
            flex-wrap: wrap;
        }

        .profile-summary {
            flex: 1;
            min-width: 240px;
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 24px;
            height: fit-content;
        }

        .profile-summary .tutor-avatar {
            width: 64px;
            height: 64px;
            font-size: 1.3rem;
            margin-bottom: 14px;
        }

        .profile-summary h1 {
            color: var(--navy);
            font-size: 1.3rem;
            margin-bottom: 6px;
        }

        .profile-stats {
            display: flex;
            gap: 20px;
            margin: 16px 0;
            padding: 14px 0;
            border-top: 1px solid var(--border-light);
            border-bottom: 1px solid var(--border-light);
        }

        .profile-stats .stat-num {
            font-size: 1.2rem;
            font-weight: bold;
            color: var(--navy);
        }

        .profile-stats .stat-lbl {
            font-size: 11px;
            color: var(--text-muted);
            text-transform: uppercase;
        }

        .profile-main {
            flex: 2;
            min-width: 300px;
        }

        .profile-section {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 22px;
            margin-bottom: 20px;
        }

        .profile-section h3 {
            color: var(--navy);
            font-size: 1rem;
            margin-bottom: 14px;
        }

        .review-card {
            padding: 14px 0;
            border-bottom: 1px solid var(--border-light);
        }

        .review-card:last-child { border-bottom: none; }

        .review-head {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 6px;
        }

        .review-name {
            font-weight: 600;
            font-size: 13px;
            color: var(--text-dark);
        }

        .review-stars {
            color: var(--orange);
            font-size: 13px;
        }

        .review-date {
            font-size: 11px;
            color: var(--text-muted);
        }

        .review-comment {
            font-size: 13px;
            color: var(--text-dark);
        }
    </style>
</head>
<body>

<% if (navIsLoggedIn) { %>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">
<% } else { %>
<jsp:include page="includes/header.jsp" />
<% } %>

    <div class="page-heading">
        <h1><%= EscapeUtil.html(tutor.name) %></h1>
        <p>Tutor Profile</p>
    </div>

    <div class="page-wrap">
        <div class="profile-layout">

            <div class="profile-summary">
                <div class="tutor-avatar"><%= EscapeUtil.html(initials.toUpperCase()) %></div>
                <h1>
                    <%= EscapeUtil.html(tutor.name) %>
                    <% if (tutor.isVerified) { %>
                        <span style="display:inline-flex;align-items:center;justify-content:center;width:15px;height:15px;background:#1a73e8;border-radius:50%;margin-left:4px;vertical-align:middle;flex-shrink:0;">
                            <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
                        </span>
                    <% } %>
                </h1>
                <div class="tutor-rating" style="margin-top: 8px;">
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.5 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.5 12 2"/></svg>
                    <%= String.format("%.2f", tutor.averageRating) %> (<%= reviewCount %> review<%= reviewCount == 1 ? "" : "s" %>)
                </div>
                <p style="font-size: 13px; color: var(--text-muted); margin: 10px 0;"><%= tutor.subjects.isEmpty() ? "No subjects listed" : tutor.subjects %></p>
                <div class="tutor-rate" style="font-size: 1.2rem;">R<%= String.format("%.2f", tutor.hourlyRate) %>/hr</div>

                <div class="profile-stats">
                    <div>
                        <div class="stat-num"><%= completedSessions %></div>
                        <div class="stat-lbl">Sessions Taught</div>
                    </div>
                    <div>
                        <div class="stat-num"><%= reviewCount %></div>
                        <div class="stat-lbl">Reviews</div>
                    </div>
                </div>

                <a href="book-session.jsp?tutorId=<%= tutorId %>" class="btn btn-primary" style="width:100%;text-align:center;display:block;">Book Session</a>
            </div>

            <div class="profile-main">

                <% if (tutor.bio != null && !tutor.bio.trim().isEmpty()) { %>
                    <div class="profile-section">
                        <h3>About</h3>
                        <p style="font-size: 14px; color: var(--text-dark);"><%= EscapeUtil.html(tutor.bio) %></p>
                    </div>
                <% } %>

                <div class="profile-section">
                    <h3>Reviews</h3>
                    <% if (reviews.isEmpty()) { %>
                        <p style="font-size: 13px; color: var(--text-muted);">No reviews yet.</p>
                    <% } else { %>
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
<% } %>

</body>
</html>