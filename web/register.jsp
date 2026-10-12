<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Create Account</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .form-page {
            max-width: 480px;
            margin: 50px auto 70px;
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

        .field-error {
            display: none;
            color: var(--error);
            font-size: 12px;
            margin-top: 4px;
        }

        .field-error.active {
            display: block;
        }

        .form-row input.invalid,
        .form-row select.invalid {
            border-color: var(--error);
        }

        .field-hint {
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 4px;
        }

        .role-toggle {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
        }

        .role-toggle label {
            flex: 1;
            text-align: center;
            padding: 12px;
            border: 1px solid var(--border-light);
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            color: var(--text-muted);
            margin-bottom: 0;
        }

        .role-toggle input[type="radio"] {
            display: none;
        }

        .role-toggle input[type="radio"]:checked + label {
            border-color: var(--navy);
            background-color: var(--navy);
            color: white;
        }

        .conditional-fields {
            display: none;
            border-top: 1px solid var(--border-light);
            padding-top: 16px;
            margin-top: 4px;
        }

        .conditional-fields.active {
            display: block;
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
    </style>
</head>
<body>

    <jsp:include page="includes/header.jsp" />

    <div class="form-page">
        <div class="form-card">
            <h1>Create your account</h1>
            <p class="subtext">Join PeerTutorConnect as a student or tutor.</p>

            <% String error = (String) request.getAttribute("error"); %>
            <% if (error != null) { %>
                <div class="form-error"><%= error %></div>
            <% } %>

            <form method="post" action="<%= request.getContextPath() %>/register" id="registerForm" novalidate>

                <div class="role-toggle">
                    <input type="radio" name="role" id="roleStudent" value="STUDENT" checked onclick="toggleRole()">
                    <label for="roleStudent">I'm a Student</label>

                    <input type="radio" name="role" id="roleTutor" value="TUTOR" onclick="toggleRole()">
                    <label for="roleTutor">I'm a Tutor</label>
                </div>

                <div class="form-row">
                    <label for="name">Full Name</label>
                    <input type="text" id="name" name="name" required
                           placeholder="e.g. Thabo Nkosi">
                    <div class="field-error" id="nameError">Please enter your full name (first and last name, letters only).</div>
                </div>

                <div class="form-row">
                    <label for="email">Email</label>
                    <input type="email" id="email" name="email" required
                           placeholder="you@example.com">
                    <div class="field-error" id="emailError">Please enter a valid email address.</div>
                </div>

                <div class="form-row">
                    <label for="phone">Phone Number</label>
                    <input type="text" id="phone" name="phone" required
                           inputmode="numeric" maxlength="10" placeholder="0812345678">
                    <div class="field-hint">10 digits, numbers only (e.g. 0812345678)</div>
                    <div class="field-error" id="phoneError">Phone number must be exactly 10 digits.</div>
                </div>

                <div id="studentFields" class="conditional-fields active">
                    <div class="form-row">
                        <label for="department">Department</label>
                        <input type="text" id="department" name="department"
                               placeholder="e.g. Computer Science">
                        <div class="field-hint">Enter the full department name (words only, no numbers)</div>
                        <div class="field-error" id="departmentError">Department must contain letters only (no numbers or symbols).</div>
                    </div>
                    <div class="form-row">
                        <label for="yearOfStudy">Year of Study</label>
                        <select id="yearOfStudy" name="yearOfStudy">
                            <option value="1">1</option>
                            <option value="2">2</option>
                            <option value="3">3</option>
                            <option value="4">4</option>
                        </select>
                    </div>
                </div>

                <div id="tutorNotice" class="conditional-fields">
                    <p class="subtext">You'll set your rate, bio, subjects, and upload verification documents right after you log in.</p>
                </div>

                <div class="form-row">
                    <label for="password">Password</label>
                    <input type="password" id="password" name="password" minlength="8" required>
                </div>

                <div class="form-row">
                    <label for="confirmPassword">Confirm Password</label>
                    <input type="password" id="confirmPassword" name="confirmPassword" minlength="8" required>
                    <div class="field-error" id="confirmPasswordError">Passwords do not match.</div>
                </div>

                <button type="submit" class="btn btn-primary submit-btn">Create Account</button>
            </form>

            <div class="form-footer-link">
                Already have an account? <a href="login.jsp">Log in</a>
            </div>
        </div>
    </div>

    <jsp:include page="includes/footer.jsp" />

    <script>
        function toggleRole() {
            var isStudent = document.getElementById('roleStudent').checked;
            document.getElementById('studentFields').classList.toggle('active', isStudent);
            document.getElementById('tutorNotice').classList.toggle('active', !isStudent);
        }

        // Validation patterns (mirrored server-side in RegisterServlet)
        var NAME_PATTERN = /^[A-Za-z]+([ '-][A-Za-z]+)+$/;      // at least two words, letters only
        var EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
        var PHONE_PATTERN = /^\d{10}$/;
        var DEPARTMENT_PATTERN = /^[A-Za-z]+(\s[A-Za-z]+)*$/;     // words and spaces only

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

        // Only allow digits to be typed into numeric-only fields
        ['phone'].forEach(function (id) {
            var el = document.getElementById(id);
            el.addEventListener('input', function () {
                el.value = el.value.replace(/\D/g, '');
            });
        });

        document.getElementById('registerForm').addEventListener('submit', function (e) {
            var isStudent = document.getElementById('roleStudent').checked;
            var valid = true;

            var name = document.getElementById('name');
            valid = showFieldError(name, document.getElementById('nameError'),
                NAME_PATTERN.test(name.value.trim())) && valid;

            var email = document.getElementById('email');
            valid = showFieldError(email, document.getElementById('emailError'),
                EMAIL_PATTERN.test(email.value.trim())) && valid;

            var phone = document.getElementById('phone');
            valid = showFieldError(phone, document.getElementById('phoneError'),
                PHONE_PATTERN.test(phone.value.trim())) && valid;

            if (isStudent) {
                var department = document.getElementById('department');
                valid = showFieldError(department, document.getElementById('departmentError'),
                    DEPARTMENT_PATTERN.test(department.value.trim())) && valid;
            }

            var password = document.getElementById('password');
            var confirmPassword = document.getElementById('confirmPassword');
            valid = showFieldError(confirmPassword, document.getElementById('confirmPasswordError'),
                password.value === confirmPassword.value) && valid;

            if (!valid) {
                e.preventDefault();
            }
        });
    </script>

</body>
</html>