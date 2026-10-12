package com.peertutorconnect.filter;

import java.io.IOException;
import java.net.URI;
import java.util.Set;
import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebFilter(filterName = "AuthFilter", urlPatterns = {"/*"})
public class AuthFilter implements Filter {

    private static final Set<String> ADMIN = Set.of(
            "/admin-bookings.jsp", "/admin-dashboard.jsp", "/admin-tutors.jsp",
            "/manage-users.jsp", "/edit-user.jsp", "/tutor-application-detail.jsp",
            "/manage-users", "/verify-tutor", "/admin-strikes.jsp", "/admin-reviews.jsp",
            "/admin-subscriptions.jsp", "/admin-subscriptions");

    private static final Set<String> TUTOR = Set.of(
            "/complete-tutor-application.jsp", "/manage-availability.jsp",
            "/tutor-dashboard.jsp", "/tutor-sessions.jsp", "/tutor-reviews.jsp",
            "/complete-tutor-application", "/availability", "/respond-booking", "/session-link", "/tutor-paysharp",
            "/tutor-subscription.jsp", "/tutor-subscription");

    private static final Set<String> STUDENT = Set.of(
            "/book-session.jsp", "/my-sessions.jsp", "/student-dashboard.jsp",
            "/book", "/rate-session");

    private static final Set<String> ANY_LOGGED_IN = Set.of(
            "/profile.jsp", "/notifications.jsp", "/profile", "/notification", "/document",
            "/no-show", "/payment-proof", "/review-flag", "/subscription-proof");

    @Override
    public void doFilter(ServletRequest rq, ServletResponse rs, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest req = (HttpServletRequest) rq;
        HttpServletResponse res = (HttpServletResponse) rs;

        String path = req.getServletPath();
        HttpSession session = req.getSession(false);
        String role = session == null ? null : (String) session.getAttribute("role");
        boolean loggedIn = role != null;

        boolean needsLogin = ADMIN.contains(path) || TUTOR.contains(path)
                || STUDENT.contains(path) || ANY_LOGGED_IN.contains(path);

        if (needsLogin && !loggedIn) {
            res.sendRedirect(req.getContextPath() + "/login.jsp");
            return;
        }
        if ((ADMIN.contains(path) && !"ADMIN".equals(role))
                || (TUTOR.contains(path) && !"TUTOR".equals(role))
                || (STUDENT.contains(path) && !"STUDENT".equals(role))) {
            res.sendError(HttpServletResponse.SC_FORBIDDEN, "You do not have access to this page.");
            return;
        }

        if ("POST".equalsIgnoreCase(req.getMethod()) && loggedIn && !sameSite(req)) {
            res.sendError(HttpServletResponse.SC_FORBIDDEN, "Cross-site request blocked.");
            return;
        }

        chain.doFilter(rq, rs);
    }

    private boolean sameSite(HttpServletRequest req) {
        String host = req.getHeader("Host");
        String source = req.getHeader("Origin");
        if (source == null || source.isEmpty() || "null".equals(source)) {
            source = req.getHeader("Referer");
        }
        if (source == null || source.isEmpty() || host == null) {
            return true;
        }
        try {
            URI uri = URI.create(source);
            String sourceHost = uri.getPort() == -1 ? uri.getHost() : uri.getHost() + ":" + uri.getPort();
            return host.equalsIgnoreCase(sourceHost);
        } catch (IllegalArgumentException e) {
            return false;
        }
    }
}