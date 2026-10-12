<%@ page import="jakarta.servlet.http.HttpSession" %>
<%
    HttpSession existingSession = request.getSession(false);
    String loggedInName = (existingSession != null) ? (String) existingSession.getAttribute("name") : null;
    String loggedInRole = (existingSession != null) ? (String) existingSession.getAttribute("role") : null;

    String dashboardUrl = "#";
    if ("STUDENT".equals(loggedInRole)) dashboardUrl = request.getContextPath() + "/student-dashboard.jsp";
    else if ("TUTOR".equals(loggedInRole)) dashboardUrl = request.getContextPath() + "/tutor-dashboard.jsp";
    else if ("ADMIN".equals(loggedInRole)) dashboardUrl = request.getContextPath() + "/admin-dashboard.jsp";
%>
<header>
    <div class="logo">Peer<span class="logo-accent">Tutor</span>Connect</div>
    <nav>
        <a href="<%= request.getContextPath() %>/index.jsp#how-it-works">How it works</a>
        <!-- "Find Tutors" is a student-facing feature: hide it for logged-in
             tutors and admins, same rule as the dashboard sidebar. -->
        <% if (loggedInName == null || "STUDENT".equals(loggedInRole)) { %>
            <a href="<%= request.getContextPath() %>/search-tutors.jsp">Find Tutors</a>
        <% } %>
        <% if (loggedInName != null) { %>
            <a href="<%= dashboardUrl %>"><%= loggedInName %></a>
            <a href="<%= request.getContextPath() %>/logout" data-logout class="btn btn-outline" style="border-color: rgba(255,255,255,0.4);">Log out</a>
        <% } else { %>
            <a href="<%= request.getContextPath() %>/login.jsp">Log in</a>
            <a href="<%= request.getContextPath() %>/register.jsp" class="btn btn-navy" style="margin-left: 20px;">Sign up</a>
        <% } %>
    </nav>
</header>

<% if (loggedInName != null) { %>
    <jsp:include page="logout-modal.jsp" />
<% } %>