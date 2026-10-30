import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';

// User and Record imports
import USER_ID from '@salesforce/user/Id';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';

// Import Apex Controller methods
import getFullOkrData from '@salesforce/apex/OkrController.getFullOkrData';
import createObjective from '@salesforce/apex/OkrController.createObjective';
import createKeyResult from '@salesforce/apex/OkrController.createKeyResult';
import createTarget from '@salesforce/apex/OkrController.createTarget';
import deleteObjectives from '@salesforce/apex/OkrController.deleteObjectives';
import deleteKeyResults from '@salesforce/apex/OkrController.deleteKeyResults';

// dragging
import updateObjectiveOrder from '@salesforce/apex/OkrController.updateObjectiveOrder';
import updateKeyResultOrder from '@salesforce/apex/OkrController.updateKeyResultOrder';

// 1. import custom labels
import OKR_Dashboard_Title from '@salesforce/label/c.OKR_Dashboard_Title';
import New_Objective from '@salesforce/label/c.New_Objective';
import New_Key_Result from '@salesforce/label/c.New_Key_Result';
import New_Target from '@salesforce/label/c.New_Target';
import Btn_Save_Objective from '@salesforce/label/c.Btn_Save_Objective';
import Lbl_Objective_Name from '@salesforce/label/c.Lbl_Objective_Name';

export default class OkrDashboard extends LightningElement {
    
    // labels to html
    labels = {
        OKR_Dashboard_Title,
        New_Objective,
        New_Key_Result,
        New_Target,
        Btn_Save_Objective, 
        Lbl_Objective_Name  
    };


    // State tracking
    @track groupedObjectives = [];
    @track objectiveOptions = []; 
    @track groupedKeyResultOptions = []; 
    @track isEditMode = false;
    
    selectedObjectiveIds = [];
    selectedKeyResultIds = [];
    wiredOkrResult; // Stores the raw wire result to enable refreshApex

    // Header tracking (User & Year)
    @track selectedUserId = USER_ID;
    @track selectedYear = new Date().getFullYear().toString();
    @track selectedUserName = '';

    targetObjectOptions = [
        { label: 'Calls', value: 'Calls' },
        { label: 'Case studies', value: 'Case studies'},
        { label: 'Contracts', value: 'Contracts'},
        { label: 'Events', value: 'Events'},
        { label: 'Google reviews', value: 'Google reviews'},
        { label: 'Leads', value: 'Leads'},
        { label: 'Opportunities', value: 'Opportunities'},
        { label: 'Reviews', value: 'Reviews' },
        { label: 'Surveys', value: 'Surveys' }
    ];

    draggedId;
    draggedType;
    draggedParentId;

