let KNXdata = { prjNm: "", knxIp: "", knxPort: 3671, loads: [] };
let editIndex = -1;
// sessionStorage key for the in-progress configuration. The three tab pages
// (index.html, logMgr.html, deviceInfo.html) are separate HTML documents so
// navigating between them causes a full page reload; without this cache the
// uncommitted `KNXdata` would be lost on every navigation. We persist after
// every mutation and rehydrate on script init so the user can move freely
// between tabs while editing.
const KNX_SESSION_KEY = "okas_knx_session_v1";
let lTyp2GA = {
    Switch: ["Swt: Control", "Swt: Status"],
    Dimmer: ["Swt: Control", "Swt: Status", "Dimming", "Bri: Control", "Bri: Value"],
    RGB: ["Swt: Control", "Swt: Status", "Dimming", "Bri: Control", "Bri: Value", "RGB Control", "RGB Value"],
    Tunable: ["Swt: Control", "Swt: Status", "Dimming", "Bri: Control", "Bri: Value", "Temperature Control", "Temperature Value"],
    HVAC: ["Swt: Control", "Swt: Status", "Room Temperature", "Setpoint Temperature", "Fan Speed Control", "Fan Speed Value", "Mode Control", "Mode Feedback"],
    Scene: ["Scene"],
    Fan: ["Swt: Control", "Swt: Status", "Speed Control", "Speed Value"],
    Curtain: ["Movement", "Movement Value", "Stop", "Position Control", "Position Value"],
}
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

// Persist the current KNXdata snapshot to sessionStorage. Called after every
// mutation (add/edit/delete load, project metadata change). Safe to call when
// sessionStorage is unavailable (private-mode Safari, etc.) — falls through.
function persistKNXSession() {
    try {
        sessionStorage.setItem(KNX_SESSION_KEY, JSON.stringify(KNXdata));
    } catch (_) { /* sessionStorage unavailable, ignore */ }
}

// Rehydrate KNXdata from sessionStorage if a prior snapshot exists, then
// mirror the values into the form fields. Returns true if anything was loaded.
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
            loads: cached.loads
        };
        document.getElementById("prjNm").value = KNXdata.prjNm || "";
        document.getElementById("knxIp").value = KNXdata.knxIp || "192.168.26.45";
        document.getElementById("knxPort").value = KNXdata.knxPort || 3671;
        return true;
    } catch (_) {
        return false;
    }
}

// Drop the cached snapshot — used after a successful "Finish" save or after
// an explicit restore from file so stale data never lingers across sessions.
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

function isGA(fnc, ga) {
    return new Promise((res) => {
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

                fPth.innerHTML = `Successfully imported data from: <b>'${(file.name).replace('.obak', '')}'</b>`;
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

// Mirror the three project-metadata inputs into KNXdata and persist. Called
// on blur so navigating away (which triggers the page reload) keeps the
// values even if the user never pressed "Finish".
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
    let gaFields = lTyp2GA[ldTyp].map((v, i) => ({
        id: `ga${i}`,
        label: v,
        placeholder: v,
        value: load.gAdd ? load.gAdd[i] : "",
        tabindex: id >= 0 ? 1 : 3,
        maxlength: 8,
        onblur: `valGA('${v}', '${i}')`
    }));

    let fieldsHtml = `<div class="modal-field-group"><label class="group-label">${escHtml(ldTyp)}: Group Address(es)</label>${makeFieldRows(gaFields)}</div>`;
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

    if (extraFields.length > 0) {
        fieldsHtml += `<div class="modal-field-group"><label class="group-label">Additional Settings</label>${makeFieldRows(extraFields)}</div>`;
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
    let grpArr = [];
    for (let v of lTyp2GA[ldTyp]) {
        let i = lTyp2GA[ldTyp].indexOf(v);
        let tID = `ga${i}`;
        let tVal = document.getElementById(tID).value;
        let tSta = await isGA(v, tVal);
        if (tSta == "edt") {
            document.getElementById(tID).value = "";
            document.getElementById(tID).focus();
            break;
        } else if (tSta == "cls") {
            bootstrap.Modal.getInstance(document.getElementById("loadModal")).hide();
            break;
        } else if (tSta == "cnt") {
            grpArr.push(tVal);
            continue;
        }
        //delete i, tSta, tID, tVal;
    }
    if (lTyp2GA[ldTyp].length == grpArr.length) {
        updLoad(grpArr, more)
    };
    //delete ldTyp, grpArr;
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
                    <span class="category-title">${escHtml(type)}</span>
                    <span class="load-count">(${typeLoads.length})</span>
                </span>
            </button>
            ${isExpanded ? `<div class="category-content">${itemsHtml}</div>` : ""}
        </div>`;
    }).join("");

    setBackupAvailability();
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
    editIndex = -1;
    persistKNXSession();
    shwLds();
    setBackupAvailability();
    bootstrap.Modal.getInstance(document.getElementById("deleteModal")).hide();
}

async function donCnf() {
    let org = (window.location.origin).toString();
    if (!prepPrj()) return;

    let jsonData = JSON.stringify(KNXdata, null, 2);
    console.log(jsonData);
    let response = await fetch(org + "/makFile.php", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: jsonData
    });
    let result = await response.text();
    if (!result) {
        showError("Error sending Configuration Data to System.");
        return;
    }
    // Configuration successfully written to the board — drop the in-memory
    // session cache so the next page load starts clean.
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
    //delete gmTitle, cYESbtn, cNObtn, eMod, jsonData, response, result, org;
}

setBackupAvailability();
rehydrateKNXSession();
shwLds();
// Persist project metadata on blur so navigating between tabs keeps the
// in-progress inputs even before the user presses "Finish".
["prjNm", "knxIp", "knxPort"].forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.addEventListener("blur", updPrjMeta);
});
