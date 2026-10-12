<%@ page import="com.peertutorconnect.dao.AvailabilityDAO" %>
<%@ page import="com.peertutorconnect.dao.TutorFeeDAO" %>
<%@ page import="com.peertutorconnect.dao.TutorDAO" %>
<%@ page import="com.peertutorconnect.util.EscapeUtil" %>
<%
    // Shows a warning on the tutor dashboard when the monthly fee is overdue (frozen) or due soon.
    // Silent when everything is paid or when anything goes wrong.
    try {
        Object fbUser = session.getAttribute("userId");
        if (fbUser != null && "TUTOR".equals(session.getAttribute("role"))) {
            Integer fbTutorId = new AvailabilityDAO().getTutorIdForUser((int) fbUser);
            if (fbTutorId != null && new TutorDAO().isVerified(fbTutorId)) {
                TutorFeeDAO fbDao = new TutorFeeDAO();
                fbDao.ensureRows();
                boolean fbFrozen = fbDao.isFrozen(fbTutorId);
                String fbDue = null;
                for (TutorFeeDAO.Fee fbFee : fbDao.getFeesForTutor(fbTutorId)) {
                    if ("DUE".equals(fbFee.status) || "REJECTED".equals(fbFee.status)) fbDue = fbFee.period;
                }
                String fbBase = request.getContextPath() + "/tutor-fees.jsp";
                if (fbFrozen) {
%>
<div style="background:#fbeae7;border:1px solid var(--error);color:var(--error);padding:14px 18px;border-radius:6px;margin-bottom:24px;font-size:14px;">
    <strong>Your account is flagged and frozen.</strong> Students cannot find or book you until your monthly fee is paid and approved.
    <a href="<%= fbBase %>" style="color:var(--error);font-weight:700;">Pay now</a>
</div>
<%
                } else if (fbDue != null) {
%>
<div style="background:#fdf1de;border:1px solid #e0a84a;color:#a2670e;padding:14px 18px;border-radius:6px;margin-bottom:24px;font-size:14px;">
    <strong>Monthly fee due:</strong> <%= EscapeUtil.html(TutorFeeDAO.monthLabel(fbDue)) %> &mdash;
    pay by <%= TutorFeeDAO.dueDate(fbDue) %> to keep your account active.
    <a href="<%= fbBase %>" style="color:#a2670e;font-weight:700;">Upload proof</a>
</div>
<%
                }
            }
        }
    } catch (Exception fbIgnored) {
        // never break the dashboard because of the fee banner
    }
%>