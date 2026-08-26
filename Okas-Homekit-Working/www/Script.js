let KNXdata = { prjNm: "", knxIp: "", knxPort: 3671, loads: [], rooms: [] };
let editIndex = -1;
// Tabs are separate documents; without this sessionStorage cache, navigating = losing your edits.
const KNX_SESSION_KEY = "okas_knx_session_v1";
// The order IS the on-bus schema (gAdd[i] -> GA key via makFile.php); reorder here, silently swap addresses.
let lTyp2GA = {
    Switch:   ["Swt: Control", "Swt: Status"],
    Dimmer:   ["Swt: Control", "Swt: Status", "Dimming", "Bri: Control", "Bri: Value"],
    RGB:      ["Swt: Control", "Swt: Status", "Dimming", "Bri: Control", "Bri: Value", "RGB Control", "RGB Value"],
    Tunable:  ["Swt: Control", "Swt: Status", "Dimming", "Bri: Control", "Bri: Value", "Temperature Control", "Temperature Value"],
    HVAC:     ["Swt: Control", "Swt: Status", "Room Temperature", "Setpoint Temperature", "Fan Speed Control", "Fan Speed Value", "Mode Control", "Mode Feedback"],
    Scene:    ["Scene"],
    Fan:      ["Swt: Control", "Swt: Status", "Speed Control", "Speed Value"],
    Curtain:  ["Movement", "Movement Value", "Stop", "Position Control", "Position Value"],
};

// Pure-UI split: these labels go under "Additional Settings"; gAdd order stays put.
let lTyp2GAExtra = {
    HVAC:    { "Room Temperature": true },
    Curtain: { "Movement Value": true, "Position Control": true, "Position Value": true },
};
let loadTypeOrder = ["Switch", "Dimmer", "Tunable", "RGB", "Fan", "Curtain", "Scene", "HVAC"];
let expandedLoadTypes = {
    Switch: true,
    Dimmer: false,
    Tunable: false,
    RGB: false,
    Fan: false,
    Curtain: false,
    Scene: false,
    HVAC: false
};

// Persist after every mutation; private-mode Safari without storage falls through quietly.
function persistKNXSession() {
    try {
        sessionStorage.setItem(KNX_SESSION_KEY, JSON.stringify(KNXdata));
    } catch (_) { /* sessionStorage unavailable, ignore */ }
}

// Rehydrate the form from a prior snapshot, if any; true when something was loaded.
function rehydrateKNXSession() {
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
        document.getElementById("prjNm").value = KNXdata.prjNm || "";
        document.getElementById("knxIp").value = KNXdata.knxIp || "192.168.26.45";
        document.getElementById("knxPort").value = KNXdata.knxPort || 3671;
        return true;
    } catch (_) {
        return false;
    }
}

// Drop the cache after a saved config; stale snapshots are how ghosts get resurrected.
function clearKNXSession() {
    try { sessionStorage.removeItem(KNX_SESSION_KEY); } catch (_) { /* ignore */ }
}

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

function setBackupAvailability() {
    const backupBtn = document.getElementById("bkUP");
    if (!backupBtn) return;
    backupBtn.style.display = "";
    backupBtn.disabled = KNXdata.loads.length === 0;
}

