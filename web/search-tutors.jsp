<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.List" %>
<%@ page import="com.peertutorconnect.util.DBConnection" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
<%
    String keyword = request.getParameter("keyword");
    String subjectIdParam = request.getParameter("subjectId");
    String maxRateParam = request.getParameter("maxRate");
    String minRatingParam = request.getParameter("minRating");
    String sortBy = request.getParameter("sortBy");

    Integer subjectId = (subjectIdParam != null && !subjectIdParam.isEmpty()) ? Integer.parseInt(subjectIdParam) : null;
    Double maxRate = (maxRateParam != null && !maxRateParam.isEmpty()) ? Double.parseDouble(maxRateParam) : null;
    Double minRating = (minRatingParam != null && !minRatingParam.isEmpty()) ? Double.parseDouble(minRatingParam) : null;

    List<TutorDAO.TutorSearchResult> tutors = null;
    String searchError = null;
    try {
        TutorDAO tutorDAO = new TutorDAO();
        tutors = tutorDAO.searchTutors(keyword, subjectId, maxRate, minRating, sortBy);
    } catch (SQLException e) {
        searchError = e.getMessage();
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Find a Tutor</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
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
        <h1>Find a Verified Tutor</h1>
        <p>Search by subject, name, price, or rating.</p>
    </div>

    <div class="page-wrap">

        <form method="get" action="search-tutors.jsp" class="search-bar">
            <div class="field">
                <label for="keyword">Tutor name</label>
                <input type="text" id="keyword" name="keyword" value="<%= keyword != null ? EscapeUtil.html(keyword) : "" %>" placeholder="Search by name">
            </div>

            <div class="field">
                <label for="subjectId">Subject</label>
                <select id="subjectId" name="subjectId">
                    <option value="">All Subjects</option>
                    <%
                        try (Connection conn = DBConnection.getConnection();
                             Statement st = conn.createStatement();
                             ResultSet rs = st.executeQuery("SELECT subjectId, moduleCode, name FROM subject ORDER BY moduleCode")) {
                            while (rs.next()) {
                                int sid = rs.getInt("subjectId");
                                boolean selected = (subjectId != null && subjectId == sid);
                    %>
                        <option value="<%= sid %>" <%= selected ? "selected" : "" %>>
                            <%= rs.getString("moduleCode") %> &mdash; <%= rs.getString("name") %>
                        </option>
                    <%
                            }
                        } catch (SQLException e) {
                    %>
                        <option value="">Could not load subjects</option>
                    <%
                        }
                    %>
                </select>
            </div>

            <div class="field">
                <label for="maxRate">Max Rate (R/hr)</label>
                <input type="number" id="maxRate" name="maxRate" min="0" step="1" value="<%= maxRateParam != null ? maxRateParam : "" %>">
            </div>

            <div class="field">
                <label for="minRating">Min Rating</label>
                <select id="minRating" name="minRating">
                    <option value="">Any</option>
                    <option value="4" <%= "4".equals(minRatingParam) ? "selected" : "" %>>4+ stars</option>
                    <option value="3" <%= "3".equals(minRatingParam) ? "selected" : "" %>>3+ stars</option>
                </select>
            </div>

            <div class="field">
                <label for="sortBy">Sort By</label>
                <select id="sortBy" name="sortBy">
                    <option value="rating" <%= !"price".equals(sortBy) ? "selected" : "" %>>Highest Rated</option>
                    <option value="price" <%= "price".equals(sortBy) ? "selected" : "" %>>Lowest Price</option>
                </select>
            </div>

            <button type="submit" class="btn btn-primary">Search</button>
        </form>

        <% if (searchError != null) { %>
            <div class="empty-state">Search failed: <%= EscapeUtil.html(searchError) %></div>
        <% } else if (tutors.isEmpty()) { %>
            <div class="empty-state">No tutors match your search. Try widening your filters.</div>
        <% } else { %>
            <div class="tutor-grid">
                <% for (TutorDAO.TutorSearchResult t : tutors) {
                    String initials = "";
                    for (String part : t.name.trim().split("\\s+")) {
                        if (!part.isEmpty()) initials += part.charAt(0);
                    }
                %>
                    <div class="tutor-card">
                        <div class="tutor-avatar"><%= EscapeUtil.html(initials.toUpperCase()) %></div>
                        <h4>
                            <a href="tutor-profile.jsp?tutorId=<%= t.tutorId %>" style="color: inherit;"><%= EscapeUtil.html(t.name) %></a>
                            <% if (t.isVerified) { %>
                                <span style="display:inline-flex;align-items:center;justify-content:center;width:15px;height:15px;background:#1a73e8;border-radius:50%;margin-left:4px;vertical-align:middle;flex-shrink:0;">
                                    <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
                                </span>
                            <% } %>
                        </h4>
                        <div class="tutor-rating">
                            <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.5 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.5 12 2"/></svg>
                            <%= String.format("%.2f", t.averageRating) %>
                            <a href="book-session.jsp?tutorId=<%= t.tutorId %>#reviews" style="font-size:12px;margin-left:6px;">See reviews</a>
                        </div>
                        <div class="tutor-subjects"><%= t.subjects.isEmpty() ? "No subjects listed" : t.subjects %></div>
                        <div class="tutor-rate">R<%= String.format("%.2f", t.hourlyRate) %>/hr</div>
                        <a href="book-session.jsp?tutorId=<%= t.tutorId %>" class="btn btn-primary" style="width:100%;text-align:center;display:block;">Book Session</a>
                    </div>
                <% } %>
            </div>
        <% } %>

    </div>

    <% if (navIsLoggedIn) { %>
    </main>
</div>
<% } else { %>
<jsp:include page="includes/footer.jsp" />
<% } %>

</body>
</html>