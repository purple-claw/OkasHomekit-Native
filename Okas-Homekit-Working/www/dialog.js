(function (global) {
  function getDialogElements(modalId) {
    const modalEl = document.getElementById(modalId || "genModal");
    if (!modalEl || !window.bootstrap || !bootstrap.Modal) return null;

    const titleEl = modalEl.querySelector("#gmTitle") || modalEl.querySelector(".modal-title");
    const bodyEl = modalEl.querySelector("#eModTxt") || modalEl.querySelector(".modal-body");
    const confirmBtn = modalEl.querySelector("#cYESbtn");
    const cancelBtn = modalEl.querySelector("#cNObtn");
    const contentEl = modalEl.querySelector(".modal-content");

    if (!titleEl || !bodyEl || !confirmBtn) return null;
    return { modalEl, titleEl, bodyEl, confirmBtn, cancelBtn, contentEl };
  }

  function setDialogTheme(contentEl, titleEl, type) {
    const dialogType = type || "info";

    if (contentEl) {
      contentEl.dataset.dialogType = dialogType;
      contentEl.classList.remove("dialog-error", "dialog-info", "dialog-warning", "dialog-success");
      contentEl.classList.add(`dialog-${dialogType}`);
    }

    if (titleEl) {
      titleEl.classList.remove("dialog-title-error", "dialog-title-info", "dialog-title-warning", "dialog-title-success");
      titleEl.classList.add(`dialog-title-${dialogType}`);
    }
  }

  function fallbackDialog(options) {
    const title = options.title || "Notice";
    const message = options.message || "";
    const type = options.type || "info";
    const emojiMap = { error: "❌", warning: "⚠️", info: "ℹ️", success: "✅" };
    const prefix = emojiMap[type] || "";
    if (options.showCancel) {
      return Promise.resolve(window.confirm(`${prefix} ${title}\n\n${message}`) ? "confirm" : "cancel");
    }

    window.alert(`${prefix} ${title}\n\n${message}`);
    return Promise.resolve("confirm");
  }

  function showAppDialog(options = {}) {
    const dialog = getDialogElements(options.modalId || "genModal");
    if (!dialog) return fallbackDialog(options);

    const {
      modalEl,
      titleEl,
      bodyEl,
      confirmBtn,
      cancelBtn,
      contentEl
    } = dialog;

    const title = options.title || "Notice";
    const message = options.message || "";
    const type = options.type || "info";
    const confirmText = options.confirmText || "OK";
    const cancelText = options.cancelText || "Cancel";
    const showCancel = Boolean(options.showCancel);
    const modal = bootstrap.Modal.getOrCreateInstance(modalEl);

    const emojiMap = { error: "❌", warning: "⚠️", info: "ℹ️", success: "✅" };
    titleEl.textContent = (emojiMap[type] || "") + " " + title;
    bodyEl.textContent = message;
    setDialogTheme(contentEl, titleEl, type);

    confirmBtn.textContent = confirmText;
    if (cancelBtn) {
      cancelBtn.textContent = cancelText;
      cancelBtn.style.display = showCancel ? "" : "none";
    }

    return new Promise((resolve) => {
      let settled = false;

      const finish = (value) => {
        if (settled) return;
        settled = true;
        modalEl.removeEventListener("hidden.bs.modal", onHidden);
        resolve(value);
      };

      const onConfirm = () => {
        finish("confirm");
        modal.hide();
      };

      const onCancel = () => {
        finish("cancel");
        modal.hide();
      };

      const onHidden = () => {
        if (!settled) {
          finish(showCancel ? "cancel" : "confirm");
        }
      };

      confirmBtn.addEventListener("click", onConfirm, { once: true });
      if (cancelBtn) {
        cancelBtn.addEventListener("click", onCancel, { once: true });
      }

      modalEl.addEventListener("hidden.bs.modal", onHidden, { once: true });
      modal.show();
    });
  }

  global.showAppDialog = showAppDialog;
  global.showError = function (message, options = {}) {
    return showAppDialog({
      title: options.title || "Error",
      message,
      type: "error",
      confirmText: options.confirmText || "OK",
      modalId: options.modalId || "genModal",
      showCancel: false
    });
  };
  global.showInfo = function (message, options = {}) {
    return showAppDialog({
      title: options.title || "Information",
      message,
      type: options.type || "info",
      confirmText: options.confirmText || "OK",
      modalId: options.modalId || "genModal",
      showCancel: false
    });
  };
  global.showValidationDialog = function (message, options = {}) {
    return showAppDialog({
      title: options.title || "Validation",
      message,
      type: options.type || "warning",
      confirmText: options.confirmText || "OK",
      cancelText: options.cancelText || "Cancel",
      modalId: options.modalId || "genModal",
      showCancel: true
    });
  };
  global.showConfirmDialog = function (message, options = {}) {
    return showAppDialog({
      title: options.title || "Confirm",
      message,
      type: options.type || "info",
      confirmText: options.confirmText || "Yes",
      cancelText: options.cancelText || "No",
      modalId: options.modalId || "genModal",
      showCancel: true
    });
  };
})(window);