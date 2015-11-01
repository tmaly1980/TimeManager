function addShortcutPopup(shurl)
{
  windowOpen('cgi-bin/Shortcuts.pl/Add?shurl='+shurl, 'addShortcut', 370, 175, 0);
}

function editShortcutPopup(shid)
{
  windowOpen('cgi-bin/Shortcuts.pl?shortcut_id='+shid, 'editShortcut'+shid, 465, 600, 0);
}

function searchProjectPopup()
{
  var link_field = arguments[0];
  var qs = arguments[1] || "";
  windowOpen('cgi-bin/Projects.pl/Search?popup=1&link_field='+link_field+'&'+qs, 'searchProject', 675, 400, 1);
}

function editProjectPopup(pid)
{
  windowOpen('cgi-bin/Projects.pl/Edit?pid='+pid, 'editProject_'+pid, 475, 600, 1);
}

function viewProjectPopup(pid)
{
  windowOpen('cgi-bin/Projects.pl/View?popup=1&pid='+pid, 'viewProject_'+pid, 600, 600, 1);
}

function widgetPopup(url, name)
{
  var w = arguments[2] || "450";
  var h = arguments[3] || "550";

  windowOpen(url, name, w, h, 1);
}

function ganttProjectPopup(pid)
{
  windowOpen('cgi-bin/POOP.pl/Gantt?fit=1&pid='+pid, 'editProject_'+pid, 725, 450, 0);
}

function viewGanttPopup(field, value)
{
  windowOpen('cgi-bin/Analysis.pl/Gantt?'+field+'='+value, 'viewGantt_'+field+'_'+value, 800, 550, 0);
}

function workloadPopup(uid)
{
  var start = arguments[1];
  var end = arguments[2];
  var qs = "";

  if (uid.type == 'select-one')
  {
    for (var i = 0; i < uid.length; i++)
    {
      if(uid.options[i].value != '' && (uid.selectedIndex == 0 || uid.selectedIndex == i)) 
      { 
        qs += "uid="+uid.options[i].value+"&";
      }
    }
    // We also want to update this on clicking on the names....
    qs += "select="+uid.id+"&";
  } 
  else if (uid.length)
  {
    for(var i = 0; i < uid.length; i++)
    {
      if (uid[i].type == 'checkbox' && uid[i].checked)
      {
        qs += "uid="+uid[i].value+"&";
      } else if (uid[i].type != 'checkbox') {
        qs += "uid="+uid[i]+"&";
      }
    }
  }
  else if (uid.type == 'checkbox')
  {
    if (uid.checked)
    {
      qs += "uid="+uid.value+"&";
    }
  } else {
    qs += "uid="+uid+"&";
  }

  // Now, take into consideration the dates....
  if (start) // ASSUMES CORRECT FORMAT DATE!
  {
    if (start.type == 'text')
    {
      qs += "startdate="+start.value+"&";
    } else {
      qs += "startdate="+start+"&";
    }
  }

  if (end) // ASSUMES CORRECT FORMAT DATE!
  {
    if (end.type == 'text')
    {
      qs += "enddate="+end.value+"&";
    } else {
      qs += "enddate="+end+"&";
    }
  }

  windowOpen('cgi-bin/Admin.pl/workload?'+qs, 'workload', 825, 450, 1);
}

function addProjectPopup()
{
  windowOpen('cgi-bin/Projects.pl/Add', 'addProject', 475, 600, 1);
}

function addTaskPopup()
{
  var qs = arguments[0];
  var linkField = arguments[1];
  var url = 'cgi-bin/Tasks.pl/Add?';
  var name = 'addTask';

  if (linkField)
  {
    url = url + '&link_field='+linkField;
  }

  if (qs)
  {
    url = url + '&' + qs;
  }

  windowOpen(url, name, 550, 550, 1);
}

function editTaskPopup(tid)
{
  var project_id = arguments[1];
  var url = "cgi-bin/Tasks.pl/Edit?tid="+tid;
  var name = "editTask_" + tid;
  if (project_id != null)
  {
    url = url + "&project_id="+project_id;
    name = name + "_"+project_id;
  }
  windowOpen(url, name, 550, 550, 1);
}