    // get current user name
    @wire(getRecord, { recordId: '$selectedUserId', fields: [USER_NAME_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            this.selectedUserName = getFieldValue(data, USER_NAME_FIELD);
        } else if (error) {
            console.error('Error fetching user name', error);
        }
    }

    //  Main data wire (reactive with parameters) 
    @wire(getFullOkrData, { userId: '$selectedUserId', year: '$selectedYear' })
    wiredOkrData(result) {
        this.wiredOkrResult = result; 
        const { error, data } = result;

        if (data) {
            let objMap = new Map();
            let tempObjOptions = [];
            
            // 1. Process ALL Objectives first
            if (data.objectives) {
                data.objectives.forEach(obj => {
                    objMap.set(obj.Id, {
                        Id: obj.Id,
                        Name: obj.Name,
                        Year: obj.Year__c,
                        KeyResults: []
                    });
                    tempObjOptions.push({ label: obj.Name, value: obj.Id });
                });
            }
            
            // 2. Process Key Results and place them inside their Objectives
            if (data.keyResults) {
                data.keyResults.forEach(kr => {
                    let formattedTargets = [];
                    if (kr.Targets__r) {
                        formattedTargets = kr.Targets__r.map(t => {
                            let percent = t.Target_Number__c > 0 ? Math.round((t.Completed__c / t.Target_Number__c) * 100) : 0;
                            return { ...t, progressPercent: percent };
                        });
                    }

                    if (objMap.has(kr.Objective__c)) {
                        objMap.get(kr.Objective__c).KeyResults.push({
                            Id: kr.Id,
                            Name: kr.Name,
                            Targets: formattedTargets
                        });
                    }
                });
            }
            
            this.groupedObjectives = Array.from(objMap.values());
            this.objectiveOptions = tempObjOptions;

            // 3. format data for grouped drop down
            this.groupedKeyResultOptions = this.groupedObjectives.map(obj => {
                return {
                    objectiveId: obj.Id,
                    objectiveName: obj.Name,
                    keyResults: obj.KeyResults.map(kr => {
                        return { label: kr.Name, value: kr.Id };
                    })
                };
            }).filter(group => group.keyResults.length > 0); 

        } else if (error) {
            console.error('Error fetching OKR data: ', error);
        }
    }

    //  UI getters
    get editButtonLabel() {
        return this.isEditMode ? 'Cancel Edit' : 'Edit Dashboard';
    }

    get yearOptions() {
        let years = [];
        // Generate years from 2023 to 2100
        for (let i = 2023; i <= 2100; i++) {
            years.push({ label: i.toString(), value: i.toString() });
        }
        return years;
    }

    // Header Handlers
    handleYearChange(event) {
        this.selectedYear = event.detail.value;
    }

    handleUserChange(event) {
        if (event.detail.recordId) {
            this.selectedUserId = event.detail.recordId;
        } else {
            this.selectedUserId = USER_ID; 
        }
    }

    // Creation Handlers
    handleCreateObjective() {
        const nameCmp = this.template.querySelector('.obj-name');
        const yearCmp = this.template.querySelector('.obj-year');

        // Stop if invalid OR if the values are completely blank
        if (!nameCmp.checkValidity() || !yearCmp.checkValidity() || !nameCmp.value || !yearCmp.value) {
            nameCmp.reportValidity();
            yearCmp.reportValidity();
            return; 
        }

        createObjective({ name: nameCmp.value, userId: this.selectedUserId, objectiveYear: yearCmp.value })
            .then(() => {
                alert('Objective Created Successfully!');
                nameCmp.value = '';
                yearCmp.value = '';
                return refreshApex(this.wiredOkrResult); 
            })
            .catch(error => {
                let errorMessage = 'Error creating objective.';
                if (error.body && error.body.message) {
                    errorMessage = error.body.message;
                }
                console.error('Error:', error);
                alert(errorMessage);
            });
    }

    handleCreateKeyResult() {
        const objCmp = this.template.querySelector('.kr-objective');
        const nameCmp = this.template.querySelector('.kr-name');

        // Stop if invalid OR if the values are completely blank
        if (!objCmp.checkValidity() || !nameCmp.checkValidity() || !objCmp.value || !nameCmp.value) {
            objCmp.reportValidity();
            nameCmp.reportValidity();
            return;
        }

        createKeyResult({ name: nameCmp.value, objectiveId: objCmp.value, contractFilter: '' })
        .then(() => {
            alert('Key Result Created Successfully!');
            nameCmp.value = '';
            objCmp.value = ''; 
            return refreshApex(this.wiredOkrResult); 
        })
        .catch(error => {
            let errorMessage = 'Error creating Key Result.';
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            }
            alert(errorMessage);
        });
    }

