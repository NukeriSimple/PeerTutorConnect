<%
    // Render the toast container and showToast() only once per page,
    // even if both sidebar.jsp and footer.jsp include this file.
    if (request.getAttribute("toastRendered") == null) {
        request.setAttribute("toastRendered", Boolean.TRUE);
%>
<div id="toast-container"></div>
<script>
    function showToast(message, type) {
        const container = document.getElementById('toast-container');
        const toast = document.createElement('div');
        toast.className = 'toast ' + (type || 'success');
        toast.textContent = message;
        container.appendChild(toast);

        setTimeout(() => {
            toast.classList.add('hide');
            setTimeout(() => toast.remove(), 300);
        }, 3500);
    }
</script>
<% } %>