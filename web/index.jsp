<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="com.peertutorconnect.util.DBConnection" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    String idxRole = (session != null) ? (String) session.getAttribute("role") : null;
    boolean isLoggedIn = idxRole != null;

    String idxDashboardUrl = request.getContextPath() + "/index.jsp";
    if ("STUDENT".equals(idxRole))
        idxDashboardUrl = request.getContextPath() + "/student-dashboard.jsp";
    else if ("TUTOR".equals(idxRole))
        idxDashboardUrl = request.getContextPath() + "/tutor-dashboard.jsp";
    else if ("ADMIN".equals(idxRole))
        idxDashboardUrl = request.getContextPath() + "/admin-dashboard.jsp";
%>
<!DOCTYPE html>
<html>
    <head>
        <title>PeerTutorConnect &mdash; Learn together</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="css/style.css">
        <style>
            .hero {
                background-color: var(--navy);
                color: white;
                padding: 70px 40px 50px;
            }

            .hero-inner {
                display: flex;
                align-items: center;
                justify-content: space-between;
                max-width: 1100px;
                margin: 0 auto;
            }

            .hero-text {
                max-width: 500px;
            }

            .hero-tag {
                color: var(--orange);
                font-size: 0.85rem;
                font-weight: bold;
                margin-bottom: 14px;
            }

            .hero-text h1 {
                font-size: 2.4rem;
                line-height: 1.25;
                margin-bottom: 18px;
            }

            .hero-text h1 .accent {
                color: var(--orange);
            }

            .hero-text p {
                color: #c9d2de;
                font-size: 1rem;
                margin-bottom: 26px;
            }

            .hero-buttons {
                display: flex;
                gap: 14px;
                margin-bottom: 40px;
            }

            .hero-graphic {
                width: 320px;
                height: 320px;
                border-radius: 50%;
                background-color: rgba(255,255,255,0.06);
                position: relative;
                flex-shrink: 0;
            }

            .card-doc {
                position: absolute;
                top: 62px;
                left: 32px;
                width: 150px;
                background: var(--cream);
                border-radius: 8px;
                padding: 14px;
                box-shadow: 0 10px 24px rgba(0,0,0,0.3);
            }

            .card-doc .doc-line {
                height: 6px;
                background: var(--border-light);
                border-radius: 3px;
                margin-bottom: 8px;
            }

            .card-doc .doc-line.accent-line {
                background: var(--orange);
                width: 45%;
                margin-bottom: 0;
            }

            .card-profile {
                position: absolute;
                bottom: 50px;
                right: 24px;
                width: 130px;
                height: 130px;
                background: #2c4870;
                border-radius: 14px;
                box-shadow: 0 10px 24px rgba(0,0,0,0.3);
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                gap: 12px;
            }

            .card-profile .avatar-circle {
                width: 54px;
                height: 54px;
                border-radius: 50%;
                background: white;
                display: flex;
                align-items: center;
                justify-content: center;
            }

            .card-profile .avatar-circle svg {
                width: 26px;
                height: 26px;
                stroke: #2c4870;
            }

            .card-profile .name-line {
                width: 55%;
                height: 6px;
                background: rgba(255,255,255,0.5);
                border-radius: 3px;
            }

            .dot-orange {
                position: absolute;
                top: 18px;
                left: 60px;
                width: 22px;
                height: 22px;
                border-radius: 50%;
                background: var(--orange);
            }

            .dot-soft {
                position: absolute;
                bottom: 24px;
                left: 4px;
                width: 16px;
                height: 16px;
                border-radius: 50%;
                background: rgba(255,255,255,0.35);
            }

            .stats-row {
                display: flex;
                gap: 48px;
                border-top: 1px solid rgba(255,255,255,0.15);
                padding-top: 22px;
                max-width: 1100px;
                margin: 0 auto;
            }

            .stat-item .stat-number {
                color: var(--orange);
                font-size: 1.4rem;
                font-weight: bold;
            }

            .stat-item .stat-label {
                color: #c9d2de;
                font-size: 0.85rem;
            }

            .features-wrap {
                background-color: white;
                border-top: 1px solid var(--border-light);
                border-bottom: 1px solid var(--border-light);
            }

            .features {
                max-width: 1100px;
                margin: 0 auto;
                padding: 55px 40px;
                display: flex;
                justify-content: space-between;
                gap: 24px;
            }

            .feature-item {
                flex: 1;
                text-align: center;
                padding: 28px 20px;
                border-radius: 10px;
                background: var(--cream);
                border: 1px solid var(--border-light);
            }

            .feature-icon-wrap {
                width: 58px;
                height: 58px;
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                margin: 0 auto 16px;
            }

            .feature-icon-wrap.navy-bg {
                background-color: rgba(26,47,78,0.09);
            }
            .feature-icon-wrap.orange-bg {
                background-color: rgba(232,150,60,0.14);
            }

            .feature-icon-wrap svg {
                width: 26px;
                height: 26px;
                stroke-width: 1.8;
                fill: none;
            }

            .feature-item h3 {
                font-size: 1.05rem;
                margin-bottom: 8px;
                color: var(--navy);
            }

            .feature-item p {
                font-size: 0.88rem;
                color: var(--text-muted);
            }

            .tutors-section {
                max-width: 1100px;
                margin: 0 auto;
                padding: 55px 40px 60px;
            }

            .tutors-section h2 {
                color: var(--navy);
                font-size: 1.3rem;
                margin-bottom: 20px;
            }

            .tutor-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(230px, 1fr));
                gap: 18px;
            }

            .tutor-card {
                border: 1px solid var(--border-light);
                border-radius: 6px;
                padding: 18px;
                background: white;
            }

            .tutor-avatar {
                width: 46px;
                height: 46px;
                border-radius: 50%;
                background-color: var(--navy);
                color: white;
                display: flex;
                align-items: center;
                justify-content: center;
                font-weight: bold;
                margin-bottom: 10px;
            }

            .tutor-card h4 {
                font-size: 1rem;
                margin-bottom: 4px;
                color: var(--navy);
            }

            .tutor-rating {
                color: var(--orange);
                font-size: 0.85rem;
                margin-bottom: 8px;
                display: flex;
                align-items: center;
                gap: 4px;
            }

            .tutor-rating svg {
                width: 14px;
                height: 14px;
                fill: var(--orange);
            }

            .tutor-subjects {
                font-size: 0.78rem;
                color: var(--text-muted);
                margin-bottom: 10px;
            }

            .tutor-rate {
                font-weight: bold;
                color: var(--navy);
                margin-bottom: 12px;
            }

            .empty-state {
                border: 1px dashed var(--border-light);
                border-radius: 6px;
                padding: 30px;
                text-align: center;
                color: var(--text-muted);
            }

            @media (max-width: 800px) {
                .hero-inner {
                    flex-direction: column;
                }
                .hero-graphic {
                    display: none;
                }
                .stats-row {
                    flex-wrap: wrap;
                    gap: 24px;
                }
                .features {
                    flex-direction: column;
                }
                footer .footer-columns {
                    flex-direction: column;
                    gap: 18px;
                }
            }
        </style>
    </head>
    <body>

        <jsp:include page="includes/header.jsp" />

        <section class="hero">
            <div class="hero-inner">
                <div class="hero-text">

                    <h1>Learn something new.<br>Teach what you <span class="accent">already know</span>.</h1>
                    <p>PeerTutorConnect matches you with fellow students who've already mastered the subject you're stuck on, or lets you open your own calendar and start tutoring in the subjects you're strong in.</p>
                    <div class="hero-buttons">
                        <% if (isLoggedIn) {%>
                        <a href="<%= idxDashboardUrl%>" class="btn btn-primary">Go to Dashboard</a>
                        <% } else { %>
                        <a href="register.jsp" class="btn btn-primary">Get started</a>
                        <a href="login.jsp" class="btn btn-outline">Log in</a>
                        <% } %>
                    </div>
                </div>

                <div class="hero-graphic">
                    <div class="dot-orange"></div>
                    <div class="dot-soft"></div>
                    <div class="card-doc">
                        <div class="doc-line"></div>
                        <div class="doc-line"></div>
                        <div class="doc-line"></div>
                        <div class="doc-line accent-line"></div>
                    </div>
                    <div class="card-profile">
                        <div class="avatar-circle">
                            <svg viewBox="0 0 24 24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="12" cy="8" r="4"></circle>
                            <path d="M4 21c0-4 4-6 8-6s8 2 8 6"></path>
                            </svg>
                        </div>
                        <div class="name-line"></div>
                    </div>
                </div>
            </div>

            <div class="stats-row">
                <div class="stat-item">
                    <div class="stat-number">1-on-1</div>
                    <div class="stat-label">peer sessions</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">
                        <%
                            int subjectCount = 0;
                            try (Connection conn = DBConnection.getConnection(); Statement st = conn.createStatement(); ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM subject")) {
                                if (rs.next()) {
                                    subjectCount = rs.getInt(1);
                                }
                            } catch (SQLException e) {
                                out.println("<!-- subject count failed: " + e.getMessage() + " -->");
                            }
                        %>
                        <%= subjectCount%>+
                    </div>
                    <div class="stat-label">subjects covered</div>
                </div>

            </div>
        </section>

        <div class="features-wrap">
            <section class="features" id="how-it-works">
                <div class="feature-item">
                    <div class="feature-icon-wrap navy-bg">
                        <svg viewBox="0 0 24 24" stroke="var(--navy)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="11" cy="11" r="7"></circle>
                        <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
                        </svg>
                    </div>
                    <h3>Find <span class="plain-amp">&amp;</span> Search</h3>
                    <p>Search verified tutors by subject, price, and rating. All tutors are academically screened.</p>
                </div>
                <div class="feature-item">
                    <div class="feature-icon-wrap navy-bg">
                        <svg viewBox="0 0 24 24" stroke="var(--navy)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <rect x="3" y="4" width="18" height="18" rx="2"></rect>
                        <line x1="16" y1="2" x2="16" y2="6"></line>
                        <line x1="8" y1="2" x2="8" y2="6"></line>
                        <line x1="3" y1="10" x2="21" y2="10"></line>
                        </svg>
                    </div>
                    <h3>Book Instantly</h3>
                    <p>Real-time availability calendar. No back-and-forth messaging.</p>
                </div>
                <div class="feature-item">
                    <div class="feature-icon-wrap orange-bg">
                        <svg viewBox="0 0 24 24" stroke="var(--orange)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <polygon points="12 2 15.09 8.5 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.5 12 2"></polygon>
                        </svg>
                    </div>
                    <h3>Rate <span class="plain-amp">&amp;</span> Review</h3>
                    <p>After your session, rate your tutor. Transparency creates accountability for everyone.</p>
                </div>
            </section>
        </div>

        <section class="tutors-section" id="tutors">
            <h2>Top-Rated Tutors</h2>

            <%
                List<Map<String, Object>> tutors = new ArrayList<>();
                try (Connection conn = DBConnection.getConnection()) {
                    String sql = "SELECT t.tutorId, u.name, t.hourlyRate, t.averageRating "
                            + "FROM tutor t JOIN user u ON t.userId = u.userId "
                            + "WHERE t.isVerified = TRUE ORDER BY t.averageRating DESC LIMIT 4";
                    try (PreparedStatement ps = conn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            Map<String, Object> row = new HashMap<>();
                            int tutorId = rs.getInt("tutorId");
                            row.put("tutorId", tutorId);
                            row.put("name", rs.getString("name"));
                            row.put("hourlyRate", rs.getBigDecimal("hourlyRate"));
                            row.put("averageRating", rs.getBigDecimal("averageRating"));

                            StringBuilder subjects = new StringBuilder();
                            try (PreparedStatement subPs = conn.prepareStatement(
                                    "SELECT s.moduleCode FROM tutor_subject ts "
                                    + "JOIN subject s ON ts.subjectId = s.subjectId WHERE ts.tutorId = ?")) {
                                subPs.setInt(1, tutorId);
                                try (ResultSet subRs = subPs.executeQuery()) {
                                    while (subRs.next()) {
                                        if (subjects.length() > 0) {
                                            subjects.append(" &middot; ");
                                        }
                                        subjects.append(subRs.getString("moduleCode"));
                                    }
                                }
                            }
                            row.put("subjects", subjects.toString());
                            tutors.add(row);
                        }
                    }
                } catch (SQLException e) {
                    out.println("<!-- tutor query failed: " + e.getMessage() + " -->");
                }
            %>

            <% if (tutors.isEmpty()) { %>
            <div class="empty-state">
                No verified tutors yet. <a href="register.jsp">Be the first to apply as a tutor.</a>
            </div>
            <% } else { %>
            <div class="tutor-grid">
                <% for (Map<String, Object> t : tutors) {
                        String name = (String) t.get("name");
                        String initials = "";
                        for (String part : name.trim().split("\\s+")) {
                            if (!part.isEmpty()) {
                                initials += part.charAt(0);
                            }
                        }
                        String bookUrl = "login.jsp?redirect=" + URLEncoder.encode("book-session.jsp?tutorId=" + t.get("tutorId"), "UTF-8");
                %>
                <div class="tutor-card">
                    <div class="tutor-avatar"><%= EscapeUtil.html(initials.toUpperCase())%></div>
                    <h4>
                        <%= EscapeUtil.html(name)%>
                        <span style="display:inline-flex;align-items:center;justify-content:center;width:15px;height:15px;background:#1a73e8;border-radius:50%;margin-left:4px;vertical-align:middle;flex-shrink:0;">
                            <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
                        </span>
                    </h4>
                    <div class="tutor-rating">
                        <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.5 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.5 12 2"/></svg>
                        <%= t.get("averageRating")%>
                    </div>
                    <div class="tutor-subjects"><%= t.get("subjects")%></div>
                    <div class="tutor-rate">R<%= t.get("hourlyRate")%>/hr</div>
                    <a href="<%= bookUrl%>" class="btn btn-primary" style="width:100%;text-align:center;display:block;">Book Now</a>
                </div>
                <% } %>
            </div>
            <% }%>
        </section>

        <jsp:include page="includes/footer.jsp" />

    </body>
</html>