<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="com.peertutorconnect.dao.SubscriptionDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    if (session.getAttribute("role") == null || !"ADMIN".equals(session.getAttribute("role"))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }
    List<SubscriptionDAO.Payment> payments = new ArrayList<>();
    List<SubscriptionDAO.TutorRow> tutors = new ArrayList<>();
    String loadError = null;
    try {
        SubscriptionDAO dao = new SubscriptionDAO();
        payments = dao.getAllPayments();
        tutors = dao.getTutorRows();
    } catch (Exception e) {
        application.log("admin-subscriptions.jsp: could not load subscriptions", e);
        loadError = e.getMessage();
    }
    int pendingCount = 0;
    for (SubscriptionDAO.Payment p : payments) if ("PENDING".equals(p.status)) pendingCount++;
%>
<!DOCTYPE html>
<html>
<head>
    <title>PeerTutorConnect &mdash; Subscriptions</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <style>
        .dash-table { width: 100%; border-collapse: collapse; background: white; border: 1px solid var(--border-light); border-radius: 6px; overflow: hidden; margin-bottom: 28px; }
        .dash-table th, .dash-table td { text-align: left; padding: 12px 16px; font-size: 14px; border-bottom: 1px solid var(--border-light); vertical-align: top; }
        .dash-table th { background: var(--cream); color: var(--navy); font-size: 12px; text-transform: uppercase; }
        .pill { display: inline-block; padding: 3px 10px; border-radius: 3px; font-size: 12px; font-weight: 600; }
        .pill-PENDING { background: #fdf1de; color: #a2670e; }
        .pill-APPROVED, .pill-ACTIVE { background: #e8f4ec; color: #1f6b3a; }
        .pill-REJECTED, .pill-FROZEN { background: #fbeae7; color: var(--error); }
        .act-form { display: inline-block; margin: 0 4px 4px 0; }
        .reason-input { padding: 6px 8px; font-size: 12px; border: 1px solid var(--border-light); border-radius: 4px; width: 170px; font-family: inherit; }
        h2.sec { color: var(--navy); font-size: 1.1rem; margin: 6px 0 12px; }
    </style>
</head>
<body>
<div class="app-shell">
    <jsp:include page="includes/sidebar.jsp" />
    <main class="app-main">
        <div class="page-heading">
            <h1>Tutor Subscriptions</h1>
            <p>Tutors pay <%= SubscriptionDAO.formatFee() %> per month. Approve a payment to keep the tutor active. Tutors who don't pay by month end are flagged and frozen, so nobody can book them.</p>
        </div>

        <div class="page-wrap">
        <% if (loadError != null) { %>
            <div class="empty-state">Could not load subscriptions: <%= EscapeUtil.html(loadError) %></div>
        <% } else { %>

            <h2 class="sec">Payments to review (<%= pendingCount %>)</h2>
            <% if (pendingCount == 0) { %>
                <div class="empty-state" style="margin-bottom:28px;">No payments waiting.</div>
            <% } else { %>
                <div class="table-wrapper">
                <table class="dash-table">
                    <thead><tr><th>Tutor</th><th>Month</th><th>Amount</th><th>Submitted</th><th>Proof</th><th>Action</th></tr></thead>
                    <tbody>
                    <% for (SubscriptionDAO.Payment p : payments) { if (!"PENDING".equals(p.status)) continue; %>
                        <tr>
                            <td><strong><%= EscapeUtil.html(p.tutorName == null ? "(removed account)" : p.tutorName) %></strong></td>
                            <td><%= SubscriptionDAO.prettyPeriod(p.period) %></td>
                            <td>R<%= String.format("%.2f", p.amount) %></td>
                            <td><%= p.submittedAt %></td>
                            <td><a href="<%= request.getContextPath() %>/subscription-proof?paymentId=<%= p.paymentId %>" target="_blank">View proof</a></td>
                            <td>
                                <form method="post" action="<%= request.getContextPath() %>/admin-subscriptions" class="act-form">
                                    <input type="hidden" name="action" value="approve">
                                    <input type="hidden" name="paymentId" value="<%= p.paymentId %>">
                                    <button type="submit" class="btn btn-primary">Approve</button>
                                </form>
                                <form method="post" action="<%= request.getContextPath() %>/admin-subscriptions" class="act-form">
                                    <input type="hidden" name="action" value="reject">
                                    <input type="hidden" name="paymentId" value="<%= p.paymentId %>">
                                    <input type="text" name="reason" class="reason-input" placeholder="Reason for rejecting" required maxlength="300">
                                    <button type="submit" class="btn btn-danger">Reject</button>
                                </form>
                            </td>
                        </tr>
                    <% } %>
                    </tbody>
                </table>
                </div>
            <% } %>

            <h2 class="sec">Tutor accounts</h2>
            <% if (tutors.isEmpty()) { %>
                <div class="empty-state" style="margin-bottom:28px;">No verified tutors yet.</div>
            <% } else { %>
                <div class="table-wrapper">
                <table class="dash-table">
                    <thead><tr><th>Tutor</th><th>Paid until</th><th>Status</th></tr></thead>
                    <tbody>
                    <% for (SubscriptionDAO.TutorRow t : tutors) { %>
                        <tr>
                            <td><%= EscapeUtil.html(t.name) %></td>
                            <td><%= t.paidUntil %></td>
                            <td>
                                <% if (t.frozen) { %><span class="pill pill-FROZEN">Frozen</span>
                                <% } else { %><span class="pill pill-ACTIVE">Active</span><% } %>
                                <% if (t.hasPending) { %> <span class="pill pill-PENDING">Payment to review</span><% } %>
                            </td>
                        </tr>
                    <% } %>
                    </tbody>
                </table>
                </div>
            <% } %>

            <h2 class="sec">Payment history</h2>
            <% boolean anyDone = false; for (SubscriptionDAO.Payment p : payments) if (!"PENDING".equals(p.status)) anyDone = true; %>
            <% if (!anyDone) { %>
                <div class="empty-state">No reviewed payments yet.</div>
            <% } else { %>
                <div class="table-wrapper">
                <table class="dash-table">
                    <thead><tr><th>Tutor</th><th>Month</th><th>Amount</th><th>Reviewed</th><th>Status</th><th>Proof</th></tr></thead>
                    <tbody>
                    <% for (SubscriptionDAO.Payment p : payments) { if ("PENDING".equals(p.status)) continue; %>
                        <tr>
                            <td><%= EscapeUtil.html(p.tutorName == null ? "(removed account)" : p.tutorName) %></td>
                            <td><%= SubscriptionDAO.prettyPeriod(p.period) %></td>
                            <td>R<%= String.format("%.2f", p.amount) %></td>
                            <td><%= p.reviewedAt %></td>
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

<% if ("true".equals(request.getParameter("approved"))) { %>
    <script>showToast('Payment approved.', 'success');</script>
<% } %>
<% if ("true".equals(request.getParameter("rejected"))) { %>
    <script>showToast('Payment rejected and the tutor was told why.', 'success');</script>
<% } %>
<%
    String err = request.getParameter("error");
    if (err != null) {
        String errMsg = "resolved".equals(err) ? "That payment was already handled."
                : "noreason".equals(err) ? "Please give a reason for rejecting."
                : "Something went wrong. Please try again.";
%>
    <script>showToast('<%= errMsg %>', 'error');</script>
<% } %>
</body>
</html>