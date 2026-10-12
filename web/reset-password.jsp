<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Set New Password</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .form-page {
            max-width: 420px;
            margin: 60px auto 80px;
            padding: 0 24px;
        }

        .form-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 8px;
            padding: 32px;
        }

        .form-card h1 {
            font-size: 1.4rem;
            color: var(--navy);
            margin-bottom: 6px;
        }

        .form-card .subtext {
            font-size: 0.85rem;
            color: var(--text-muted);
            margin-bottom: 24px;
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

        .form-row {
            margin-bottom: 16px;
        }

        .submit-btn {
            width: 100%;
            padding: 12px;
            margin-top: 8px;
        }
    </style>
</head>
<body>

    <jsp:include page="includes/header.jsp" />

    <%
        String token = request.getParameter("token");
        if (token == null || token.trim().isEmpty()) {
            token = (String) request.getAttribute("token");
        }
    %>

    <div class="form-page">
        <div class="form-card">
            <% if (token == null || token.trim().isEmpty()) { %>
                <h1>Invalid link</h1>
                <p class="subtext">This password reset link is missing its token. Please request a new one.</p>
                <a href="<%= request.getContextPath() %>/forgot-password.jsp" class="btn btn-primary submit-btn" style="display:block;text-align:center;">Request New Link</a>
            <% } else { %>
                <h1>Set a new password</h1>
                <p class="subtext">Choose a new password for your account.</p>

                <% String error = (String) request.getAttribute("error"); %>
                <% if (error != null) { %>
                    <div class="form-error"><%= error %></div>
                <% } %>

                <form method="post" action="<%= request.getContextPath() %>/reset-password">
                    <input type="hidden" name="token" value="<%= token %>">
                    <div class="form-row">
                        <label for="password">New Password</label>
                        <input type="password" id="password" name="password" minlength="8" required>
                    </div>
                    <div class="form-row">
                        <label for="confirmPassword">Confirm New Password</label>
                        <input type="password" id="confirmPassword" name="confirmPassword" minlength="8" required>
                    </div>
                    <button type="submit" class="btn btn-primary submit-btn">Reset Password</button>
                </form>
            <% } %>
        </div>
    </div>

    <jsp:include page="includes/footer.jsp" />

</body>
</html>