function searchTaskPopup()
{
  taskSearchPopup(arguments[0], arguments[1], arguments[2]);
}

function taskSearchPopup()
{
  var qs = arguments[0];
  var linkField = arguments[1] || '';
  var qs_nosearch = arguments[2]; // Query to give, but not yet to search on (to refine fields!)
  var url = "cgi-bin/Tasks.pl/Search?popup=1&link_field="+linkField
  if (qs_nosearch)
  {
    url = url+"&"+qs_nosearch;
  }
  else if (qs) // Don't do search unless gave query!
  {
    url = url+"&action=Search&no_search_form=1&"+qs;
  }

  windowOpen(url, "searchTask", 725, 400, 1);
}

function editDependencies(tid)
{
  windowOpen('cgi-bin/Tasks.pl/Edit?edit_dependencies=1&tid='+tid, 'dependencies_'+tid, 450, 300, 1);
}

function setDatePopup(field)
{
  var month = arguments[1];
  windowOpen('cgi-bin/Calendar.pl/month/'+month+'?set_field='+field, 'setDate', 250, 300, 0);

}

function searchMilestonePopup()
{
  var link_field = arguments[0];
  var qs = arguments[1];
  windowOpen('cgi-bin/TaskGroups.pl/Search?popup=1&link_field='+link_field+'&'+qs, 'searchMilestone', 675, 400, 1);
}

function viewMilestonePopup(mid)
{
  windowOpen('cgi-bin/TaskGroups.pl/Edit?mid='+mid, 'editMilestone_'+mid, 775, 450, 1);
}

function editMilestonePopup(mid)
{
  windowOpen('cgi-bin/TaskGroups.pl/Edit?mid='+mid, 'editMilestone_'+mid, 775, 450, 1);
}

function addMilestonePopup()
{
  var pid = arguments[0];
  var link_field = arguments[1];
  var url = 'cgi-bin/TaskGroups.pl/Add?';
  if (pid != '' && pid != null)
  {
    url = url + 'pid='+pid+'&';
  }
  if (link_field)
  {
    url = url + 'link_field='+link_field;
  }
  windowOpen(url, 'addMilestone', 750, 450, 1);
}

function addEventPopup()
{
  windowOpen('cgi-bin/Events.pl/Add', 'addEvent', 750, 580, 0);
}

function editEventPopup(eid)
{
  windowOpen('cgi-bin/Events.pl?event_id='+eid, 'editEvent'+eid, 750, 580, 0);
}

function addProductPopup()
{
  windowOpen('cgi-bin/Products.pl?add=1', 'addProduct', 450, 620, 1);
}

function editProductPopup(prod_id)
{
  windowOpen('cgi-bin/Products.pl/product/Edit?prod_id='+prod_id, 'editProduct_'+prod_id, 450, 620, 1);
}

function viewProductPopup(prod_id)
{
  windowOpen('cgi-bin/Products.pl/product/View?prod_id='+prod_id, 'viewProduct_'+prod_id, 700, 400, 1);
}

function addFeatureRequestPopup()
{
  windowOpen('cgi-bin/Products.pl/frequest/Add', 'addFeatureRequest', 700, 600, 1);
}

function editFeatureRequestPopup(req_id)
{
  windowOpen('cgi-bin/Products.pl/frequest/Edit?req_id='+req_id, 'editFeatureRequest_'+req_id, 700, 600, 1);
}

function editProductVersionPopup(prod_id, ver_id)
{
  windowOpen('cgi-bin/Products.pl/version/Edit?prod_id='+prod_id+'&ver_id='+ver_id, 'editProductVersion_'+prod_id+'_'+ver_id, 700, 600, 1);
}

function addCompetitorPopup(prod_id)
{
  windowOpen('cgi-bin/Products.pl/competitor/Add?prod_id='+prod_id, 'addCompetitor_'+prod_id, 835, 600, 1);
}

