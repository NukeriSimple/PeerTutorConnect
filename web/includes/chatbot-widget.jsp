<div id="chatbot-bubble" onclick="toggleChatbot()">
    <svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
        <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>
    </svg>
</div>

<div id="chatbot-window">
    <div id="chatbot-header">
        <span>PeerTutorConnect Assistant</span>
        <span id="chatbot-close" onclick="toggleChatbot()">&times;</span>
    </div>
    <div id="chatbot-messages">
        <div class="chat-msg bot">Hi! I'm here to help with anything about PeerTutorConnect &mdash; finding tutors, booking sessions, or how the platform works. What can I help with?</div>
    </div>
    <div id="chatbot-input-row">
        <input type="text" id="chatbot-input" placeholder="Type a message..." onkeydown="if(event.key==='Enter') sendChatMessage()">
        <button onclick="sendChatMessage()">Send</button>
    </div>
</div>

<style>
    #chatbot-bubble {
        position: fixed;
        bottom: 24px;
        right: 24px;
        width: 56px;
        height: 56px;
        background-color: var(--orange);
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        box-shadow: 0 4px 14px rgba(0,0,0,0.25);
        z-index: 999;
        transition: transform 0.2s ease;
    }

    #chatbot-bubble:hover {
        transform: scale(1.08);
    }

    #chatbot-window {
        position: fixed;
        bottom: 92px;
        right: 24px;
        width: 320px;
        max-width: calc(100vw - 32px);
        height: 420px;
        max-height: calc(100vh - 140px);
        background: white;
        border-radius: 10px;
        box-shadow: 0 8px 30px rgba(0,0,0,0.25);
        display: none;
        flex-direction: column;
        overflow: hidden;
        z-index: 999;
    }

    #chatbot-window.open {
        display: flex;
    }

    #chatbot-header {
        background-color: var(--navy);
        color: white;
        padding: 14px 16px;
        font-size: 14px;
        font-weight: 600;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    #chatbot-close {
        cursor: pointer;
        font-size: 20px;
        line-height: 1;
    }

    #chatbot-messages {
        flex: 1;
        overflow-y: auto;
        padding: 14px;
        display: flex;
        flex-direction: column;
        gap: 10px;
        background: var(--cream);
    }

    .chat-msg {
        max-width: 85%;
        padding: 9px 12px;
        border-radius: 10px;
        font-size: 13px;
        line-height: 1.4;
    }

    .chat-msg.bot {
        background: white;
        border: 1px solid var(--border-light);
        color: var(--text-dark);
        align-self: flex-start;
    }

    .chat-msg.user {
        background: var(--navy);
        color: white;
        align-self: flex-end;
    }

    .chat-msg.typing {
        color: var(--text-muted);
        font-style: italic;
    }

    #chatbot-input-row {
        display: flex;
        border-top: 1px solid var(--border-light);
        padding: 10px;
        gap: 8px;
    }

    #chatbot-input-row input {
        flex: 1;
        padding: 8px 10px;
        font-size: 13px;
    }

    #chatbot-input-row button {
        background: var(--orange);
        color: white;
        border: none;
        padding: 8px 14px;
        border-radius: 4px;
        font-size: 13px;
        font-weight: 600;
        cursor: pointer;
    }

    @media (max-width: 500px) {
        #chatbot-window {
            width: calc(100vw - 24px);
            right: 12px;
            bottom: 84px;
        }
        #chatbot-bubble {
            right: 16px;
            bottom: 16px;
        }
    }
</style>

<script>
    function toggleChatbot() {
        document.getElementById('chatbot-window').classList.toggle('open');
    }

    function sendChatMessage() {
        const input = document.getElementById('chatbot-input');
        const message = input.value.trim();
        if (!message) return;

        const messagesDiv = document.getElementById('chatbot-messages');

        const userDiv = document.createElement('div');
        userDiv.className = 'chat-msg user';
        userDiv.textContent = message;
        messagesDiv.appendChild(userDiv);

        input.value = '';
        messagesDiv.scrollTop = messagesDiv.scrollHeight;

        const typingDiv = document.createElement('div');
        typingDiv.className = 'chat-msg bot typing';
        typingDiv.id = 'typing-indicator';
        typingDiv.textContent = 'Typing...';
        messagesDiv.appendChild(typingDiv);
        messagesDiv.scrollTop = messagesDiv.scrollHeight;

        fetch(window.contextPathForChatbot + '/chatbot', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ message: message })
        })
        .then(res => res.json())
        .then(data => {
            const typing = document.getElementById('typing-indicator');
            if (typing) typing.remove();

            const botDiv = document.createElement('div');
            botDiv.className = 'chat-msg bot';
            botDiv.textContent = data.reply || data.error || 'Something went wrong.';
            messagesDiv.appendChild(botDiv);
            messagesDiv.scrollTop = messagesDiv.scrollHeight;
        })
        .catch(() => {
            const typing = document.getElementById('typing-indicator');
            if (typing) typing.remove();

            const errDiv = document.createElement('div');
            errDiv.className = 'chat-msg bot';
            errDiv.textContent = 'Sorry, I could not connect. Please try again.';
            messagesDiv.appendChild(errDiv);
        });
    }
</script>