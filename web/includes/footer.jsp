<style>
    footer .footer-social {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
        margin-top: 4px;
    }

    footer .footer-social a {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 40px;
        height: 40px;
        margin: 0;
        border-radius: 50%;
        background: rgba(255, 255, 255, 0.1);
        color: #ffffff;
        transition: background-color 0.2s ease, transform 0.2s ease;
    }

    footer .footer-social a:hover {
        background: var(--orange);
        color: #ffffff;
        transform: translateY(-2px);
    }

    footer .footer-social svg {
        width: 20px;
        height: 20px;
        display: block;
    }
</style>

<footer>
    <div class="footer-columns">
        <div>
            <h4>Peer<span class="logo-accent">Tutor</span>Connect</h4>
            <p>Connecting students with verified peer tutors.</p>
        </div>
        <div>
            <h4>Quick Links</h4>
            <a href="<%= request.getContextPath() %>/index.jsp#tutors">Find a Tutor</a>
            <a href="<%= request.getContextPath() %>/register.jsp">Become a Tutor</a>
        </div>
        <div>
            <h4>Our Mission</h4>
            <p>Making quality tutoring accessible to all students.</p>
        </div>
        <div>
            <h4>Contact Us</h4>
            <div class="footer-social">

                <!-- Email -->
                <a href="mailto:nukerisimple@gmail.com" title="Email us" aria-label="Email us">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                        <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
                        <polyline points="22,6 12,13 2,6"/>
                    </svg>
                </a>

                <!-- Phone call -->
                <a href="tel:0810284592" title="Call us: 081 028 4592" aria-label="Call us">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                        <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/>
                    </svg>
                </a>

                <!-- WhatsApp -->
                <a href="https://wa.me/27810284592" target="_blank" rel="noopener noreferrer" title="WhatsApp us: 081 028 4592" aria-label="WhatsApp us">
                    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                        <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
                    </svg>
                </a>

                <!-- Facebook -->
                <a href="https://www.facebook.com/share/1HYgjtCcZB/?mibextid=wwXIfr" target="_blank" rel="noopener noreferrer" title="Follow us on Facebook" aria-label="Follow us on Facebook">
                    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                        <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
                    </svg>
                </a>

            </div>
        </div>
    </div>
    <div class="footer-bottom">
        &copy; PeerTutorConnect. Built by TechFusion.
    </div>
</footer>

<jsp:include page="toast.jsp" />

<script>
(function () {
    const EDGE_TOLERANCE = 3;

    function maxScroll() {
        return Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
    }

    function isAtTop() {
        return window.scrollY <= EDGE_TOLERANCE;
    }

    function isAtBottom() {
        return window.scrollY >= maxScroll() - EDGE_TOLERANCE;
    }

    function clampScroll() {
        const max = maxScroll();
        if (window.scrollY < 0) {
            window.scrollTo(0, 0);
        } else if (window.scrollY > max) {
            window.scrollTo(0, max);
        }
    }

    function preventWheelOverscroll(e) {
        const deltaY = e.deltaY !== undefined ? e.deltaY : 0;
        if ((isAtTop() && deltaY < 0) || (isAtBottom() && deltaY > 0)) {
            e.preventDefault();
        }
    }

    let touchStartY = 0;

    function onTouchStart(e) {
        touchStartY = e.touches[0].clientY;
    }

    function onTouchMove(e) {
        const touchY = e.touches[0].clientY;
        const movingDown = touchY > touchStartY;
        const movingUp = touchY < touchStartY;

        if ((isAtTop() && movingDown) || (isAtBottom() && movingUp)) {
            e.preventDefault();
        }
    }

    document.addEventListener('wheel', preventWheelOverscroll, { passive: false, capture: true });
    document.addEventListener('touchstart', onTouchStart, { passive: true, capture: true });
    document.addEventListener('touchmove', onTouchMove, { passive: false, capture: true });

    // Safety net: snap back immediately if any momentum/inertia scroll
    // still slips past the edge despite the guards above.
    let clampTicking = false;
    function onScroll() {
        if (!clampTicking) {
            clampTicking = true;
            requestAnimationFrame(function () {
                clampScroll();
                clampTicking = false;
            });
        }
    }
    document.addEventListener('scroll', onScroll, { passive: true });

    // Re-check on resize, since scrollHeight/innerHeight can change
    // (e.g. mobile address bar collapsing).
    window.addEventListener('resize', clampScroll);
})();
</script>