function editCompetitorPopup(comp_id)
{
  windowOpen('cgi-bin/Products.pl/competitor/Edit?comp_id='+comp_id, 'editCompetitor_'+comp_id, 835, 600, 1);
}

function editGoalPopup(goal_id)
{
  windowOpen('cgi-bin/Products.pl/goal/Edit?goal_id='+goal_id, 'editGoal_'+goal_id, 835, 600, 1);
}

function addGoalPopup(prod_ver_id)
{
  windowOpen('cgi-bin/Products.pl/goal/Add?prod_ver_id='+prod_ver_id, 'addGoal_'+prod_ver_id, 835, 600, 1);
}


function editComponentPopup(component_id)
{
  windowOpen('cgi-bin/Products.pl/component/Edit?component_id='+component_id, 'editComponent_'+component_id, 650, 450, 1);
}

function addComponentPopup(prod_ver_id)
{
  windowOpen('cgi-bin/Products.pl/component/Add?prod_ver_id='+prod_ver_id, 'addComponent_'+prod_ver_id, 650, 450, 1);
}

function editComponentFeaturePopup(cfeature_id)
{
  windowOpen('cgi-bin/Products.pl/component_feature/Edit?cfeature_id='+cfeature_id, 'editComponentFeature_'+cfeature_id, 625, 400, 1);
}

function addComponentFeaturePopup(component_id)
{
  windowOpen('cgi-bin/Products.pl/component_feature/Add?component_id='+component_id, 'addComponentFeature_'+component_id, 625, 400, 1);
}


function editComponentFeatureItemPopup(fitem_id)
{
  windowOpen('cgi-bin/Products.pl/feature_item/Edit?fitem_id='+fitem_id, 'editComponentFeatureItem_'+fitem_id, 835, 600, 1);
}

function addComponentFeatureItemPopup(cfeature_id)
{
  windowOpen('cgi-bin/Products.pl/feature_item/Add?cfeature_id='+cfeature_id, 'addComponentFeatureItem_'+cfeature_id, 835, 600, 1);
}

function editDocumentationPopup(ver_id)
{
  windowOpen('cgi-bin/Products.pl/documentation/Edit?ver_id='+ver_id, 'editDocumentation_'+ver_id, 500, 600, 1);
}








function origAddProductPopup()
{
  windowOpen('cgi-bin/Admin.pl/product?add=1', 'addProduct', 350, 350, 1);
}

function origViewProductPopup(prod_id)
{
  windowOpen('cgi-bin/Admin.pl/product?prod_id='+prod_id, 'editProduct_'+prod_id, 350, 350, 1);
}




function addUserPopup()
{
  windowOpen('cgi-bin/Admin.pl/user?add=1', 'addUser', 450, 475, 1);
}

function editUserPopup(uid)
{
  var id = get_field_value(uid);
  if (!id || id == '') { id = uid; }
  windowOpen('cgi-bin/Admin.pl/user?uid='+id, 'editUser_'+id, 450, 620, 1);
}

function addGroupPopup()
{
  windowOpen('cgi-bin/Admin.pl/group?add=1', 'addGroup', 525, 475, 1);
}

function editGroupPopup(gid)
{
  windowOpen('cgi-bin/Admin.pl/group?gid='+gid, 'editGroup_'+gid, 525, 475, 1);
}


function closePopup()
{
  var noreload = arguments[0];
  if (self.opener && !noreload && ! self.opener.noreload)
  {
    self.opener.location.reload();
  }
  window.close();
}

function closeFramesetPopup()
{
  var noreload = arguments[0];
  if (!window.parent) { closePopup(noreload); }
  if (window.parent.opener && !noreload)
  {
    window.parent.opener.location.reload();
  }
  window.parent.close();
}

function dateTimePopup(name)
{
  windowOpen('cgi-bin/Calendar.pl/dateTime_'+name, 'dateTime', 200, 300, 0);
}

function timeSet(hr, min, field)
{
  var hour = hr.value;
  if (hour < 10) { hour = "0" + hour; }
  field.value = hour + ":" + min.value;
}

