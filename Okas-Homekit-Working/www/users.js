// www/users.js
// User Management page — programmer-only.
// First-time setup creates the owner's email+password. On an existing
// board the page shows the owner profile and lets the programmer change
// the owner email or reset the owner password. Both authenticated by the
// physical board access token, supplied server-side by ownerCredentials.php
// (the browser never sees it). Guest accounts are managed exclusively
// from the owner's mobile app and are intentionally not present here.

(() => {
    // ---- Helpers ----
    const setVisible = (el, show) => {
        if (!el) return;
        el.hidden = !show;
    };

    const strengthHint = (password) => {
        if (password.length < 8) return 'Too short';
        const has = {
            lower: /[a-z]/.test(password),
            upper: /[A-Z]/.test(password),
            digit: /\d/.test(password),
            symbol: /[^A-Za-z0-9]/.test(password),
        };
        const classes = Object.values(has).filter(Boolean).length;
        if (classes >= 3 && password.length >= 10) return 'Strong';
        if (classes >= 3) return 'OK';
        return `Need 1 of: ${[
            has.lower ? '' : 'lowercase',
            has.upper ? '' : 'uppercase',
            has.digit ? '' : 'digit',
            has.symbol ? '' : 'symbol',
        ].filter(Boolean).join(', ')}`;
    };

    // ---- Render: brand-new board vs existing owner ----
    const render = async () => {
        const status = await fetch(`${window.location.origin}/api/auth/status`)
            .then((r) => r.json())
            .catch(() => null);
        if (!status || !status.success) {
            showError('Could not reach the auth service.');
            return;
        }
        if (!status.hasAdmin) {
            setVisible(document.getElementById('setupSection'), true);
            setVisible(document.getElementById('adminSection'), false);
            // Bump the script handle if previously the page showed the
            // admin sections (edge: fresh board after a reset).
            document.getElementById('setupEmail').focus();
            return;
        }
        setVisible(document.getElementById('setupSection'), false);
        setVisible(document.getElementById('adminSection'), true);
    };

    const updateLabelPreview = () => {
        const value = document.getElementById('ownerLabel').value.trim();
        document.getElementById('labelPreview').textContent = value || '…';
    };
    const labelInput = document.getElementById('ownerLabel');
    if (labelInput) labelInput.addEventListener('input', updateLabelPreview);

    // ---- Change owner name ----
    document.getElementById('labelForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const label = document.getElementById('ownerLabel').value.trim();
        if (!label || label.length > 80) {
            showError('Display name must be 1-80 characters.');
            return;
        }
        const btn = document.getElementById('labelSave');
        btn.disabled = true;
        try {
            const body = new URLSearchParams();
            body.append('action', 'label');
            body.append('label', label);
            const response = await fetch(
                `${window.location.origin}/ownerCredentials.php`,
                { method: 'POST', body }
            );
            const data = await response.json();
            if (!response.ok || data.success === false) throw new Error(data.message || `HTTP ${response.status}`);
            showInfo('Owner name updated. It appears in the app home as "Hi, ' + label + '" on their next app visit.');
        } catch (err) {
            showError('Could not change name: ' + err.message);
        } finally {
            btn.disabled = false;
        }
    });

    // ---- First-time setup ----
    document.getElementById('setupForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const email = document.getElementById('setupEmail').value.trim();
        const password = document.getElementById('setupPassword').value;
        const label = document.getElementById('setupLabel').value.trim();
        const hint = strengthHint(password);
        if (hint !== 'Strong' && hint !== 'OK') {
            showError('Password too weak: ' + hint);
            return;
        }
        const btn = document.getElementById('setupSave');
        btn.disabled = true;
        try {
            const response = await fetch(`${window.location.origin}/api/auth/admin/setup`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password, label: label || undefined }),
            });
            const data = await response.json();
            if (!response.ok || data.success === false) throw new Error(data.message || `HTTP ${response.status}`);
            showInfo('Owner account created. They can now sign in from the mobile app.');
            await render();
        } catch (err) {
            showError('Setup failed: ' + err.message);
        } finally {
            btn.disabled = false;
        }
    });

    // ---- Change owner email ----
    document.getElementById('emailForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const email = document.getElementById('ownerEmail').value.trim();
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
            showError('Enter a valid email address.');
            return;
        }
        const btn = document.getElementById('emailSave');
        btn.disabled = true;
        try {
            const body = new URLSearchParams();
            body.append('action', 'email');
            body.append('email', email);
            const response = await fetch(
                `${window.location.origin}/ownerCredentials.php`,
                { method: 'POST', body }
            );
            const data = await response.json();
            if (!response.ok || data.success === false) throw new Error(data.message || `HTTP ${response.status}`);
            showInfo('Owner email updated.');
            document.getElementById('ownerEmail').value = '';
        } catch (err) {
            showError('Could not change email: ' + err.message);
        } finally {
            btn.disabled = false;
        }
    });

    // ---- Reset owner password ----
    document.getElementById('resetPasswordForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const next = document.getElementById('resetNewPassword').value;
        const confirm = document.getElementById('resetConfirmPassword').value;
        if (next !== confirm) {
            showError('New password and confirmation do not match.');
            return;
        }
        const hint = strengthHint(next);
        if (hint !== 'Strong' && hint !== 'OK') {
            showError('New password too weak: ' + hint);
            return;
        }
        const btn = document.getElementById('resetPasswordSave');
        btn.disabled = true;
        try {
            const body = new URLSearchParams();
            body.append('action', 'password');
            body.append('newPassword', next);
            const response = await fetch(
                `${window.location.origin}/ownerCredentials.php`,
                { method: 'POST', body }
            );
            const data = await response.json();
            if (!response.ok || data.success === false) throw new Error(data.message || `HTTP ${response.status}`);
            showInfo('Owner password reset. They will sign in with the new password.');
            document.getElementById('resetPasswordForm').reset();
        } catch (err) {
            showError('Could not reset password: ' + err.message);
        } finally {
            btn.disabled = false;
        }
    });

    // ---- Utilities ----
    const showError = (message) => {
        if (window.showError) { window.showError(message); return; }
        alert(message);
    };
    const showInfo = (message) => {
        if (window.showInfo) { window.showInfo(message); return; }
        alert(message);
    };

    // Live password-strength hints on both password fields.
    ['resetNewPassword'].forEach((id) => {
        const el = document.getElementById(id);
        if (el) {
            el.addEventListener('input', (e) => {
                const hint = strengthHint(e.target.value);
                e.target.setCustomValidity(hint === 'Strong' || hint === 'OK' ? '' : hint);
            });
        }
    });

    document.addEventListener('DOMContentLoaded', () => {
        render();
    });
})();