// Format IP Address while typing
function isIP(input) {
    const re = /^(?!0\.)(?!127\.)(?!169\.254\.)(?!22[4-9]\.)(?!23[0-9]\.)(?!24[0-9]\.)(?!25[0-5]\.)((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$/;
    return re.test(input.value);
}

function valGA(lt, id) {
    let val = document.getElementById(`ga${id}`).value;
    if (val == "") return;
    const regX = /^(3[01]|[12]?\d)\/([0-7])\/(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$/;
    let chk = val.match(regX);
    var [a, b, c] = val.split("/").map(Number);
    if ((a + b + c) == 0) chk = false;
    if (!chk) {
        document.getElementById(`ga${id}`).value = "";
        document.getElementById(`ga${id}`).focus();
        showError(`Group-Address [ '${val}' ] for [ '${lt}' ], is invalid`, { title: "Validation Error" });
    }
}

// Optional = no required-toast when an Additional Settings field is blank.
function isOptionalGA(ldTyp, idx) {
    const list = lTyp2GA[ldTyp] || [];
    const extras = lTyp2GAExtra[ldTyp] || {};
    return !!extras[list[idx]];
}

function isGA(fnc, ga, optional = false) {
    return new Promise((res) => {
        // Blank extra = "no GA for this slot"; the positional id (ga${i}) keeps the schema intact.
        if (optional && (ga == null || ga.trim() === "")) {
            res("cnt");
            return;
        }
        const regX = /^(3[01]|[12]?\d)\/([0-7])\/(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$/;
        let chk = ga.match(regX);
        var [a, b, c] = ga.split("/").map(Number);
        if ((a + b + c) == 0) chk = false;
        if (!chk) {
            showValidationDialog(
                `Groupaddress: [ ${ga} ] for ${fnc} is invalid or out of range.\nValid Range ([0-31]/[0-7]/[0-255]).`,
                {
                    title: "⚠️ Validation Error",
                    confirmText: "Correct Entry",
                    cancelText: "Cancel Load"
                }
            ).then((choice) => {
                res(choice === "confirm" ? "edt" : "cls");
            });
        } else {
            res("cnt");
        }
    }); // 32/7/76
}

function initKNXData(defaultType) {
    document.getElementById("modalTitle").innerText = "Add Load";
    document.getElementById("editIndex").value = "";
    document.getElementById("loadName").value = "";
    document.getElementById("loadType").value = defaultType || "Switch";
    document.getElementById("sA").hidden = false;
    let knxIp = document.getElementById("knxIp").value
    const re = /^(?!0\.)(?!127\.)(?!169\.254\.)(?!22[4-9]\.)(?!23[0-9]\.)(?!24[0-9]\.)(?!25[0-5]\.)((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$/;
    if (!re.test(knxIp)) {
        showError("Please enter a valid KNX/IP Interface IP Address.", { title: "Validation Error" });
        return;
    }

    updFields();
    let modal = new bootstrap.Modal(document.getElementById("loadModal"));
    modal.show();
    document.getElementById('loadModal').addEventListener('shown.bs.modal', function () {
        document.getElementById('loadName').focus();
    }, { once: true });
    document.getElementById('loadModal').addEventListener('hidden.bs.modal', function (event) {
        setBackupAvailability();
    }, { once: true });
}

function rstKNXinfo() {
    KNXdata.prjNm = "";
    KNXdata.knxIp = "";
    KNXdata.knxPort = 3671;
    KNXdata.loads = [];
    KNXdata.rooms = [];
    document.getElementById("prjNm").value = "";
    document.getElementById("knxIp").value = "192.168.26.45";
    document.getElementById("knxPort").value = 3671;
    document.getElementById("fPth").innerHTML = "";
    document.getElementById("fPth").style.display = "none";
    setBackupAvailability();
}

document.getElementById('cnfYesBtn').addEventListener('click', function () {
    rstKNXinfo();
    shwLds();
    const cnfMdl = bootstrap.Modal.getInstance(document.getElementById("cnfMdl"));
    if (cnfMdl) {
        cnfMdl.hide();
    }
    // Proceed with file selection
    document.getElementById('fInp').click();
});

document.getElementById('fInp').addEventListener('change', function () {
    if (!this.files || this.files.length === 0) {
        showInfo('No file selected.');
        return;
    }
    const file = this.files[0];
    const fPth = document.getElementById('fPth');

    if (!file.name.endsWith('.obak') && file.type !== 'application/json') {
        showError('Please select a valid *.json or *.obak configuration file.', { title: "Validation Error" });
        this.value = '';
        return;
    }

    const reader = new FileReader();

    reader.onload = function (event) {
        try {
            const fData = event.target.result;
            const impData = JSON.parse(fData);

            if (impData && typeof impData.prjNm !== 'undefined' && Array.isArray(impData.loads)) {
                KNXdata = impData;

                document.getElementById("prjNm").value = KNXdata.prjNm || "";
                document.getElementById("knxIp").value = KNXdata.knxIp || "";
                document.getElementById("knxPort").value = KNXdata.knxPort || 3671;
                persistKNXSession();
                shwLds();

                fPth.innerHTML = `Successfully imported data from: <b>'${(file.name).replace('.obak', '')}'</b>
                    ${KNXdata.loads.length ? '<div class="restore-continue-row"><button type="button" id="restoreContinue" class="btn-primary-glass" onclick="restoreContinue()">Continue →</button></div>' : ''}`;
                if (KNXdata.loads.length) {
                    // land the programmer in the studio, matching the ETS flow
                    window.restoreContinue = () => {
                        studioSel = 0;
                        showStage(3);
                    };
                }
                fPth.style.display = 'block';
                setBackupAvailability();
            } else {
                throw new Error("JSON file does not have the expected format.");
            }
        } catch (error) {
            showError(`Error parsing JSON file: ${error.message}`);
        } finally {
            document.getElementById('fInp').value = '';
        }
    };

    reader.readAsText(file);
});

function prepPrj() {
    KNXdata.prjNm = document.getElementById("prjNm").value;
    KNXdata.knxIp = document.getElementById("knxIp").value;
    KNXdata.knxPort = document.getElementById("knxPort").value;
    if (!KNXdata.prjNm) {
        showError("There is no Project Name given.", { title: "Validation Error" });
        return false;
    };
    if (KNXdata.loads.length === 0) {
        showInfo("Please add at least one load before finishing.");
        return false;
    }
    return true;
}

// Metadata saved on blur — navigating away reloads the page, and reloads eat unsaved input.
function updPrjMeta() {
    KNXdata.prjNm = document.getElementById("prjNm").value;
    KNXdata.knxIp = document.getElementById("knxIp").value;
    KNXdata.knxPort = document.getElementById("knxPort").value;
    persistKNXSession();
}


function resDat() { // Restore Data from Backup File::
    if (KNXdata.loads.length > 0) {
        const cnfMdl = new bootstrap.Modal(document.getElementById("cnfMdl"));
        document.getElementById("cnfMdlBdy").innerHTML = `Your current configuration already contains ${KNXdata.loads.length}
        KNX Load ${KNXdata.loads.length > 1 ? "entries" : "entry"}.<br/>
            Do you want to overwrite it with the Data from Restored File?`;
        cnfMdl.show();
    } else {
        // If no data exists, proceed directly to file selection
        document.getElementById('fInp').click();
    }
}

function bkUP() { // Backup KNX Data to restore later::
    if (!prepPrj()) return;

    const now = new Date();
    const dateString = now.getFullYear().toString() +
        (now.getMonth() + 1).toString().padStart(2, '0') +
        now.getDate().toString().padStart(2, '0');
    const fileName = `${KNXdata.prjNm}_${dateString}.obak`;

    const jsonData = JSON.stringify(KNXdata, null, 2);
    const blob = new Blob([jsonData], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName;
    a.click();
    URL.revokeObjectURL(url); // Free up memory after the click
}
function makeInputField(field) {
    const value = escHtml(field.value ?? "");
    const placeholder = escHtml(field.placeholder || "");
    const label = escHtml(field.label || field.placeholder || field.id);
    const onblur = field.onblur ? ` onblur="${field.onblur}"` : "";
    return `<input type="text" id="${field.id}" tabindex="${field.tabindex || 4}" value="${value}" placeholder="${placeholder}" aria-label="${label}" maxlength="${field.maxlength || 8}"${onblur}>`;
}

function makeFieldRows(fields) {
    let rows = "";
    for (let index = 0; index < fields.length; index += 2) {
        rows += `<div class="field-row">${makeInputField(fields[index])}`;
        if (fields[index + 1]) rows += makeInputField(fields[index + 1]);
        rows += `</div>`;
    }
    return rows;
}

function updFields(id) {
    if (id == undefined || id < 0) id = -1;
    let ldTyp = document.getElementById("loadType").value || "Switch";
    let load = id >= 0 ? KNXdata.loads[id] : {};
    let gaList = lTyp2GA[ldTyp] || [];
    let extraGaSet = lTyp2GAExtra[ldTyp] || {};

    // Input id (ga${idx}) keeps its original index — panels are cosmetic, the array order is contract.
    let primaryFields = [];
    let extraGaFields = [];
    gaList.forEach((v, i) => {
        const f = {
            id: `ga${i}`,
            label: v,
            placeholder: v,
            value: load.gAdd ? load.gAdd[i] : "",
            tabindex: id >= 0 ? 1 : 3,
            maxlength: 8,
            onblur: `valGA('${v}', '${i}')`
        };
        if (extraGaSet[v]) {
            extraGaFields.push(f);
        } else {
            primaryFields.push(f);
        }
    });

    let fieldsHtml = "";
    if (primaryFields.length > 0) {
        fieldsHtml += `<div class="modal-field-group"><label class="group-label">${escHtml(ldTyp)}: Group Address(es)</label>${makeFieldRows(primaryFields)}</div>`;
    }

    let extraFields = [];

    switch (ldTyp) {
        case 'Scene':
            extraFields = [
                { id: 'Scn', placeholder: 'KNX Scene No.', value: load.Scn, tabindex: 4, maxlength: 3 }
            ];
            break;
        case 'HVAC':
            extraFields = [
                { id: 'Tmn', placeholder: 'Min. Setpoint Temperature', value: load.Tmn, tabindex: 4, maxlength: 3 },
                { id: 'Tmx', placeholder: 'Max. Setpoint Temperature', value: load.Tmx, tabindex: 5, maxlength: 3 },
                { id: 'Smx', placeholder: 'Max Speed', value: load.Smx, tabindex: 4, maxlength: 5 },
                { id: 'Fst', placeholder: 'Speed Step', value: load.Fst, tabindex: 5, maxlength: 5 }
            ];
            break;
        case 'Tunable':
            extraFields = [
                { id: 'Kmn', placeholder: 'Min. Color Temperature (K)', value: load.Kmn, tabindex: 4, maxlength: 5 },
                { id: 'Kmx', placeholder: 'Max. Color Temperature (K)', value: load.Kmx, tabindex: 5, maxlength: 5 }
            ];
            break;
        case 'Fan':
            extraFields = [
                { id: 'Smx', placeholder: 'Max Speed', value: load.Smx, tabindex: 4, maxlength: 5 },
                { id: 'Fst', placeholder: 'Speed Step', value: load.Fst, tabindex: 5, maxlength: 5 }
            ];
            break;
    }

    if (extraGaFields.length > 0 || extraFields.length > 0) {
        let extrasHtml = "";
        if (extraGaFields.length > 0) {
            extrasHtml += `<label class="group-label" style="margin-top:8px;">Additional Group Address(es)</label>${makeFieldRows(extraGaFields)}`;
        }
        if (extraFields.length > 0) {
            extrasHtml += `<label class="group-label" style="margin-top:8px;">Additional Settings</label>${makeFieldRows(extraFields)}`;
        }
        fieldsHtml += `<div class="modal-field-group">${extrasHtml}</div>`;
    }

    document.getElementById("dynamicFields").innerHTML = fieldsHtml;
}

function updLoad(gArr, more) {
    let gAdd = gArr;
    let index = document.getElementById("editIndex").value;
    let ldNm = document.getElementById("loadName").value;
    let ldTyp = document.getElementById("loadType").value;
    document.getElementById("loadName").value = "";
    document.getElementById("loadType").value = "Switch";
    let load = { ldNm, ldTyp, gAdd };
    switch (ldTyp) {
        case 'Scene':
            load.Scn = document.getElementById('Scn').value;
            document.getElementById('Scn').value = "";
            break;
        case 'Fan':
            load.Smx = document.getElementById('Smx').value;
            document.getElementById('Smx').value = "";
            load.Fst = document.getElementById('Fst').value;
            document.getElementById('Fst').value = "";
            break;
        case 'HVAC':
            load.Tmn = document.getElementById('Tmn').value;
            load.Tmx = document.getElementById('Tmx').value;
            load.Smx = document.getElementById('Smx').value;
            load.Fst = document.getElementById('Fst').value;
            document.getElementById('Smx').value = "";
            document.getElementById('Fst').value = "";
            document.getElementById('Tmn').value = "";
            document.getElementById('Tmx').value = "";
            break;
        case 'Tunable':
            load.Kmn = document.getElementById('Kmn').value;
            load.Kmx = document.getElementById('Kmx').value;
            document.getElementById('Kmn').value = "";
            document.getElementById('Kmx').value = "";
            break;
    }
    if (index === "") {
        KNXdata.loads.push(load);
    } else {
        KNXdata.loads[index] = load;
    }
    persistKNXSession();
    shwLds();
    setBackupAvailability();
    updFields();
    document.getElementById('loadName').focus();
    if (!more) {
        bootstrap.Modal.getInstance(document.getElementById("loadModal")).hide();
        setBackupAvailability();
    }
}

async function saveLoad(more) {
    let ldNm = document.getElementById('loadName');
    if (ldNm.value == "") {
        showError(`Load Name can't be [""]`, { title: "Validation Error" });
        ldNm.focus();
        return;
    }
    let ldTyp = document.getElementById("loadType").value;
    // "Primary" must be filled, "extra" may be blank; both keep their positional index — the schema doesn't care about panels.
    let extraGaSet = lTyp2GAExtra[ldTyp] || {};
    let grpArr = [];
    for (let i = 0; i < lTyp2GA[ldTyp].length; i++) {
        let v = lTyp2GA[ldTyp][i];
        let tID = `ga${i}`;
        let tVal = document.getElementById(tID).value;
        let tSta = await isGA(v, tVal, !!extraGaSet[v]);
        if (tSta == "edt") {
            document.getElementById(tID).value = "";
            document.getElementById(tID).focus();
            break;
        } else if (tSta == "cls") {
            bootstrap.Modal.getInstance(document.getElementById("loadModal")).hide();
            break;
        } else if (tSta == "cnt") {
            // Blanks round-trip as empty strings; gAdd[i] still maps to the same key.
            grpArr.push(extraGaSet[v] ? tVal : tVal);
            continue;
        }
    }
    if (lTyp2GA[ldTyp].length == grpArr.length) {
        updLoad(grpArr, more)
    };
}

function selectLoad(id) {
    editIndex = Number(id);
    document.querySelectorAll(".load-item-dropdown").forEach((item) => {
        item.classList.toggle("selected", item.dataset.loadIndex == id);
    });
}

function toggleLoadCategory(type) {
    expandedLoadTypes[type] = !expandedLoadTypes[type];
    shwLds();
}

function shwLds() {
    const LdOpts = document.getElementById("LdOpts");
    const edBtn = document.getElementById("edBtn");
    const can = document.getElementById("loadCan");
    if (!LdOpts || !can) return;

    if (editIndex >= KNXdata.loads.length) editIndex = -1;
    LdOpts.style.display = "block";
    if (edBtn) {
        edBtn.hidden = true;
        edBtn.style.display = "none";
    }

    let allTypes = loadTypeOrder.concat(Object.keys(lTyp2GA).filter((type) => !loadTypeOrder.includes(type)));
    let grouped = KNXdata.loads.reduce((acc, load, id) => {
        let type = load.ldTyp || "Switch";
        if (!acc[type]) acc[type] = [];
        acc[type].push({ load, id });
        return acc;
    }, {});

    can.innerHTML = allTypes.map((type) => {
        let typeLoads = grouped[type] || [];
        let isExpanded = expandedLoadTypes[type];
        let itemsHtml = "";

        if (typeLoads.length > 0) {
            itemsHtml = `<div class="loads-list">${typeLoads.map(({ load, id }) => {
                let addresses = Array.isArray(load.gAdd) ? load.gAdd.filter(Boolean).join(", ") : "";
                let selectedClass = Number(editIndex) === id ? " selected" : "";
                return `<div class="load-item-dropdown${selectedClass}" data-load-index="${id}" role="button" tabindex="0" onclick="selectLoad(${id})" onkeydown="if(event.key === 'Enter' || event.key === ' '){event.preventDefault(); selectLoad(${id});}">
                    <div class="load-info">
                        <span class="load-name">${escHtml(load.ldNm)} - [${escHtml(load.ldTyp)}]</span>
                        ${addresses ? `<span class="load-address">${escHtml(addresses)}</span>` : ""}
                    </div>
                    <div class="load-actions">
                        <button type="button" class="edit-load" onclick="event.stopPropagation(); selectLoad(${id}); editLoad();" title="Edit Load">Edit</button>
                        <button type="button" class="delete-load" onclick="event.stopPropagation(); selectLoad(${id}); cnfDel();" title="Delete Load">Delete</button>
                    </div>
                </div>`;
            }).join("")}</div>`;
        } else {
            itemsHtml = `<div class="empty-category-dropdown">
                <span class="empty-text">No loads added</span>
                <button type="button" class="add-small" onclick="event.stopPropagation(); initKNXData('${type}')">+ Add Load</button>
            </div>`;
        }

        return `<div class="load-category-dropdown">
            <button type="button" class="category-header" onclick="toggleLoadCategory('${type}')" aria-expanded="${isExpanded ? "true" : "false"}">
                <span class="category-title-wrapper">
                    <span class="dropdown-arrow${isExpanded ? " expanded" : ""}" aria-hidden="true"></span>
                    <i class="ld-ico ld-ico-sm ld-ico-${type}" aria-hidden="true"></i>
                    <span class="category-title">${escHtml(type)}</span>
                    <span class="load-count">(${typeLoads.length})</span>
                </span>
            </button>
            ${isExpanded ? `<div class="category-content">${itemsHtml}</div>` : ""}
        </div>`;
    }).join("");

    setBackupAvailability();
    if (typeof refreshCfgSummary === 'function') refreshCfgSummary();
    const s3 = document.getElementById('stage3');
    if (s3 && !s3.hidden && typeof renderStudio === 'function') renderStudio();
}

function editLoad() {
    if (editIndex === -1) {
        showInfo("Please select an item to edit!");
        return;
    }
    document.getElementById("modalTitle").innerText = "Edit Load";
    document.getElementById("editIndex").value = editIndex;
    document.getElementById("sA").hidden = true;
    document.getElementById("loadName").value = KNXdata.loads[editIndex].ldNm;
    document.getElementById("loadType").value = KNXdata.loads[editIndex].ldTyp;
    updFields(editIndex);
    let modal = new bootstrap.Modal(document.getElementById("loadModal"));
    modal.show();
}

function cnfDel() {
    if (editIndex === -1) {
        showInfo("Please select an item to delete!");
        return;
    }
    let modal = new bootstrap.Modal(document.getElementById("deleteModal"));
    modal.show();
}

function delLoad() {
    KNXdata.loads.splice(editIndex, 1);
    // Board load indices are positional: deleting a load shifts every
    // room reference past it. Keep room assignments consistent.
    const removedIdx = editIndex + 1;
    KNXdata.rooms.forEach((room) => {
        room.loads = (room.loads || [])
            .filter((idx) => idx !== removedIdx)
            .map((idx) => (idx > removedIdx ? idx - 1 : idx));
    });
    editIndex = -1;
    persistKNXSession();
    shwLds();
    setBackupAvailability();
    bootstrap.Modal.getInstance(document.getElementById("deleteModal")).hide();
}

// ============ Single-page flow: Stage 1 Project · Stage 2 ETS Review · Stage 3 Rooms & Loads ============
let etsDraft = null; // {prjNm, loads:[{ldNm,ldTyp,gAdd,_inc,...}], rooms:[{name,loads:[1-based],_inc}]}
let studioSel = 0;   // selected KNXdata.rooms index; '__unassigned__' for the pseudo-room

const LD_HUES = { Switch:'#00afd2', Dimmer:'#f0a000', RGB:'#8e5bd6', Tunable:'#e8590c',
                  HVAC:'#0ca678', Scene:'#3b82f6', Fan:'#5c7cfa', Curtain:'#d63384' };
const hueOf = (t) => LD_HUES[t] || '#00afd2';

// Stage unlocks: 2 needs a pending ETS draft, 3 needs at least one load.
function stageUnlocked(n) {
    if (n === 1) return true;
    if (n === 2) return !!etsDraft;
    return KNXdata.loads.length > 0;
}

function showStage(n) {
    [1, 2, 3].forEach((i) => {
        document.getElementById('stage' + i).hidden = i !== n;
    });
    document.querySelectorAll('.bus-seg').forEach((seg) => {
        const v = Number(seg.dataset.seg);
        seg.classList.toggle('is-on', v === n);
        seg.classList.toggle('is-done', v < n);
        seg.classList.toggle('is-locked', !stageUnlocked(v));
    });
    if (n === 1) refreshCfgSummary();
    if (n === 3) renderStudio();
}

document.querySelectorAll('.bus-seg').forEach((seg) => {
    seg.addEventListener('click', () => {
        const v = Number(seg.dataset.seg);
        if (!stageUnlocked(v)) {
            showInfo(v === 2
                ? 'Upload an ETS project first — the review stage opens after a conversion.'
                : 'Add or import at least one load to open the rooms stage.',
                { title: 'Stage Locked' });
            return;
        }
        showStage(v);
    });
});

function backToStage1() { showStage(1); }

function refreshCfgSummary() {
    const resume = document.getElementById('resumeRow');
    resume.innerHTML = (etsDraft && !etsDraft._merged)
        ? '<button type="button" class="btn-restore resume-btn" onclick="showStage(2)">Resume ETS Review →</button>'
        : '';
    const box = document.getElementById('cfgSummary');
    const nL = KNXdata.loads.length;
    const nR = KNXdata.rooms.length;
    if (!nL && !nR) { box.hidden = true; return; }
    box.hidden = false;
    box.innerHTML = `
        <div class="stat-card">
            <div class="stat-num">${nL}</div>
            <div class="stat-label">Loads Configured</div>
        </div>
        <div class="stat-card">
            <div class="stat-num">${nR}</div>
            <div class="stat-label">Room${nR === 1 ? '' : 's'}</div>
        </div>`;
}

// ---------------- Upload ETS ----------------
// Wipe the working configuration so the flow starts from zero.
// Deliberately board-safe: the running setup is only replaced by Finish.
function clearConfig() {
    if (!KNXdata.loads.length && !KNXdata.rooms.length) {
        showInfo('The working configuration is already empty.', { title: 'Nothing to Clear' });
        return;
    }
    const nL = KNXdata.loads.length, nR = KNXdata.rooms.length;
    showConfirmDialog(
        `Clear the entire working configuration? All ${nL} load${nL === 1 ? '' : 's'} and ${nR} room${nR === 1 ? '' : 's'} in this editor will be removed. ` +
        'The board keeps running its current setup until you Finish a new one.',
        { title: 'Reset Configuration', type: 'warning', confirmText: 'Clear Everything', cancelText: 'Keep' }
    ).then((choice) => {
        if (choice !== 'confirm') return;
        rstKNXinfo();
        clearKNXSession();
        shwLds();
        refreshCfgSummary();
        showStage(1);
        studioSel = 0;
        showInfo('Configuration cleared. Upload an ETS project or add loads manually to start again.', { title: 'Cleared' });
    });
}

function uploadEts() {
    document.getElementById('etsInp').click();
}

document.getElementById('etsInp').addEventListener('change', function () {
    if (!this.files || !this.files.length) return;
    const file = this.files[0];
    this.value = '';
    if (!file.name.toLowerCase().endsWith('.knxproj')) {
        showError('Please select a .knxproj ETS project file.', { title: 'Validation Error' });
        return;
    }
    const btn = document.querySelector('.btn-primary-glass');
    const orig = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'Converting…';
    const fd = new FormData();
    fd.append('etsfile', file);
    fetch(window.location.origin + '/uploadEts.php', { method: 'POST', body: fd })
        .then((r) => r.json().catch(() => ({ ok: false, err: 'Invalid server response.' })))
        .then((res) => {
            if (!res.ok) {
                showError(res.err || 'Conversion failed.', { title: 'ETS Import' });
                return;
            }
            etsDraft = res.draft;
            etsDraft.loads.forEach((ld) => { ld._inc = true; });
            etsDraft.rooms.forEach((rm) => { rm._inc = true; });
            if (document.getElementById('prjNm').value.trim() === '' && etsDraft.prjNm) {
                document.getElementById('prjNm').value = etsDraft.prjNm;
                updPrjMeta();
            }
            renderReview();
            showStage(2);
        })
        .catch((e) => showError('Upload failed: ' + e.message, { title: 'ETS Import' }))
        .finally(() => { btn.disabled = false; btn.textContent = orig; });
});

// ---------------- Stage 2 · review ----------------
function renderReview() {
    const incLoads = etsDraft.loads.filter((l) => l._inc).length;
    const incRooms = etsDraft.rooms.filter((r) => r._inc).length;
    document.getElementById('revLead').textContent =
        'Everything below came from the ETS project. Tick what to keep, rename anything — names are what you will see in the app.';
    document.getElementById('revCounts').innerHTML =
        `<span class="rev-count">${incRooms} room${incRooms === 1 ? '' : 's'}</span>` +
        `<span class="rev-count">${incLoads} load${incLoads === 1 ? '' : 's'} kept</span>`;
    document.getElementById('revContinueBtn').disabled = incLoads === 0;

    document.getElementById('revBody').innerHTML = etsDraft.rooms.map((rm, ri) => {
        const chips = rm.loads.map((boardIdx) => {
            const ld = etsDraft.loads[boardIdx - 1];
            if (!ld) return '';
            return `<label class="rev-chip ld-hue-${ld.ldTyp}${ld._inc ? '' : ' off'}" data-r="${ri}" data-l="${boardIdx}">
                <input type="checkbox" data-act="ldinc" ${ld._inc ? 'checked' : ''}>
                <i class="ld-ico ld-ico-sm ld-ico-${ld.ldTyp}" aria-hidden="true"></i>
                <input class="ets-name" value="${escHtml(ld.ldNm)}" data-act="ldname" title="Rename load">
                <span class="ldtyp">${escHtml(ld.ldTyp)}</span>
            </label>`;
        }).join('');
        return `<div class="rev-room" data-room="${ri}">
            <div class="rev-room-head">
                <input type="checkbox" data-act="rminc" ${rm._inc ? 'checked' : ''} title="Include this room">
                <input class="rev-room-name" value="${escHtml(rm.name)}" data-act="rmname" title="Rename room">
                <button type="button" class="rev-drop" data-act="rmexclude">Exclude room</button>
            </div>
            <div class="rev-chips">${chips}</div>
        </div>`;
    }).join('');
}

document.getElementById('revBody').addEventListener('change', function (e) {
    const t = e.target;
    const act = t.dataset.act;
    if (!act) return;
    const roomEl = t.closest('.rev-room');
    const ri = Number(roomEl.dataset.room);
    const rm = etsDraft.rooms[ri];
    if (act === 'rminc') {
        rm._inc = t.checked;
        rm.loads.forEach((b) => { etsDraft.loads[b - 1]._inc = t.checked; });
    } else if (act === 'ldinc') {
        const chip = t.closest('.rev-chip');
        etsDraft.loads[Number(chip.dataset.l) - 1]._inc = t.checked;
        renderReview();
        return;
    } else if (act === 'rmname') {
        rm.name = t.value.trim() || rm.name;
    } else if (act === 'ldname') {
        const chip = t.closest('.rev-chip');
        etsDraft.loads[Number(chip.dataset.l) - 1].ldNm = t.value.trim() || etsDraft.loads[Number(chip.dataset.l) - 1].ldNm;
    }
    if (act === 'rminc') renderReview();
    else updateRevCounts();
});
function updateRevCounts() {
    const incLoads = etsDraft.loads.filter((l) => l._inc).length;
    const incRooms = etsDraft.rooms.filter((r) => r._inc).length;
    document.getElementById('revCounts').innerHTML =
        `<span class="rev-count">${incRooms} room${incRooms === 1 ? '' : 's'}</span>` +
        `<span class="rev-count">${incLoads} load${incLoads === 1 ? '' : 's'} kept</span>`;
    document.getElementById('revContinueBtn').disabled = incLoads === 0;
}
document.getElementById('revBody').addEventListener('click', function (e) {
    if (e.target.closest('[data-act="rmexclude"]')) {
        const ri = Number(e.target.closest('.rev-room').dataset.room);
        etsDraft.rooms[ri]._inc = false;
        etsDraft.rooms[ri].loads.forEach((b) => { etsDraft.loads[b - 1]._inc = false; });
        renderReview();
    }
});

function uniqueLoadName(base, taken) {
    let nm = base.trim() || 'Load';
    if (!taken.has(nm)) { taken.add(nm); return nm; }
    for (let i = 2; ; i++) {
        const cand = `${nm} (${i})`;
        if (!taken.has(cand)) { taken.add(cand); return cand; }
    }
}

function continueReview() {
    const taken = new Set(KNXdata.loads.map((l) => l.ldNm));
    const idxMap = new Map();
    let n = 0;
    etsDraft.loads.forEach((ld, i) => {
        if (!ld._inc) return;
        const clean = { ldNm: uniqueLoadName(ld.ldNm, taken), ldTyp: ld.ldTyp, gAdd: ld.gAdd };
        ['Scn', 'Kmn', 'Kmx', 'Tmn', 'Tmx', 'Smx', 'Fst'].forEach((k) => {
            if (ld[k] !== undefined && ld[k] !== '') clean[k] = ld[k];
        });
        KNXdata.loads.push(clean);
        idxMap.set(i + 1, KNXdata.loads.length);
        n++;
    });
    let roomsAdded = 0;
    etsDraft.rooms.forEach((rm) => {
        if (!rm._inc) return;
        const idxs = rm.loads.map((b) => idxMap.get(b)).filter(Boolean);
        if (!idxs.length) return;
        KNXdata.rooms.push({ id: rm.name, name: rm.name, imagePath: null, loads: idxs,
            createdAt: new Date().toISOString(), isFavorite: false });
        roomsAdded++;
    });
    persistKNXSession();
    shwLds();
    etsDraft = null; // merged — a stale draft would double-import on resume
    document.getElementById('resumeRow').innerHTML = '';
    studioSel = Math.max(0, KNXdata.rooms.length - roomsAdded); // land on first imported room
    showStage(3);
    showInfo(`Imported ${n} load(s) into ${roomsAdded} room(s). Review, rename or remove anything, then press Finish.`, { title: 'ETS Imported' });
}

// ---------------- Stage 3 · rooms & loads studio ----------------
function unassignedBoardIdxs() {
    const assigned = new Set();
    KNXdata.rooms.forEach((r) => (r.loads || []).forEach((b) => assigned.add(b)));
    const out = [];
    KNXdata.loads.forEach((l, i) => { if (!assigned.has(i + 1)) out.push(i + 1); });
    return out;
}

function renderStudio() {
    // Rail
    const rail = document.getElementById('railList');
    const items = [];
    KNXdata.rooms.forEach((rm, i) => {
        const first = rm.loads && rm.loads.length ? KNXdata.loads[rm.loads[0] - 1] : null;
        const hue = hueOf(first ? first.ldTyp : 'Switch');
        items.push(`<button type="button" class="rail-item${studioSel === i ? ' active' : ''}"
            style="--hue:${hue}" data-rail="${i}">
            <i class="ld-ico ld-ico-sm ld-ico-${first ? first.ldTyp : 'Switch'}" aria-hidden="true"></i>
            <span class="rail-name">${escHtml(rm.name)}</span>
            <span class="rail-count">${(rm.loads || []).length}</span>
        </button>`);
    });
    const un = unassignedBoardIdxs();
    items.push(`<button type="button" class="rail-item${studioSel === '__unassigned__' ? ' active' : ''}"
        style="--hue:#5b7386" data-rail="__unassigned__">
        <i class="ld-ico ld-ico-sm" style="--hue:#5b7386" aria-hidden="true"></i>
        <span class="rail-name">Unassigned</span>
        <span class="rail-count">${un.length}</span>
    </button>`);
    rail.innerHTML = items.join('');

    // Info strip
    const nL = KNXdata.loads.length, nR = KNXdata.rooms.length;
    document.getElementById('studioInfo').textContent =
        `${nL} load${nL === 1 ? '' : 's'} across ${nR} room${nR === 1 ? '' : 's'} After Configuring, Press Finish to Complete.`;

    // Main pane
    const head = document.getElementById('roomHead');
    const grid = document.getElementById('tileGrid');
    if (studioSel === '__unassigned__') {
        head.innerHTML = `<input class="room-title" value="Unassigned" disabled>
            <span class="room-meta">${un.length} load${un.length === 1 ? '' : 's'} not in any room yet</span>`;
        grid.innerHTML = un.length ? un.map(tileHtml).join('') :
            `<div class="studio-empty"><b>All loads are placed</b>Every load belongs to a room.</div>`;
    } else {
        const rm = KNXdata.rooms[studioSel];
        if (!rm) { studioSel = '__unassigned__'; renderStudio(); return; }
        head.innerHTML = `
            <input class="room-title" value="${escHtml(rm.name)}" data-act="roomtitle" title="Rename room">
            <span class="room-meta">${(rm.loads || []).length} load${(rm.loads || []).length === 1 ? '' : 's'} in this room</span>
            <span class="room-actions">
                <button type="button" class="btn-cancel" data-act="delroom">Remove Room</button>
            </span>`;
        grid.innerHTML = (rm.loads || []).length ? rm.loads.map(tileHtml).join('') :
            `<div class="studio-empty"><b>This room is empty</b>Add loads from the toolbar, or assign them to a room after uploading the configuration.</div>`;
    }
}

function tileHtml(boardIdx) {
    const ld = KNXdata.loads[boardIdx - 1];
    if (!ld) return '';
    const hue = hueOf(ld.ldTyp);
    const ga = (ld.gAdd || []).filter(Boolean).join('  ·  ') || 'No group addresses';
    return `<div class="load-tile ld-hue-${ld.ldTyp}" style="--hue:${hue};--i:${boardIdx % 12}" data-bidx="${boardIdx}">
        <button type="button" class="tile-move" data-act="movetile" title="Move to another room">⇄</button>
        <button type="button" class="tile-del" data-act="delltile" title="Delete load">×</button>
        <div class="tile-top"><i class="ld-ico ld-ico-${ld.ldTyp}" aria-hidden="true"></i><span class="tile-type">${escHtml(ld.ldTyp)}</span></div>
        <input class="tile-name" value="${escHtml(ld.ldNm)}" data-act="tilename" title="Rename load">
        <div class="tile-ga" title="${escHtml(ga)}">${escHtml(ga)}</div>
    </div>`;
}

document.getElementById('railList').addEventListener('click', function (e) {
    const item = e.target.closest('.rail-item');
    if (!item) return;
    const v = item.dataset.rail;
    studioSel = v === '__unassigned__' ? '__unassigned__' : Number(v);
    renderStudio();
});

document.getElementById('stage3').addEventListener('change', function (e) {
    const act = e.target.dataset.act;
    if (act === 'roomtitle') {
        const rm = KNXdata.rooms[studioSel];
        const nm = e.target.value.trim();
        if (rm && nm) { rm.name = nm; rm.id = nm; persistKNXSession(); renderStudio(); }
    } else if (act === 'tilename') {
        const bidx = Number(e.target.closest('.load-tile').dataset.bidx);
        const nm = e.target.value.trim();
        if (nm) { KNXdata.loads[bidx - 1].ldNm = nm; persistKNXSession(); refreshCfgSummary(); }
    }
});

function openMoveDialog(boardIdx) {
    const ld = KNXdata.loads[boardIdx - 1];
    const ownerIdx = KNXdata.rooms.findIndex((r) => (r.loads || []).includes(boardIdx));
    document.getElementById('moveLoadName').textContent = ld.ldNm;
    const opts = [];
    KNXdata.rooms.forEach((r, i) => {
        if (i === ownerIdx) return;
        opts.push(`<button type="button" class="move-opt" data-target="${i}">
            <i class="ld-ico ld-ico-sm ld-ico-${(r.loads && r.loads.length ? KNXdata.loads[r.loads[0] - 1].ldTyp : 'Switch')}" aria-hidden="true"></i>
            <span class="move-opt-name">${escHtml(r.name)}</span>
            <span class="rail-count">${(r.loads || []).length}</span>
        </button>`);
    });
    if (ownerIdx >= 0) {
        opts.push(`<button type="button" class="move-opt move-opt-un" data-target="__unassigned__">
            <i class="ld-ico ld-ico-sm" style="--hue:#5b7386" aria-hidden="true"></i>
            <span class="move-opt-name">Unassigned</span>
        </button>`);
    }
    document.getElementById('moveList').innerHTML =
        opts.join('') || '<div class="studio-empty">No other rooms yet — create one first.</div>';
    const modalEl = document.getElementById('moveModal');
    document.getElementById('moveList').onclick = (e) => {
        const btn = e.target.closest('.move-opt');
        if (!btn) return;
        const t = btn.dataset.target;
        bootstrap.Modal.getInstance(modalEl)?.hide();
        moveLoadToRoom(boardIdx, t === '__unassigned__' ? '__unassigned__' : Number(t));
    };
    new bootstrap.Modal(modalEl).show();
}

function moveLoadToRoom(boardIdx, target) {
    // remove from current owner (if any)
    KNXdata.rooms.forEach((r) => {
        r.loads = (r.loads || []).filter((b) => b !== boardIdx);
    });
    if (target !== '__unassigned__') {
        const room = KNXdata.rooms[target];
        if (room && !room.loads.includes(boardIdx)) room.loads.push(boardIdx);
    }
    persistKNXSession();
    shwLds();
    // keep the viewport sensible: if the source room is selected and now empty,
    // stay on it (empty state shows); otherwise rerender in place.
    renderStudio();
}

document.getElementById('stage3').addEventListener('click', function (e) {
    const btn = e.target.closest('[data-act]');
    if (!btn) return;
    if (btn.dataset.act === 'movetile') {
        openMoveDialog(Number(btn.closest('.load-tile').dataset.bidx));
        return;
    }
    if (btn.dataset.act === 'delltile') {
        const bidx = Number(btn.closest('.load-tile').dataset.bidx);
        const ld = KNXdata.loads[bidx - 1];
        showConfirmDialog(`Delete load "${ld.ldNm}"? This removes it from the configuration.`, {
            title: 'Delete Load', confirmText: 'Delete', cancelText: 'Keep'
        }).then((choice) => {
            if (choice !== 'confirm') return;
            removeLoadAt(bidx - 1);
        });
    } else if (btn.dataset.act === 'delroom') {
        const rm = KNXdata.rooms[studioSel];
        showConfirmDialog(`Remove room "${rm.name}"? Its ${rm.loads.length} load(s) stay in the configuration as Unassigned.`, {
            title: 'Remove Room', confirmText: 'Remove', cancelText: 'Cancel'
        }).then((choice) => {
            if (choice !== 'confirm') return;
            KNXdata.rooms.splice(studioSel, 1);
            studioSel = Math.min(studioSel, KNXdata.rooms.length - 1);
            if (studioSel < 0) studioSel = '__unassigned__';
            persistKNXSession();
            shwLds(); renderStudio();
        });
    }
});

// Splice a load out of KNXdata and keep every room's 1-based index valid.
function removeLoadAt(zeroBasedIdx) {
    KNXdata.loads.splice(zeroBasedIdx, 1);
    const removedIdx = zeroBasedIdx + 1;
    KNXdata.rooms.forEach((room) => {
        room.loads = (room.loads || [])
            .filter((idx) => idx !== removedIdx)
            .map((idx) => (idx > removedIdx ? idx - 1 : idx));
    });
    persistKNXSession();
    shwLds(); renderStudio();
}

async function donCnf() {
    let org = (window.location.origin).toString();
    if (!prepPrj()) return;

    // The board writes both config files and restarts services during this
    // POST (~6s) — show the programmer it is working, not frozen.
    const ov = document.getElementById('upOverlay');
    const finBtn = document.querySelector('.btn-finish');
    ov.hidden = false;
    if (finBtn) finBtn.disabled = true;
    let response, result;
    try {
        let jsonData = JSON.stringify(KNXdata, null, 2);
        response = await fetch(org + "/makFile.php", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: jsonData
        });
        result = await response.text();
    } finally {
        // overlay covers ONLY the upload; the backup prompt must be clickable
        ov.hidden = true;
        if (finBtn) finBtn.disabled = false;
    }
    if (!result) {
        showError("Error sending Configuration Data to System.");
        return;
    }
    // Config saved — drop the session cache so the next load starts clean, not haunted.
    clearKNXSession();

    const choice = await showConfirmDialog(
        `It is advisable to back up the "Configuration Data".\nWould you like to create a backup now?`,
        {
            title: "✅ Configuration Data sent to System.",
            type: "success",
            confirmText: "YES",
            cancelText: "NO"
        }
    );
    if (choice === "confirm") {
        bkUP();
    }
}

setBackupAvailability();
rehydrateKNXSession();
shwLds();
showStage(1);
// Blur-save the metadata too; tab-hopping without it is how configs get eaten.
["prjNm", "knxIp", "knxPort"].forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.addEventListener("blur", updPrjMeta);
});