    handleCreateTarget() {
        const krCmp = this.template.querySelector('.tgt-keyresult');
        const objCmp = this.template.querySelector('.tgt-object');
        const numCmp = this.template.querySelector('.tgt-number');

        if (!krCmp.checkValidity() || !objCmp.checkValidity() || !numCmp.checkValidity()) {
            krCmp.reportValidity();
            objCmp.reportValidity();
            numCmp.reportValidity();
            return;
        }

        let parentObjectiveName = '';
        let keyResultName = '';
        
        for (let obj of this.groupedObjectives) {
            let foundKr = obj.KeyResults.find(k => k.Id === krCmp.value);
            if (foundKr) {
                parentObjectiveName = obj.Name;
                keyResultName = foundKr.Name;
                break;
            }
        }

        const uniqueTargetName = parentObjectiveName + ' > ' + keyResultName + ' - ' + objCmp.value + ' Target';

        createTarget({ 
            name: uniqueTargetName, 
            targetNumber: numCmp.value, 
            targetObject: objCmp.value, 
            keyResultId: krCmp.value 
        })
        .then(() => {
            alert('Target Created Successfully!');
            krCmp.value = '';
            objCmp.value = '';
            numCmp.value = '';
            return refreshApex(this.wiredOkrResult); 
        })
        .catch(error => {
            let errorMessage = 'Error creating Target.';
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            }
            console.error('Error:', error);
            alert(errorMessage); 
        });
    }

    // Deletion / Edit handlers
    toggleEditMode() {
        this.isEditMode = !this.isEditMode;
        if (!this.isEditMode) {
            this.selectedObjectiveIds = [];
            this.selectedKeyResultIds = [];
        }
    }

    handleCheckboxChange(event) {
        const recordId = event.target.dataset.id;
        const type = event.target.dataset.type; 
        const isChecked = event.target.checked;

        if (type === 'objective') {
            if (isChecked) {
                this.selectedObjectiveIds.push(recordId);
            } else {
                this.selectedObjectiveIds = this.selectedObjectiveIds.filter(id => id !== recordId);
            }
        } else if (type === 'keyresult') {
            if (isChecked) {
                this.selectedKeyResultIds.push(recordId);
            } else {
                this.selectedKeyResultIds = this.selectedKeyResultIds.filter(id => id !== recordId);
            }
        }
    }

    handleDeleteSelected() {
        if (this.selectedObjectiveIds.length === 0 && this.selectedKeyResultIds.length === 0) {
            alert('Please select at least one item to delete.');
            return;
        }

        if (confirm('Are you sure you want to delete the selected items? All nested records will be lost.')) {
            let promises = [];
            
            if (this.selectedObjectiveIds.length > 0) {
                promises.push(deleteObjectives({ objectiveIds: this.selectedObjectiveIds }));
            }
            if (this.selectedKeyResultIds.length > 0) {
                promises.push(deleteKeyResults({ keyResultIds: this.selectedKeyResultIds }));
            }

            Promise.all(promises)
                .then(() => {
                    alert('Selected items deleted successfully.');
                    this.toggleEditMode(); 
                    return refreshApex(this.wiredOkrResult); 
                })
                .catch(error => {
                    console.error('Error deleting items', error);
                    alert('An error occurred while deleting items.');
                });
        }
    }

    // Drag and Drop logic

    handleDragStart(event) {
        event.stopPropagation();
        this.draggedId = event.currentTarget.dataset.id;
        this.draggedType = event.currentTarget.dataset.type;
        this.draggedParentId = event.currentTarget.dataset.objId;
        event.currentTarget.classList.add('drag-active');
    }

    handleDragOver(event) {
        event.preventDefault(); // Required to allow drop
        event.stopPropagation();
    }

    handleDragEnter(event) {
        event.preventDefault();
        event.stopPropagation();
        // Highlight only if dragging the same type (Obj over Obj, or KR over KR)
        if (event.currentTarget.dataset.type === this.draggedType) {
            event.currentTarget.classList.add('drag-over');
        }
    }

    handleDragLeave(event) {
        event.stopPropagation();
        event.currentTarget.classList.remove('drag-over');
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        
        // Remove highlight styles
        this.template.querySelectorAll('.drop-zone').forEach(el => {
            el.classList.remove('drag-over', 'drag-active');
        });

        const targetId = event.currentTarget.dataset.id;
        const targetType = event.currentTarget.dataset.type;
        const targetParentId = event.currentTarget.dataset.objId;

        // Validation: mix types, drop on itself
        if (this.draggedType !== targetType || this.draggedId === targetId) return;

        if (this.draggedType === 'objective') {
            this.reorderObjectives(this.draggedId, targetId);
        } else if (this.draggedType === 'keyresult' && this.draggedParentId === targetParentId) {
            this.reorderKeyResults(this.draggedParentId, this.draggedId, targetId);
        }
    }


    // save permanently

    reorderObjectives(dragId, dropId) {
        let items = [...this.groupedObjectives];
        const dragIndex = items.findIndex(item => item.Id === dragId);
        const dropIndex = items.findIndex(item => item.Id === dropId);

        const [draggedItem] = items.splice(dragIndex, 1);
        items.splice(dropIndex, 0, draggedItem);
        
        this.groupedObjectives = items; // Update UI immediately

        const orderedIds = items.map(item => item.Id);
        updateObjectiveOrder({ orderedIds }).catch(error => console.error(error));
    }

    reorderKeyResults(objId, dragId, dropId) {
        let items = [...this.groupedObjectives];
        const objIndex = items.findIndex(obj => obj.Id === objId);
        
        let krs = [...items[objIndex].KeyResults];
        const dragIndex = krs.findIndex(kr => kr.Id === dragId);
        const dropIndex = krs.findIndex(kr => kr.Id === dropId);

        const [draggedItem] = krs.splice(dragIndex, 1);
        krs.splice(dropIndex, 0, draggedItem);
        
        items[objIndex].KeyResults = krs;
        this.groupedObjectives = items; // Update UI immediately

        const orderedIds = krs.map(kr => kr.Id);
        updateKeyResultOrder({ orderedIds }).catch(error => console.error(error));
    }
}