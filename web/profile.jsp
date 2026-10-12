<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.peertutorconnect.dao.UserDAO.ProfileRow" %>
<%@ page import="com.peertutorconnect.dao.AvailabilityDAO" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Profile Settings</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .form-page {
            max-width: 560px;
            margin: 0;
            padding: 0;
        }

        .form-card {
            background: white;
            border: 1px solid var(--border-light);
            border-radius: 8px;
            padding: 32px;
            margin-bottom: 24px;
        }

        .form-card h1 {
            font-size: 1.4rem;
            color: var(--navy);
            margin-bottom: 6px;
        }

        .form-card h2 {
            font-size: 1.1rem;
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

        .form-error {
            background: #fbeae7;
            border: 1px solid var(--error);
            color: var(--error);
            padding: 10px 14px;
            border-radius: 4px;
            font-size: 13px;
            margin-bottom: 18px;
        }

        .form-success {
            background: #e8f5e9;
            border: 1px solid #4caf50;
            color: #2e7d32;
            padding: 10px 14px;
            border-radius: 4px;
            font-size: 13px;
            margin-bottom: 18px;
        }

        .field-error {
            display: none;
            color: var(--error);
            font-size: 12px;
            margin-top: 4px;
        }

        .field-error.active {
            display: block;
        }

        .form-row input.invalid {
            border-color: var(--error);
        }

        .field-hint {
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 4px;
        }

        .form-row input:disabled,
        .form-row select:disabled {
            background-color: #f0f0f0;
            color: var(--text-muted);
            cursor: not-allowed;
            border-color: var(--border-light);
        }

        .locked-hint {
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 4px;
            font-style: italic;
        }

        .submit-btn {
            padding: 10px 24px;
            margin-top: 8px;
        }
    </style>
</head>
<body>

    <div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">

    <%
        ProfileRow profile = (ProfileRow) request.getAttribute("profile");
        String infoError = (String) request.getAttribute("infoError");
        String infoSuccess = (String) request.getAttribute("infoSuccess");
        String passwordError = (String) request.getAttribute("passwordError");
        String passwordSuccess = (String) request.getAttribute("passwordSuccess");
        boolean isStudent = profile != null && "STUDENT".equals(profile.role);
    %>

    <div class="page-heading">
        <h1>Profile Settings</h1>
        <p>Update your contact information. Some fields are locked and cannot be changed here.</p>
    </div>

    <div class="page-wrap">
    <div class="form-page">

        <!-- ACCOUNT INFO -->
        <div class="form-card">
            <h2>Account Information</h2>

            <% if (infoError != null) { %>
                <div class="form-error"><%= infoError %></div>
            <% } %>
            <% if (infoSuccess != null) { %>
                <div class="form-success"><%= infoSuccess %></div>
            <% } %>

            <form method="post" action="<%= request.getContextPath() %>/profile" id="infoForm" novalidate>
                <input type="hidden" name="action" value="updateInfo">

                <div class="form-row">
                    <label for="name">Full Name</label>
                    <input type="text" id="name" name="name" disabled
                           value="<%= profile != null ? profile.name : "" %>">
                    <div class="locked-hint">This cannot be changed. Contact an administrator if this is incorrect.</div>
                </div>

                <div class="form-row">
                    <label for="email">Email</label>
                    <input type="email" id="email" name="email" required
                           value="<%= profile != null ? profile.email : "" %>">
                    <div class="field-error" id="emailError">Please enter a valid email address.</div>
                </div>

                <div class="form-row">
                    <label for="phone">Phone Number</label>
                    <input type="text" id="phone" name="phone" required
                           inputmode="numeric" maxlength="10"
                           value="<%= profile != null ? profile.phone : "" %>">
                    <div class="field-hint">10 digits, numbers only</div>
                    <div class="field-error" id="phoneError">Phone number must be exactly 10 digits.</div>
                </div>

                <% if (isStudent) { %>
                <div class="form-row">
                    <label for="department">Department</label>
                    <input type="text" id="department" name="department" disabled
                           value="<%= profile.department != null ? profile.department : "" %>">
                    <div class="locked-hint">This cannot be changed. Contact an administrator if this is incorrect.</div>
                </div>
                <div class="form-row">
                    <label for="yearOfStudy">Year of Study</label>
                    <select id="yearOfStudy" name="yearOfStudy" disabled>
                        <% for (int y = 1; y <= 4; y++) { %>
                            <option value="<%= y %>" <%= (profile.yearOfStudy != null && profile.yearOfStudy == y) ? "selected" : "" %>><%= y %></option>
                        <% } %>
                    </select>
                    <div class="locked-hint">This cannot be changed. Contact an administrator if this is incorrect.</div>
                </div>
                <% } %>

                <button type="submit" class="btn btn-primary submit-btn">Save Changes</button>
            </form>
        </div>

        <!-- PAYSHARP (tutors only) -->
        <%
            String psDetails = "";
            boolean showPaysharp = false;
            if ("TUTOR".equals(session.getAttribute("role"))) {
                Integer psTutorId = new AvailabilityDAO().getTutorIdForUser((int) session.getAttribute("userId"));
                TutorDAO psTutorDAO = new TutorDAO();
                if (psTutorId != null && psTutorDAO.isVerified(psTutorId)) {
                    showPaysharp = true;
                    String saved = psTutorDAO.getPaysharpDetails(psTutorId);
                    psDetails = (saved == null) ? "" : saved;
                }
            }
            boolean psSaved = "true".equals(request.getParameter("paysharpsaved"));
            String psErr = request.getParameter("paysharperror");
        %>
        <% if (showPaysharp) { %>
        <div class="form-card">
            <h2>PaySharp Details</h2>
            <p class="subtext">Students pay you using these details after you approve a booking.</p>

            <% if (psSaved) { %>
                <div class="form-success">Your PaySharp details have been saved.</div>
            <% } %>
            <% if ("invalid".equals(psErr)) { %>
                <div class="form-error">Please enter your PaySharp details (5 to 255 characters).</div>
            <% } else if (psErr != null) { %>
                <div class="form-error">Could not save your PaySharp details. Please try again.</div>
            <% } %>

            <form method="post" action="<%= request.getContextPath() %>/tutor-paysharp">
                <input type="hidden" name="from" value="profile">
                <div class="form-row">
                    <label for="paysharp">PaySharp details</label>
                    <input type="text" id="paysharp" name="paysharp" required minlength="5" maxlength="255"
                           value="<%= EscapeUtil.html(psDetails) %>"
                           placeholder="e.g. your PaySharp number, email or username">
                </div>
                <button type="submit" class="btn btn-primary submit-btn">Save PaySharp Details</button>
            </form>
        </div>
        <% } %>

        <!-- PASSWORD CHANGE -->
        <div class="form-card">
            <h2>Change Password</h2>
            <p class="subtext">Enter your current password to set a new one.</p>

            <% if (passwordError != null) { %>
                <div class="form-error"><%= passwordError %></div>
            <% } %>
            <% if (passwordSuccess != null) { %>
                <div class="form-success"><%= passwordSuccess %></div>
            <% } %>

            <form method="post" action="<%= request.getContextPath() %>/profile" id="passwordForm" novalidate>
                <input type="hidden" name="action" value="changePassword">

                <div class="form-row">
                    <label for="currentPassword">Current Password</label>
                    <input type="password" id="currentPassword" name="currentPassword" required>
                </div>

                <div class="form-row">
                    <label for="newPassword">New Password</label>
                    <input type="password" id="newPassword" name="newPassword" minlength="8" required>
                </div>

                <div class="form-row">
                    <label for="confirmNewPassword">Confirm New Password</label>
                    <input type="password" id="confirmNewPassword" name="confirmNewPassword" minlength="8" required>
                    <div class="field-error" id="confirmNewPasswordError">Passwords do not match.</div>
                </div>

                <button type="submit" class="btn btn-primary submit-btn">Update Password</button>
            </form>
        </div>

    </div>
    </div>

    </main>
    </div>

    <script>
        var EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
        var PHONE_PATTERN = /^\d{10}$/;

        function showFieldError(inputEl, errorEl, isValid) {
            if (isValid) {
                inputEl.classList.remove('invalid');
                errorEl.classList.remove('active');
            } else {
                inputEl.classList.add('invalid');
                errorEl.classList.add('active');
            }
            return isValid;
        }

        document.getElementById('phone').addEventListener('input', function () {
            this.value = this.value.replace(/\D/g, '');
        });

        document.getElementById('infoForm').addEventListener('submit', function (e) {
            var valid = true;

            var email = document.getElementById('email');
            valid = showFieldError(email, document.getElementById('emailError'),
                EMAIL_PATTERN.test(email.value.trim())) && valid;

            var phone = document.getElementById('phone');
            valid = showFieldError(phone, document.getElementById('phoneError'),
                PHONE_PATTERN.test(phone.value.trim())) && valid;

            if (!valid) {
                e.preventDefault();
            }
        });

        document.getElementById('passwordForm').addEventListener('submit', function (e) {
            var newPassword = document.getElementById('newPassword');
            var confirmNewPassword = document.getElementById('confirmNewPassword');
            var valid = showFieldError(confirmNewPassword, document.getElementById('confirmNewPasswordError'),
                newPassword.value === confirmNewPassword.value);

            if (!valid) {
                e.preventDefault();
            }
        });
    </script>

</body>
</html>