// Rooms page: shares its session with the Configuration page (same key, same KNXdata shape).
const KNX_SESSION_KEY = "okas_knx_session_v1";
let KNXdata = { prjNm: "", knxIp: "", knxPort: 3671, loads: [], rooms: [] };
let roomEditIndex = -1;
let selRoomIdx = -1;
let draftLoads = new Set(); // loads assigned to the room being edited, live

// Accent hue per load type: the dot on cards, so a scan reads the mix at a glance.
const ldTypHue = {
    Switch: "#00afd2",
    Dimmer: "#f0a000",
    RGB: "#8e5bd6",
    Tunable: "#e8590c",
    HVAC: "#0ca678",
    Scene: "#3b82f6",
    Fan: "#5c7cfa",
    Curtain: "#d63384"
};
const loadTypeOrder = ["Switch", "Dimmer", "Tunable", "RGB", "Fan", "Curtain", "Scene", "HVAC"];

function escHtml(value) {
    return String(value ?? "").replace(/[&<>"']/g, function (char) {
        return {
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            '"': "&quot;",
            "'": "&#39;"
        }[char];
    });
}

function loadSession() {
    let raw;
    try {
        raw = sessionStorage.getItem(KNX_SESSION_KEY);
    } catch (_) { return false; }
    if (!raw) return false;
    try {
        const cached = JSON.parse(raw);
        if (!cached || typeof cached !== "object" || !Array.isArray(cached.loads)) return false;
        KNXdata = {
            prjNm: cached.prjNm ?? "",
            knxIp: cached.knxIp ?? "",
            knxPort: cached.knxPort ?? 3671,
            loads: cached.loads,
            rooms: cached.rooms ?? []
        };
        return true;
    } catch (_) {
        return false;
    }
}

function persistSession() {
    try {
        sessionStorage.setItem(KNX_SESSION_KEY, JSON.stringify(KNXdata));
    } catch (_) { /* sessionStorage unavailable, ignore */ }
}

function loadOf(boardIdx) {
    return KNXdata.loads[boardIdx - 1]; // board loads are 1-based; index 0 is project meta
}

function groupedLoads() {
    const grouped = KNXdata.loads.reduce((acc, load, i) => {
        if (!load || !load.ldNm) return acc; // skip meta/garbage entries
        const type = load.ldTyp || "Switch";
        if (!acc[type]) acc[type] = [];
        acc[type].push({ load, boardIdx: i + 1 });
        return acc;
    }, {});
    return loadTypeOrder.filter((type) => grouped[type]).map((type) => ({ type, items: grouped[type] }));
}

// ---- Right pane: ALL loads, toggleable squircle cards --------------------

function renderLoadPalette() {
    const can = document.getElementById("typeCan");
    const count = document.getElementById("detailCount");
    const lead = document.getElementById("detailLead");
    if (!can) return;

    const editing = roomEditIndex >= 0 ? KNXdata.rooms[roomEditIndex] : null;
    lead.innerHTML = editing
        ? `Click loads to add or remove them from <b>${escHtml(editing.name)}</b>.`
        : "Click a load card to assign it to the new room.";
    count.textContent = KNXdata.loads.length === 0 ? "" : `${KNXdata.loads.length} load${KNXdata.loads.length === 1 ? "" : "s"}`;

    if (KNXdata.loads.length === 0) {
        can.innerHTML = `<div class="detail-empty">
            <div class="detail-empty-title">No loads configured yet</div>
            <div class="detail-empty-sub">Add loads in the Configuration page first, then build rooms here.</div>
        </div>`;
        return;
    }

    can.innerHTML = groupedLoads().map(({ type, items }) => {
        const hue = ldTypHue[type] || "#00afd2";
        const cards = items.map(({ load, boardIdx }) => {
            const inRoom = draftLoads.has(boardIdx);
            return `<div class="load-card${inRoom ? " selected" : ""}" style="--card-hue:${hue}" role="button" tabindex="0"
                onclick="toggleInRoom(${boardIdx})"
                onkeydown="if(event.key === 'Enter' || event.key === ' '){event.preventDefault(); toggleInRoom(${boardIdx});}"
                title="${inRoom ? "Click to remove from room" : "Click to add to room"}">
                <span class="load-card-name">${escHtml(load.ldNm)}</span>
                <span class="load-card-check" aria-hidden="true">${inRoom ? "&#10003;" : ""}</span>
            </div>`;
        }).join("");
        return `<div class="type-group">
            <div class="type-group-title">
                <span class="type-dot" style="background:${hue}"></span>
                <span>${escHtml(type)}</span>
                <span class="load-count">${items.length}</span>
            </div>
            <div class="load-card-grid">${cards}</div>
        </div>`;
    }).join("");
}

function toggleInRoom(boardIdx) {
    if (draftLoads.has(boardIdx)) draftLoads.delete(boardIdx);
    else draftLoads.add(boardIdx);
    renderLoadPalette();
    renderEditorLoads();
    syncEditorMode();
}

// ---- Left pane, editor card: name + real-time assigned loads -------------

function renderEditorLoads() {
    const list = document.getElementById("roomLoadList");
    if (!list) return;
    if (KNXdata.loads.length === 0) {
        list.innerHTML = `<div class="empty-text">No loads configured yet.</div>`;
        return;
    }
    if (draftLoads.size === 0) {
        list.innerHTML = `<div class="assign-empty">No loads assigned yet — click load cards on the right.</div>`;
        return;
    }
    list.innerHTML = Array.from(draftLoads).sort((a, b) => a - b).map((boardIdx) => {
        const load = loadOf(boardIdx);
        if (!load) return "";
        const type = load.ldTyp || "Switch";
        const hue = ldTypHue[type] || "#00afd2";
        return `<div class="assign-chip" style="--card-hue:${hue}">
            <span class="assign-chip-name">${escHtml(load.ldNm)}</span>
            <button type="button" class="assign-chip-del" title="Remove load"
                onclick="toggleInRoom(${boardIdx})">&times;</button>
        </div>`;
    }).join("");
}

