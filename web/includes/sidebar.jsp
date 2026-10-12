<%@ page import="jakarta.servlet.http.HttpSession" %>
<%@ page import="com.peertutorconnect.dao.NotificationDAO" %>
<%@ page import="com.peertutorconnect.dao.AvailabilityDAO" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
<%@ page import="com.peertutorconnect.dao.UserDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%
    HttpSession sbSession = request.getSession(false);
    String sbRole = (sbSession != null) ? (String) sbSession.getAttribute("role") : null;
    String sbName = (sbSession != null) ? (String) sbSession.getAttribute("name") : null;
    Object sbUserIdObj = (sbSession != null) ? sbSession.getAttribute("userId") : null;

    String dashboardUrl = request.getContextPath() + "/index.jsp";
    if ("STUDENT".equals(sbRole)) dashboardUrl = request.getContextPath() + "/student-dashboard.jsp";
    else if ("TUTOR".equals(sbRole)) dashboardUrl = request.getContextPath() + "/tutor-dashboard.jsp";
    else if ("ADMIN".equals(sbRole)) dashboardUrl = request.getContextPath() + "/admin-dashboard.jsp";

    int sbUnread = 0;
    String sbEmail = null;
    // Short preview list for the topbar dropdown - full history lives on
    // notifications.jsp via the "See all notifications" link below.
    List<NotificationDAO.Notification> sbRecentNotifs = new ArrayList<>();
    if (sbUserIdObj != null) {
        try {
            sbUnread = new NotificationDAO().getUnreadCount((int) sbUserIdObj);
        } catch (Exception e) {
            sbUnread = 0;
        }
        try {
            UserDAO.ProfileRow sbProfile = new UserDAO().getProfile((int) sbUserIdObj);
            if (sbProfile != null) sbEmail = sbProfile.email;
        } catch (Exception e) {
            sbEmail = null;
        }
        try {
            List<NotificationDAO.Notification> sbAllNotifs = new NotificationDAO().getForUser((int) sbUserIdObj);
            int sbPreviewCount = Math.min(5, sbAllNotifs.size());
            sbRecentNotifs = sbAllNotifs.subList(0, sbPreviewCount);
        } catch (Exception e) {
            sbRecentNotifs = new ArrayList<>();
        }
    }

    // A tutor only gets access to tutor-only features (My Sessions,
    // Availability) once an admin has approved their application. Before
    // that they can still reach their Dashboard (which itself routes them
    // to the application form until it's complete).
    boolean sbTutorApproved = false;
    if ("TUTOR".equals(sbRole) && sbUserIdObj != null) {
        try {
            Integer sbTutorId = new AvailabilityDAO().getTutorIdForUser((int) sbUserIdObj);
            if (sbTutorId != null) {
                sbTutorApproved = new TutorDAO().isVerified(sbTutorId);
            }
        } catch (Exception e) {
            sbTutorApproved = false;
        }
    }

    String currentPage = request.getServletPath();

    // First initial of the user's name, shown in both the sidebar profile
    // card and the top bar avatar circle (e.g. "Karabo K" -> "K").
    String sbInitial = "?";
    if (sbName != null && !sbName.trim().isEmpty()) {
        sbInitial = sbName.trim().substring(0, 1).toUpperCase();
    }
%>

<!-- Top bar: logo, notifications bell, avatar, log out.
     Sidebar below carries the profile card, nav links, and its
     own log out at the bottom - both logout links do the same
     thing, just for convenience wherever the user's eye lands. -->
<header class="app-topbar">
    <a class="topbar-logo" href="<%= request.getContextPath() %>/index.jsp">Peer<span class="logo-accent">Tutor</span>Connect</a>
    <div class="topbar-right">
        <div class="notif-wrap">
            <button type="button" class="icon-btn" id="notifBellBtn" title="Notifications"
                    aria-haspopup="true" aria-expanded="false" onclick="toggleNotifDropdown(event)">
                &#128276;
                <% if (sbUnread > 0) { %><span class="icon-badge"><%= sbUnread %></span><% } %>
            </button>
            <div class="notif-dropdown" id="notifDropdown">
                <div class="notif-dropdown-header">Notifications</div>
                <div class="notif-dropdown-body">
                    <% if (sbRecentNotifs.isEmpty()) { %>
                        <div class="notif-dropdown-empty">Nothing new.</div>
                    <% } else { %>
                        <div class="notif-list">
                        <% for (NotificationDAO.Notification n : sbRecentNotifs) {
                            String notifHref = (n.link != null && !n.link.trim().isEmpty())
                                    ? request.getContextPath() + n.link
                                    : request.getContextPath() + "/notifications.jsp";
                        %>
                            <a href="<%= notifHref %>" class="notif-item <%= n.isRead ? "" : "unread" %>">
                                <span><%= EscapeUtil.html(n.message) %></span>
                                <span class="notif-time"><%= n.createdAt %></span>
                            </a>
                        <% } %>
                        </div>
                    <% } %>
                </div>
                <a href="<%= request.getContextPath() %>/notifications.jsp" class="notif-dropdown-footer">See all notifications</a>
            </div>
        </div>
        <a href="<%= request.getContextPath() %>/profile" class="topbar-avatar" title="<%= EscapeUtil.html(sbName) %>"><%= sbInitial %></a>
        <a href="<%= request.getContextPath() %>/logout" data-logout class="topbar-logout">Log out</a>
    </div>
