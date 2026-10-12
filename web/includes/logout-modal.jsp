<%
    // Render the logout confirmation modal only once per page,
    // even if both header.jsp and sidebar.jsp are included.
    if (request.getAttribute("logoutModalRendered") == null) {
        request.setAttribute("logoutModalRendered", Boolean.TRUE);
%>
<div id="logout-modal" class="modal-overlay" role="dialog" aria-modal="true"
     aria-labelledby="logout-modal-title" aria-describedby="logout-modal-text">
    <div class="modal-box">
        <h3 id="logout-modal-title">Log out?</h3>
        <p id="logout-modal-text">Are you sure you want to log out of PeerTutorConnect?</p>
        <div class="modal-actions">
            <button type="button" id="logout-cancel" class="btn btn-secondary">Stay logged in</button>
            <button type="button" id="logout-confirm" class="btn btn-danger">Yes, log out</button>
        </div>
    </div>
</div>

<script>
(function () {
    var modal = document.getElementById('logout-modal');
    var confirmBtn = document.getElementById('logout-confirm');
    var cancelBtn = document.getElementById('logout-cancel');
    var logoutUrl = null;
    var lastFocused = null;

    function openModal(url) {
        logoutUrl = url;
        lastFocused = document.activeElement;
        modal.classList.add('open');
        cancelBtn.focus();
    }

    function closeModal() {
        modal.classList.remove('open');
        logoutUrl = null;
        if (lastFocused && lastFocused.focus) {
            lastFocused.focus();
        }
    }

    // Intercept every logout link on the page
    document.addEventListener('click', function (e) {
        var link = e.target.closest ? e.target.closest('a[data-logout]') : null;
        if (!link) return;
        e.preventDefault();
        openModal(link.href);
    });

    confirmBtn.addEventListener('click', function () {
        if (logoutUrl) {
            window.location.href = logoutUrl;
        }
    });

    cancelBtn.addEventListener('click', closeModal);

    // Click on the dark backdrop closes the modal
    modal.addEventListener('click', function (e) {
        if (e.target === modal) closeModal();
    });

    document.addEventListener('keydown', function (e) {
        if (!modal.classList.contains('open')) return;

        if (e.key === 'Escape') {
            closeModal();
            return;
        }

        // Keep keyboard focus inside the modal
        if (e.key === 'Tab') {
            var first = cancelBtn;
            var last = confirmBtn;
            if (e.shiftKey && document.activeElement === first) {
                e.preventDefault();
                last.focus();
            } else if (!e.shiftKey && document.activeElement === last) {
                e.preventDefault();
                first.focus();
            }
        }
    });
})();
</script>
<% } %>