function syncEditorMode() {
    const editing = roomEditIndex >= 0 ? KNXdata.rooms[roomEditIndex] : null;
    document.getElementById("editorMode").textContent = editing ? "Editing Room" : "Add Room";
    document.getElementById("editorLead").textContent = editing
        ? "Click Save Room to apply the changes."
        : "Name the room, then click loads on the right to assign them.";
}

// ---- Editor mode ---------------------------------------------------------

function newRoom() {
    roomEditIndex = -1;
    selRoomIdx = -1;
    draftLoads = new Set();
    document.getElementById("roomEditIndex").value = "";
    document.getElementById("roomName").value = "";
    syncEditorMode();
    renderEditorLoads();
    renderRoomRegistry();
    renderLoadPalette();
    document.getElementById("roomName").focus();
}

function editRoom(id) {
    roomEditIndex = Number(id);
    selRoomIdx = roomEditIndex;
    document.getElementById("roomEditIndex").value = roomEditIndex;
    const room = KNXdata.rooms[roomEditIndex];
    document.getElementById("roomName").value = room.name;
    draftLoads = new Set(room.loads || []);
    syncEditorMode();
    renderEditorLoads();
    renderRoomRegistry();
    renderLoadPalette();
    document.getElementById("roomName").focus();
}

// ---- Save / delete -------------------------------------------------------

function saveRoom() {
    const name = document.getElementById("roomName").value.trim();
    if (!name) {
        showError("Room Name can't be [\"\"]", { title: "Validation Error" });
        document.getElementById("roomName").focus();
        return;
    }
    if (KNXdata.loads.length === 0) {
        showError("Add at least one load in the Configuration page before creating rooms.", { title: "Validation Error" });
        return;
    }
    const loads = Array.from(draftLoads).sort((a, b) => a - b);
    const room = { name, loads };
    const idx = document.getElementById("roomEditIndex").value;
    if (idx === "") {
        KNXdata.rooms.push(room);
        roomEditIndex = KNXdata.rooms.length - 1;
    } else {
        KNXdata.rooms[Number(idx)] = room;
    }
    selRoomIdx = roomEditIndex;
    document.getElementById("roomEditIndex").value = roomEditIndex;
    persistSession();
    syncEditorMode();
    renderRoomRegistry();
}

function cnfDelRoom(id, name) {
    showConfirmDialog(
        `Delete room "${name}"? Its loads stay in the Configuration and can be reused.`,
        {
            title: "Delete Room",
            type: "warning",
            confirmText: "Delete",
            cancelText: "Cancel"
        }
    ).then((choice) => {
        if (choice !== "confirm") return;
        KNXdata.rooms.splice(Number(id), 1);
        if (roomEditIndex === Number(id)) newRoom();
        else if (roomEditIndex > Number(id)) roomEditIndex -= 1;
        selRoomIdx = roomEditIndex;
        if (roomEditIndex >= 0) document.getElementById("roomEditIndex").value = roomEditIndex;
        persistSession();
        renderRoomRegistry();
    });
}

// ---- Saved rooms registry (left, bottom) ---------------------------------

function renderRoomRegistry() {
    const can = document.getElementById("roomCan");
    const count = document.getElementById("roomCount");
    if (!can) return;
    if (KNXdata.rooms.length === 0) {
        count.textContent = "0";
        can.innerHTML = `<div class="room-card empty-card">
            <span class="empty-text">No rooms yet — name one above.</span>
        </div>`;
        return;
    }
    count.textContent = KNXdata.rooms.length;
    can.innerHTML = KNXdata.rooms.map((room, i) => {
        const loads = (room.loads || [])
            .map(loadOf)
            .filter(Boolean);
        const dots = [...new Set(loads.map((l) => l.ldTyp || "Switch"))]
            .map((t) => `<span class="type-dot" title="${escHtml(t)}" style="background:${ldTypHue[t] || "#00afd2"}"></span>`)
            .join("");
        const selClass = selRoomIdx === i ? " selected" : "";
        return `<div class="room-card${selClass}" role="button" tabindex="0" onclick="editRoom(${i})"
            onkeydown="if(event.key === 'Enter' || event.key === ' '){event.preventDefault(); editRoom(${i});}">
            <div class="room-card-top">
                <span class="room-card-name">${escHtml(room.name)}</span>
                <button type="button" class="room-card-del" title="Delete Room" aria-label="Delete ${escHtml(room.name)}"
                    onclick="event.stopPropagation(); cnfDelRoom(${i}, '${escHtml(room.name).replace(/'/g, "\\'")}');">&times;</button>
            </div>
            <div class="room-card-meta">
                <span class="room-load-count">${loads.length} load${loads.length === 1 ? "" : "s"}</span>
                ${dots ? `<span class="room-type-dots">${dots}</span>` : ""}
            </div>
        </div>`;
    }).join("");
}

// ---- Boot ----------------------------------------------------------------

loadSession();
syncEditorMode();
renderEditorLoads();
renderRoomRegistry();
renderLoadPalette();
if (KNXdata.loads.length === 0) {
    showInfo("No loads configured yet. Add loads in the Configuration page first, then build rooms here.", {
        title: "Rooms need loads",
        type: "info"
    });
}