function dateSet(field, ymd)
{
  if (window.opener)
  {
    var f = window.opener.document.getElementById(field);
    if (f)
    {
      f.value = ymd;
    }
  }
  return false; // Don't follow link!
}


function resetOwner (form)
{
  if (!form.uid) { return; } // Not there, i.e., Personal.
  form.uid.selectedIndex = -1;
  for(var i = form.uid.length - 1; i >= 0; i--)
  {
    form.uid.options[i] = null; // Remove from list.
  }
  form.uid.options[0] = new Option("Click Save to Refresh", "");
}

function updatePercent (status, percent)
{
  var datefield = arguments[2];
  var datevalue = arguments[3];
  if (status.selectedIndex == -1) { return; }
  var opt = status.options[status.selectedIndex];
  if (opt)
  {
    var value = opt.value;

    if (value == 0)
    {
      set_select(percent, "0");
    } else if (value >= 10 && value < 20) { // Cancelled
      if (datefield)
      {
        datefield.value = datevalue;
      }
    } else if (value >= 20) {
      set_select(percent, "100");
      if (datefield)
      {
        datefield.value = datevalue;
      }
    }
  }
}

function updateStatus (percent, status)
{
  var datefield = arguments[2];
  var datevalue = arguments[3];
  if (percent.selectedIndex == -1) { return; }
  var opt = percent.options[percent.selectedIndex];
  if (opt)
  {
    var value = opt.value;
    if (value == 100) // Set to last option, Completed
    {
      set_select(status, "20");
      if (datefield)
      {
        datefield.value = datevalue;
      }
      // NEEDS TO BE SET FOR % to 100 also
    } 
    else if (value == 0) // Set to first option, not started
    {
      set_select(status, "0");
    }
    else // Set to In Progress (1)
    {
      set_select(status, "1");
    }
  }
}

function checkDateFormat(obj)
{
  if (!obj) { return false; }
  if (obj.value != '' && obj.value.search(/^\d{4}-\d{2}-\d{2}$/) < 0)
  {
    alert("Please use YYYY-MM-DD format.");
    obj.select();
    obj.focus();
    return false;
  }
}

function linkField(field_id, value, text)
{
  var opener = window.opener;
  if (!opener)
  {
    alert("Cannot link, parent window was closed.");
    return false;
  }
  var field = opener.document.getElementById(field_id);
  if (!field) { return false; } // BLAH

  // It's a select list, so append.
  field.options[field.length] = new Option(text, value);
  if (field_id == 'SUBTASKS')
  {
    alert("Please make sure to save the parent task for the linking to take effect.");
  } else if (field_id == 'TGROUPS') {
    alert("Please make sure to save the milestone's task for the linking to take effect.");
  } else {
    alert("Please make sure to save the containing task for the linking to take effect.");
  }

  // Now copy over any EXTRA data....
  for (var i = 3; i < arguments.length; i+=2)
  {
    var key = arguments[i];
    var value = arguments[i+1];
    var field = opener.document.getElementById(key);
    if (field)
    {
      var old_value = get_field_value(field);
      if (!old_value)
      {
        set_field(field, value);
      }
    }
  }
  return false;
}

function linkMileToTask(field_id, value, text)
{
  linkField(field_id, value, text);
  if (field_id == 'TGROUPS') // Linking mile to task window.
  // Copy dates and product over, too. If not already set!
  {

  }
}

function checkAll(f, x, name)
// Later on, add support so can be just PREFIX of id. Will need to do regex of whole form's elements, though
{
  var a = f[name];
  if (a && a.length)
  {
    for(var i = 0; i < a.length; i++)
    {
      a[i].checked = x.checked;
    }
  } else if (a) {
      a.checked = x.checked;
  } else { // Try as prefix.
    var re = new RegExp('^'+name+'_');
    for (var i = 0; i < f.elements.length; i++)
    {
      var field = f.elements[i];
      var id = field.id;
      if (id && id.length && id.match(re)) // Found it!
      {
        field.checked = x.checked;
      }
    }
  }

}