</header>

<aside class="app-sidebar">

    <div class="sidebar-profile">
        <div class="sidebar-avatar"><%= sbInitial %></div>
        <div class="sidebar-profile-name"><%= EscapeUtil.html(sbName) %></div>
        <% if (sbEmail != null) { %>
            <div class="sidebar-profile-email"><%= EscapeUtil.html(sbEmail) %></div>
        <% } %>
    </div>

    <nav class="sidebar-nav">
        <a href="<%= dashboardUrl %>" class="<%= currentPage.contains("dashboard") ? "active" : "" %>">Dashboard</a>

        <!-- "Find Tutors" is a student-only feature: browsing/booking
             tutors doesn't apply to tutor or admin accounts. -->
        <% if ("STUDENT".equals(sbRole)) { %>
            <a href="<%= request.getContextPath() %>/search-tutors.jsp" class="<%= currentPage.contains("search-tutors") ? "active" : "" %>">Find Tutors</a>
            <a href="<%= request.getContextPath() %>/my-sessions.jsp" class="<%= currentPage.contains("my-sessions") ? "active" : "" %>">My Sessions</a>
        <% } else if ("TUTOR".equals(sbRole) && sbTutorApproved) { %>
            <a href="<%= request.getContextPath() %>/tutor-sessions.jsp" class="<%= currentPage.contains("tutor-sessions") ? "active" : "" %>">My Sessions</a>
            <a href="<%= request.getContextPath() %>/manage-availability.jsp" class="<%= currentPage.contains("manage-availability") ? "active" : "" %>">Availability</a>
            <a href="<%= request.getContextPath() %>/tutor-reviews.jsp" class="<%= currentPage.contains("tutor-reviews") ? "active" : "" %>">My Reviews</a>
            <a href="<%= request.getContextPath() %>/tutor-subscription.jsp" class="<%= currentPage.contains("tutor-subscription") ? "active" : "" %>">Subscription</a>
        <% } else if ("ADMIN".equals(sbRole)) { %>
            <a href="<%= request.getContextPath() %>/manage-users.jsp" class="<%= currentPage.contains("manage-users") ? "active" : "" %>">Manage Users</a>
            <a href="<%= request.getContextPath() %>/admin-strikes.jsp" class="<%= currentPage.contains("admin-strikes") ? "active" : "" %>">No-Show Reports</a>
            <a href="<%= request.getContextPath() %>/admin-reviews.jsp" class="<%= currentPage.contains("admin-reviews") ? "active" : "" %>">Reported Reviews</a>
            <a href="<%= request.getContextPath() %>/admin-subscriptions.jsp" class="<%= currentPage.contains("admin-subscriptions") ? "active" : "" %>">Subscriptions</a>
        <% } %>

        <!-- Notifications and Profile Settings removed here - notifications
             lives in the top bar; profile lives only via the avatar link -->
    </nav>

    <div class="sidebar-bottom">
        <a href="<%= request.getContextPath() %>/logout" data-logout class="sidebar-logout-link">Log out</a>
    </div>

</aside>

<jsp:include page="logout-modal.jsp" />
<jsp:include page="toast.jsp" />

<script>
    // Notification bell dropdown: toggle on click, close on outside
    // click or Escape. Guarded so re-including sidebar.jsp twice on one
    // page (shouldn't happen, but just in case) won't double-bind.
    if (!window.__notifDropdownBound) {
        window.__notifDropdownBound = true;

        window.toggleNotifDropdown = function (event) {
            event.stopPropagation();
            var dropdown = document.getElementById('notifDropdown');
            var btn = document.getElementById('notifBellBtn');
            var isOpen = dropdown.classList.toggle('open');
            btn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
        };

        document.addEventListener('click', function (event) {
            var wrap = document.querySelector('.notif-wrap');
            if (wrap && !wrap.contains(event.target)) {
                var dropdown = document.getElementById('notifDropdown');
                var btn = document.getElementById('notifBellBtn');
                if (dropdown) dropdown.classList.remove('open');
                if (btn) btn.setAttribute('aria-expanded', 'false');
            }
        });

        document.addEventListener('keydown', function (event) {
            if (event.key === 'Escape') {
                var dropdown = document.getElementById('notifDropdown');
                var btn = document.getElementById('notifBellBtn');
                if (dropdown) dropdown.classList.remove('open');
                if (btn) btn.setAttribute('aria-expanded', 'false');
            }
        });
    }
</script>