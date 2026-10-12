<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Reset Password</title>
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

        .sent-state {
            text-align: center;
        }

        .sent-state svg {
            width: 44px;
            height: 44px;
            stroke: var(--success);
            margin-bottom: 14px;
        }
    </style>
</head>
<body>

    <jsp:include page="includes/header.jsp" />

    <div class="form-page">
        <div class="form-card">
            <% if ("true".equals(request.getParameter("sent"))) { %>
                <div class="sent-state">
                    <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
                        <path d="M22 4 12 14.01l-3-3"/>
                    </svg>
                    <h1>Check your email</h1>
                    <p class="subtext">If an account exists for that address, we've sent a link to reset your password. It expires in 1 hour.</p>
                </div>
            <% } else { %>
                <h1>Forgot your password?</h1>
                <p class="subtext">Enter your email and we'll send you a link to reset it.</p>

                <% String error = (String) request.getAttribute("error");
                   String errorParam = request.getParameter("error");
                   String errorMsg = error;
                   if (errorMsg == null && "expired".equals(errorParam)) {
                       errorMsg = "That reset link has expired or is invalid. Please request a new one.";
                   } else if (errorMsg == null && "invalidtoken".equals(errorParam)) {
                       errorMsg = "That reset link is invalid. Please request a new one.";
                   }
                %>
                <% if (errorMsg != null) { %>
                    <div class="form-error"><%= errorMsg %></div>
                <% } %>

                <form method="post" action="<%= request.getContextPath() %>/forgot-password">
                    <div class="form-row">
                        <label for="email">Email</label>
                        <input type="email" id="email" name="email" required>
                    </div>
                    <button type="submit" class="btn btn-primary submit-btn">Send Reset Link</button>
                </form>
            <% } %>

            <div class="form-footer-link">
                <a href="<%= request.getContextPath() %>/login.jsp">Back to log in</a>
            </div>
        </div>
    </div>

    <jsp:include page="includes/footer.jsp" />

</body>
</html>