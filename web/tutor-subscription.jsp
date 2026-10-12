<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="com.peertutorconnect.dao.AvailabilityDAO" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
<%@ page import="com.peertutorconnect.dao.SubscriptionDAO" %>
<%@ page import="com.peertutorconnect.util.AppConfig" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"TUTOR".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }
    int userId = (int) session.getAttribute("userId");
    Integer tutorId = new AvailabilityDAO().getTutorIdForUser(userId);
    if (tutorId == null || !new TutorDAO().isVerified(tutorId)) {
        response.sendRedirect(request.getContextPath() + "/tutor-dashboard.jsp");
        return;
    }

    SubscriptionDAO.Status st = null;
    List<SubscriptionDAO.Payment> history = new ArrayList<>();
    String loadError = null;
    try {
        SubscriptionDAO dao = new SubscriptionDAO();
        st = dao.getStatus(tutorId);
        history = dao.getPaymentsForTutor(tutorId);
    } catch (Exception e) {
        application.log("tutor-subscription.jsp: could not load subscription", e);
        loadError = e.getMessage();
    }
    String payDetails = AppConfig.get("subscription.payment.details",
            "Ask the admin for the payment details.");
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Subscription</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .sub-card { background: white; border: 1px solid var(--border-light); border-radius: 6px; padding: 20px 22px; margin-bottom: 22px; }
        .sub-card h2 { color: var(--navy); font-size: 1.1rem; margin-bottom: 10px; }
        .sub-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 16px; }
        .sub-grid .num { font-size: 1.4rem; font-weight: 700; color: var(--navy); }
        .sub-grid .lbl { font-size: 11px; font-weight: 600; color: var(--text-muted); text-transform: uppercase; margin-top: 4px; }
        .banner-frozen { background: #fbeae7; color: var(--error); border: 1px solid #f0c4bd; border-radius: 6px; padding: 14px 18px; margin-bottom: 22px; font-weight: 600; }
        .banner-ok { background: #e8f4ec; color: #1f6b3a; border: 1px solid #bfe0c9; border-radius: 6px; padding: 14px 18px; margin-bottom: 22px; font-weight: 600; }
        .banner-wait { background: #fdf1de; color: #a2670e; border: 1px solid #f0d9ae; border-radius: 6px; padding: 14px 18px; margin-bottom: 22px; font-weight: 600; }
        .pay-box { background: var(--cream); border-radius: 6px; padding: 12px 14px; font-size: 14px; white-space: pre-wrap; margin: 10px 0 16px; }
        .dash-table { width: 100%; border-collapse: collapse; background: white; border: 1px solid var(--border-light); border-radius: 6px; overflow: hidden; }
        .dash-table th, .dash-table td { text-align: left; padding: 12px 16px; font-size: 14px; border-bottom: 1px solid var(--border-light); vertical-align: top; }
        .dash-table th { background: var(--cream); color: var(--navy); font-size: 12px; text-transform: uppercase; }
        .pill { display: inline-block; padding: 3px 10px; border-radius: 3px; font-size: 12px; font-weight: 600; }
        .pill-PENDING { background: #fdf1de; color: #a2670e; }
        .pill-APPROVED { background: #e8f4ec; color: #1f6b3a; }
        .pill-REJECTED { background: #fbeae7; color: var(--error); }
        .upload-row { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">
        <div class="page-heading">
            <h1>Subscription</h1>
            <p>Tutors pay <%= SubscriptionDAO.formatFee() %> per month to stay listed and bookable. Pay the admin, then upload your proof of payment here.</p>
        </div>

        <div class="page-wrap">
        <% if (loadError != null || st == null) { %>
            <div class="empty-state">Could not load your subscription<%= loadError != null ? ": " + EscapeUtil.html(loadError) : "." %></div>
        <% } else { %>

            <% if (st.frozen) { %>
                <div class="banner-frozen">Your account is frozen. Students can't see or book you until you pay for
                    <%= SubscriptionDAO.prettyPeriod(st.nextPeriod) %> and the admin approves it.</div>
            <% } else if (st.hasPending) { %>
                <div class="banner-wait">Your payment is waiting for the admin to review it.</div>
            <% } else { %>
                <div class="banner-ok">Your account is active until <%= st.paidUntil %>.</div>
            <% } %>

            <div class="sub-card">
                <div class="sub-grid">
                    <div><div class="num"><%= SubscriptionDAO.formatFee() %></div><div class="lbl">Monthly fee</div></div>
                    <div><div class="num"><%= st.paidUntil %></div><div class="lbl">Paid until</div></div>
                    <div><div class="num"><%= SubscriptionDAO.prettyPeriod(st.nextPeriod) %></div><div class="lbl">Next month to pay</div></div>
                </div>
            </div>

            <% if (!st.hasPending) { %>
            <div class="sub-card">
                <h2>Pay for <%= SubscriptionDAO.prettyPeriod(st.nextPeriod) %></h2>
                <p>Pay <strong><%= SubscriptionDAO.formatFee() %></strong> to:</p>
                <div class="pay-box"><%= EscapeUtil.html(payDetails) %></div>
                <form method="post" action="<%= request.getContextPath() %>/tutor-subscription" enctype="multipart/form-data" class="upload-row">
                    <input type="file" name="proof" accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png" required>
                    <button type="submit" class="btn btn-primary">Upload proof of payment</button>
                </form>
                <p style="font-size:12px;color:var(--text-muted);margin-top:8px;">PDF, JPG or PNG, up to 5 MB. You'll get a reminder 4 days before month end.</p>
            </div>
            <% } %>

            <h2 style="color:var(--navy);font-size:1.1rem;margin:8px 0 12px;">Payment history</h2>
            <% if (history.isEmpty()) { %>
                <div class="empty-state">No payments yet.</div>
            <% } else { %>
                <div class="table-wrapper">
                <table class="dash-table">
                    <thead><tr><th>Month</th><th>Amount</th><th>Submitted</th><th>Status</th><th>Proof</th></tr></thead>
                    <tbody>
                    <% for (SubscriptionDAO.Payment p : history) { %>
                        <tr>
                            <td><%= SubscriptionDAO.prettyPeriod(p.period) %></td>
                            <td>R<%= String.format("%.2f", p.amount) %></td>
                            <td><%= p.submittedAt %></td>
                            <td>
                                <span class="pill pill-<%= p.status %>"><%= p.status.charAt(0) + p.status.substring(1).toLowerCase() %></span>
                                <% if ("REJECTED".equals(p.status) && p.rejectReason != null) { %>
                                    <div style="font-size:12px;color:var(--text-muted);margin-top:4px;"><%= EscapeUtil.html(p.rejectReason) %></div>
                                <% } %>
                            </td>
                            <td><a href="<%= request.getContextPath() %>/subscription-proof?paymentId=<%= p.paymentId %>" target="_blank">View</a></td>
                        </tr>
                    <% } %>
                    </tbody>
                </table>
                </div>
            <% } %>
        <% } %>
        </div>
    </main>
</div>

<% if ("true".equals(request.getParameter("submitted"))) { %>
    <script>showToast('Proof uploaded. The admin will review it.', 'success');</script>
<% } %>
<%
    String err = request.getParameter("error");
    if (err != null) {
        String errMsg = "nofile".equals(err) ? "Please choose a file to upload."
                : "badfile".equals(err) ? "Upload a real PDF, JPG or PNG up to 5 MB."
                : "pending".equals(err) ? "You already have a payment waiting for review."
                : "notallowed".equals(err) ? "Your account can't submit a payment yet."
                : "Something went wrong. Please try again.";
%>
    <script>showToast('<%= errMsg %>', 'error');</script>
<% } %>
</body>
</html>