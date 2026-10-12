<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.net.URLEncoder" %>
<!DOCTYPE html>
<html>
    <head>
        <title>PeerTutorConnect &mdash; Log In</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="css/style.css">
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600;700;800&display=swap');

            html, body {
                height: 100%;
            }

            body {
                margin: 0;
            }

            .auth-split {
                display: flex;
                min-height: 100vh;
            }

            /* Left hero panel */
            .auth-left {
                flex: 1;
                background: var(--navy);
                color: white;
                padding: 60px 64px;
                display: flex;
                flex-direction: column;
                justify-content: space-between;
            }

            .auth-logo {
                font-family: 'Playfair Display', 'Poppins', serif;
                font-size: 1.7rem;
                font-weight: 700;
            }

            .auth-logo span {
                color: var(--orange);
            }

            .auth-tagline {
                font-family: 'Playfair Display', 'Poppins', serif;
                font-size: 1.6rem;
                font-weight: 700;
                line-height: 1.35;
                margin-bottom: 20px;
            }

            .auth-divider {
                width: 44px;
                height: 3px;
                background: var(--orange);
                border-radius: 2px;
                margin-bottom: 20px;
            }

            .auth-desc {
                font-size: 0.92rem;
                line-height: 1.6;
                color: #b9c3d4;
                max-width: 380px;
            }

            .auth-stats {
                display: flex;
                gap: 40px;
            }

            .auth-stats .stat-num {
                font-family: 'Playfair Display', 'Poppins', serif;
                font-size: 1.3rem;
                font-weight: 700;
                color: var(--orange);
            }

            .auth-stats .stat-lbl {
                font-size: 0.8rem;
                color: #b9c3d4;
                margin-top: 2px;
            }

            /* Right form panel */
            .auth-right {
                flex: 1;
                background: var(--cream);
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 40px 24px;
            }

            .form-page {
                max-width: 420px;
                width: 100%;
                margin: 0;
                padding: 0;
            }

            .form-card {
                background: white;
                border: 1px solid var(--border-light);
                border-radius: 8px;
                padding: 32px;
            }

            .form-card h1 {
                font-family: 'Playfair Display', 'Poppins', serif;
                font-size: 1.5rem;
                color: var(--navy);
                margin-bottom: 6px;
            }

            .form-card .subtext {
                font-size: 0.85rem;
                color: var(--text-muted);
                margin-bottom: 24px;
            }

            .form-row {
                margin-bottom: 16px;
            }

            .submit-btn {
                width: 100%;
                padding: 12px;
                margin-top: 8px;
            }

            .form-footer-link {
                text-align: center;
                font-size: 13px;
                margin-top: 18px;
                color: var(--text-muted);
            }

            .form-footer-link a {
                color: var(--navy);
                font-weight: 600;
            }

            .password-wrapper {
                position: relative;
            }

            .password-wrapper input {
                padding-right: 42px;
            }

            .toggle-password {
                position: absolute;
                right: 10px;
                top: 50%;
                transform: translateY(-50%);
                background: none;
                border: none;
                cursor: pointer;
                color: var(--text-muted);
                padding: 4px;
                display: flex;
                align-items: center;
            }

            .toggle-password:hover {
                color: var(--navy);
            }

            .forgot-password-row {
                text-align: right;
                font-size: 12px;
                margin-bottom: 14px;
            }

            .forgot-password-row a {
                color: var(--navy);
                font-weight: 600;
            }

            @media (max-width: 800px) {
                .auth-split {
                    flex-direction: column;
                }
                .auth-left {
                    padding: 40px 32px;
                    min-height: 280px;
                }
                .auth-tagline {
                    font-size: 1.3rem;
                }
            }
        </style>
    </head>
    <body>

        <%
            // Only trust a redirect that points to book-session.jsp with a numeric tutorId.
            // Anything else is dropped so this can't be used as an open redirect.
            String rawRedirect = request.getParameter("redirect");
            String redirectParam = null;
            if (rawRedirect != null && rawRedirect.matches("book-session\\.jsp\\?tutorId=\\d+")) {
                redirectParam = rawRedirect;
            }
        %>

        <div class="auth-split">

            <div class="auth-left">
                <div class="auth-logo">Peer<span>Tutor</span>Connect</div>

                <div class="auth-mid">
                    <h2 class="auth-tagline">Learn something new.<br>Teach what you know.</h2>
                    <div class="auth-divider"></div>
                    <p class="auth-desc">Book a session with a fellow student who's already mastered what you're working on &mdash; or open up your own calendar and help someone else get there.</p>
                </div>

                <div class="auth-stats">
                    <div>
                        <div class="stat-num">1-on-1</div>
                        <div class="stat-lbl">peer sessions</div>
                    </div>

                </div>
            </div>

            <div class="auth-right">
                <div class="form-page">
                    <div class="form-card">
                        <h1>Welcome back</h1>
                        <p class="subtext"><%= redirectParam != null ? "Log in to continue booking your tutor." : "Log in to keep your sessions on track."%></p>

                        <form method="post" action="<%= request.getContextPath()%>/login">
                            <% if (redirectParam != null) {%>
                            <input type="hidden" name="redirect" value="<%= redirectParam%>">
                            <% }%>
                            <div class="form-row">
                                <label for="email">Email</label>
                                <input type="email" id="email" name="email" required>
                            </div>
                            <div class="form-row">
                                <label for="password">Password</label>
                                <div class="password-wrapper">
                                    <input type="password" id="password" name="password" required>
                                    <button type="button" class="toggle-password" onclick="togglePassword()" aria-label="Show password">
                                        <svg id="eyeIcon" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                                        <circle cx="12" cy="12" r="3"/>
                                        </svg>
                                    </button>
                                </div>
                            </div>
                            <div class="forgot-password-row">
                                <a href="<%= request.getContextPath()%>/forgot-password.jsp">Forgot password?</a>
                            </div>
                            <button type="submit" class="btn btn-primary submit-btn">Log In</button>
                        </form>

                        <div class="form-footer-link">
                            No account yet? <a href="register.jsp<%= redirectParam != null ? "?redirect=" + URLEncoder.encode(redirectParam, "UTF-8") : ""%>">Sign up</a>
                        </div>
                    </div>
                </div>
            </div>

        </div>

        <script>
            function togglePassword() {
                const input = document.getElementById('password');
                const icon = document.getElementById('eyeIcon');

                if (input.type === 'password') {
                    input.type = 'text';
                    icon.innerHTML = '<path d="M17.94 17.94A10.94 10.94 0 0 1 12 20c-7 0-11-8-11-8a21.8 21.8 0 0 1 5.06-6.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a21.8 21.8 0 0 1-3.22 4.66M14.12 14.12a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/>';
                } else {
                    input.type = 'password';
                    icon.innerHTML = '<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>';
                }
            }
        </script>

        <%-- showToast() lives in toast.jsp; without this include the toast messages never appear --%>
        <jsp:include page="includes/toast.jsp" />

        <% String unverifiedEmail = (String) request.getAttribute("unverifiedEmail"); %>
        <% if (unverifiedEmail != null) { %>
        <div id="verifyModal" role="dialog" aria-modal="true" aria-labelledby="verifyTitle"
             style="position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99999;padding:16px;">
            <div style="background:#ffffff;color:#1f2937;max-width:420px;width:100%;border-radius:12px;padding:28px;text-align:center;box-shadow:0 10px 30px rgba(0,0,0,.3);">
                <div style="font-size:42px;line-height:1;margin-bottom:10px;">&#9993;</div>
                <h2 id="verifyTitle" style="margin:0 0 12px;font-size:20px;color:#111827;">Check your email first</h2>
                <p style="margin:0 0 10px;line-height:1.5;">Please confirm your email address before you can log in.</p>
                <p style="margin:0 0 10px;line-height:1.5;">We just sent a fresh confirmation link to
                    <strong><%= com.peertutorconnect.util.EscapeUtil.html(unverifiedEmail) %></strong>.
                    Click it, then log in again.</p>
                <p style="margin:0 0 20px;font-size:13px;color:#6b7280;">Can't find it? Check your spam folder.</p>
                <button type="button" id="verifyOk"
                        style="background:#2563eb;color:#ffffff;border:0;border-radius:8px;padding:10px 22px;font-size:15px;cursor:pointer;">
                    OK, I will check my email
                </button>
            </div>
        </div>
        <script>
            (function () {
                var m = document.getElementById('verifyModal');
                function close() { if (m) { m.parentNode.removeChild(m); } }
                document.getElementById('verifyOk').addEventListener('click', close);
                document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { close(); } });
                document.getElementById('verifyOk').focus();
            })();
        </script>
        <% } %>

        <% String error = (String) request.getAttribute("error"); %>
        <% if (error != null) {%>
        <script>showToast('<%= error.replace("'", "\\'")%>', 'error');</script>
        <% } %>
        <% if ("true".equals(request.getParameter("registered"))) { %>
        <script>showToast('Account created. Check your email and click the link to activate it.', 'success');</script>
        <% } %>
        <% if ("true".equals(request.getParameter("verified"))) { %>
        <script>showToast('Email confirmed. You can now log in.', 'success');</script>
        <% } %>
        <% if ("true".equals(request.getParameter("verifyfailed"))) { %>
        <script>showToast('This link is invalid or has expired. Log in and we will send you a new one.', 'error');</script>
        <% } %>
        <% if ("true".equals(request.getParameter("reset"))) { %>
        <script>showToast('Password reset. You can now log in.', 'success');</script>
        <% }%>

    </body>
</html>