// Copyright 2003 - 2004 MalySoft, http://www.malysoft.com/
// Use, duplication, reading, and copying of this further code is subject to the User License Agreement.

function set_checkbox(checkbox, val) // Checkbox (one or more)
{
  var default_value = arguments[2];
  var multiple = arguments[3];
  if (!checkbox) { return; }
  var found = 0;

  checkbox = get_field(checkbox);
  

  if (checkbox.length)
  {
    for(var i = 0 ; i < checkbox.length; i++)
    {
      found = set_checkbox(checkbox[i], val, null, multiple);
    }

    if (found == 0 && default_value)
    {
      for(var i = 0 ; i < checkbox.length; i++)
      {
        found = set_checkbox(checkbox[i], default_value, multiple);
      }
    }
  } else {
    var values = multiple ? val.split(",") : new Array(val);
    var default_values = multiple ? val.split(",") : new Array(val);

    found = 0;
    for (var i = 0; i < values.length; i++)
    {
      var value = values[i];
      if (checkbox.value == value)
      {
        checkbox.checked = 1;
	found = 1;
      } else {
        checkbox.checked = 0;
      }
    }

    for (var i = 0; i < default_values.length; i++)
    {
      var default_value = default_values[i];
      if (checkbox.value == default_value)
      {
        checkbox.checked = 1;
	found = 1;
      } else {
        checkbox.checked = 0;
      }
    }
  }
  return found;
}

function set_radio(radiogroup, val) // Radio group
{
    var default_value = arguments[2];
    if (!radiogroup) { return; }
    var found = 0;
    if (radiogroup.length)
    {
      for (var i = 0; i < radiogroup.length; i++)
      {
        set_radio(radiogroup[i], val);
      }

      if (found == 0 && default_value)
      {
        for (var i = 0; i < radiogroup.length; i++)
	{
          set_radio(radiogroup[i], default_value);
	}
      }
    } else {
      if (radiogroup.value == val || radiogroup.value == default_value)
      {
        radiogroup.checked = 1;
	return 1;
      }
    }
}

function set_popup(sel, val)
{
  var def = arguments[2];
  return set_select(sel, val, def);
}

function set_select_or_text(sel, text, val)
{
  sel = get_field(sel);
  text = get_field(text);

  set_select(sel, val);
  if (! get_field_value(sel) )
  {
    set_text(text, val);
  }
}
                    
function set_select(sel, val) // Drop-down list.
{
    var default_value = arguments[2];
    sel = get_field(sel);
    if (!sel || sel.type != 'select-one') { return; }
    // CHANGED 01/23/04, only do "" as first option. and in that case, DONT do a default value! (use maly-if to determine whether to do that or not)
      for (var i = 0; i < sel.options.length; i++)
      {
        var opt = sel.options[i];
        if (opt.value == val)
        {
          opt.selected = 1;
          return;
        }
      }
    // Not found, set to one with default value.
    for (var i = 0; i < sel.options.length; i++)
    {
      var opt = sel.options[i];
      if (opt.value == default_value)
      {
        opt.selected = 1;
        return;
      }
    }
}

function set_multiselect(sel, val) // Select box, with multiple values. 'val' is probably an array.
{
    var default_value = arguments[2]; // comma separated list (string) or Array.
    if (!sel || sel.type != 'select-multiple') { return; }

    if (typeof val == 'string') { val = val.split(","); } 
    var found = 0;
    for (var i = 0; i < sel.length; i++)
    {
      var opt = sel.options[i];
      for (var j = 0; j < val.length; j++)
      {
        if (opt.value == val[j])
        {
          opt.selected = 1;
          found = 1;
        }
      }
    }
    if (found) { return; }

    // Not found, set to one with default value.
    if (! default_value.length) { default_value = new Array(default_value); }
    for (var i = 0; i < sel.options.length; i++)
    {
      var opt = sel.options[i];


      for (var j  = 0; j < default_value.length; i++)
      {
        if (opt.value == default_value[j])
        {
          opt.selected = 1;
          return;
        }
      }
    }
}

function clear_select(sel) // Given either string for getElementById, or given object.
{
  if (!sel) { return; }

  sel = get_field(sel);

  if (sel.length && ! sel.type) {
    for (var i = 0; i < sel.length; i++)
    {
      clear_select(sel[i]);
    }
  } else if (sel.type == 'select-one' || sel.type == 'select-multiple') {
    sel.options.length = 0;
  } else {
    var obj=document.getElementById(sel);
    if (obj)
    {
      obj.options.length = 0;
    }
  }
  return false;
}

function field_has_value(obj) // If text, not empty. if radio/check, value not 0/null. if select, value not ''
{
  if (!obj) { return false; }
  if (obj.type == 'select-one' || obj.type == 'select-multiple')
  {
    if (obj.selectedIndex >= 0)
    {
      return (obj.options[obj.selectedIndex].value != "");
    }
  } 
  else if (obj.type == 'hidden' || obj.type == 'text')
  {
    return (obj.value != '');
  }
  else if (obj.type == 'radio' || obj.type == 'checkbox')
  {
    return (obj.checked);
  }
  else if (obj.length)
  {
    for (var i = 0; i < obj.length; i++)
    {
      var fhv = field_has_value(obj[i]);
      if (fhv) { return fhv; }
    }
  }
  return false;
}
                                                            
function popWin(url, name, w, h)
{
  var scroll=arguments[4]||'yes';
  var opts = 'menubar=0,toolbar=0,location=0,scrollbars='+scroll+',copyhistory=0,width='+w+',height='+h;
  window.open(url, name, opts);
  return false;
}

//Get name for default items, not just value.
//Get list of all values, in proper order. Sort.
function listDefault(left, right, items, names, all_values)
{
  // Move everything on right to left, even default (which is moved later).
  for (var r=right.options.length-1; r>=0; r--)
  {
    var right_o = right.options[r];
    var left_o = new Option(right_o.text, right_o.value, false, false);
    left.options[left.options.length] = left_o;
    right.options[r] = null;
  }

  for (var i=0; i<items.length; i++)
  {
    // Move the default values found on left onto right.
    for (var l=left.options.length-1; l>=0; l--)
    {
      var left_o = left.options[l];
      if (left_o.value == items[i])
      {
	var right_o = new Option(left_o.text, left_o.value, false, false);
	right.insertBefore(right_o, right.firstChild);
	left.options[l] = null;
      }
    }
  }

  var sorted_left_options = new Array();
  var sorted_right_options = new Array();

  for (var v=0; v<all_values.length; v++)
  {
    var value = all_values[v];

    // Sort left list.
    for (var l = 0; l< left.options.length; l++)
    {
      var left_o = left.options[l];
      if (left_o.value == value) // If in left list.
      { sorted_left_options[sorted_left_options.length] = new Option(left_o.text, left_o.value); }
    }

    // Sort right list.
    for (var r=0; r<right.options.length; r++)
    {
      var right_o = right.options[r];
      if (right_o.value == value) // If in left list.
      { sorted_right_options[sorted_right_options.length] = new Option(right_o.text, right_o.value); }
    }
  }

  for(var i=0; i<left.options.length; i++) // Give new order
  { left.options[i] = sorted_left_options[i]; }

  for(var i=0; i<right.options.length; i++) // Give new order
  { right.options[i] = sorted_right_options[i]; }


}

function get_field(sel) // Gets either an object or a string, and returns the object.
{
  if (typeof sel == 'string') // id tag
  {
    sel = document.getElementById(sel);
  }
  return sel;
}

function moveDualList( from, to)
{
  var defaultValues = arguments[2];
  var shouldSort = arguments[3];
  var moveLeft = arguments[4];

  from = get_field(from);
  to = get_field(to);

  if (!from || !to)
  {
    return false;
  }

  // Return if none set in from.
  if (from.selectedIndex == -1)
  {
    return false;
  }

  // Set in new.
  for( var i = 0; i<from.options.length; i++)
  {
    var o = from.options[i];
    if (o.selected) { to.options[to.options.length] = new Option(o.text, o.value, false, false); }
  }

  // Remove from old.
  if (from.type == 'select-one' && from.selectedIndex >= 0) // Only remove initially selected, as removing will reselect another
  {
    from.options[from.selectedIndex] = null;
  } else {
    for (var i = (from.options.length-1); i>=0; i--)
    {
      var o = from.options[i];
      if (o.selected) { from.options[i] = null; }
    }
  }


  var left = from;
  var right = to;

  if (moveLeft)
  {
    left = to;
    right = from;
  }

  if (defaultValues)
  {
  
    // Move defaults to right ONLY if empty at end. Else, make sure on left. (remove and insertbefore)
    // Remove default values from side getting new values. Add to other side (on top).
    // if left is getting new values, move defaults to right if right is empty after.
  
    if (moveLeft) 
    {
      if (right.options.length <= 0) // If nothing left on right afterwards.
      {
        for(var g=left.options.length-1; g>=0; g--)
        {
          var o = left.options[g];
          for(var y=defaultValues.length-1; y>=0; y--)
          {
  	    if (defaultValues[y] == o.value)
  	    {
              right.insertBefore(new Option(o.text, o.value), right.firstChild);
  	      left.options[g] = null; // Remove from left.
  	      break;
  	    }
          }
        }
      }
    } else { // Moving to right, Adding. Remove default values.
      for(var y=right.options.length-1; y>=0; y--)
      {
        var o = right.options[y];
        for(var z=defaultValues.length-1; z>=0; z--)
        {
          if (o.value == defaultValues[z]) // If right option is default value, remove since other adding.
  	  {
  	    left.insertBefore(new Option(o.text, o.value), left.firstChild);
  	    // Move to left side. Remove from right side.
  	    right.options[y] = null;
  	    break;
  	  }
        }
      }
    }
  
  }

  // Do sorting.
  if (shouldSort)
  {
    //alphabetize(from);
    alphabetize(to);
  }

  from.selectedIndex = -1;
  to.selectedIndex = -1;
  return false;
}

function opt_sort(a, b)
{
  if (a.value == null || a.value == '')
  {
    return -1;
  } 
  else if (b.value == null || b.value == '')
  {
    return 1;
  } else if (a.text < b.text)
  {
    return -1;
  } else if (a.text > b.text)
  {
    return 1;
  }
  return 0;
}
                                                                                                                  
function alphabetize(sel)
{
  if (!sel) { return; }
  var list = new Array();
  for(var x = 0; x < sel.options.length; x++)
  {
    var old_opt = sel.options[x];
    var opt = new Option(old_opt.text, old_opt.value);
    list.push(opt);
  }
  list.sort(opt_sort);
  for (var y = 0; y < list.length; y++)
  {
    var value = list[y];
    sel.options[y] = value;
  }
}

function selectSubmit(selects)
{
  if (typeof selects == 'string')
  {
    selects = get_field(selects);
  }
  if (selects == null || !selects) { return; }
  if (selects.length && ! selects.type)
  {
    for(var i = 0; i < selects.length; i++)
    {
      var sel = get_field(selects[i]); // could be object or id.
      for (var j = 0; j < sel.length; j++)
      {
        sel.options[j].selected = 1;
      }
    }
  } else { // Single one.
    var sel = get_field(selects); // object or id.
    for (var i = 0; i < sel.length; i++)
    {
      sel.options[i].selected = 1;
    }
  }
  return true;
}

function submit_handler (selects)
{
  // Perhaps switch to names....
  if (selects == null || selects.length == 0) { return; }
  for (var i=0; i<selects.length; i++)
  {
    var s = selects[i];
    if (s == null || s.options == null || s.options.length == 0) { continue; }
    for (var j=0; j<s.options.length; j++)
    {
      s.options[j].selected = true;
    }
  }
}

function multiList_submit_handler(f)
{
  // Take each element. If selects has corresponding FOO_TEXT, select all inside.
  if (!f || !f.elements) { return false; }
  for (var i = 0; i < f.elements.length; i++)
  {
    var field = f.elements[i];
    if (field && field.type == 'select-multiple' && f.elements[field.name+'_TEXT']) // Select all.
    {
      for (var j=0; j<field.options.length; j++)
      {
        field.options[j].selected = true;
      }
    }

  }
  return true;
}


function text_get(text) // joins the values from one or more text fields, with ':' delimiting. Return empty string if no values in anything.
{
  var values = new Array;
  var delim  = arguments[1] || ':';
  text = get_field(text);
  var text_list;
  if (text.type == 'text' || text.type == 'select-multiple')
  {
    text_list = new Array(text);
  } else if (typeof text == 'object' && text.length) { // Array
    text_list = text;
  }

  for (var i = 0; i < text_list.length; i++)
  {
    var field = get_field(text_list[i]);
    if (field.type == 'select-multiple')
    {
      for(var x = 0; x < field.length; x++)
      {
        values.push(field.options[x].value);
      }
    } else {
      values.push(field.value);
    }
  }

  if (values.join("") == "") { return ""; }

  return values.join(delim);
}

function text_set(text, value) // Sets one or more text fields with the value, split at ':'
{
  var delim = arguments[2];
  var values = value.split(delim);
  var text_list;
  text = get_field(text);
  if (text.type == 'text' || text.type == 'select-multiple')
  {
    text_list = new Array(text);
  } else if (typeof text == 'object' && text.length) { // Array
    text_list = text;
  }

  for (var i = 0; i < text_list.length; i++)
  {
    var field = text_list[i];
    field = get_field(field);
    if (field.type == 'select-multiple') // Gobble up rest.
    {
      clear_select(field);
      for (var x = 0; x < values.length; x++)
      {
        field.options[field.length] = new Option(values[x], values[x]);
      }
    } else {
      set_field(field, values.shift() || "");
    }
  }
  return true;
}

function multiList_down(list)
{
  list = get_field(list);
  var text = arguments[1];
  var keep_highlighted = arguments[2];
  var ix = list.selectedIndex;
  var new_ix = ix+1;
  var opt = list.options[ix];
  var opt2 = null;
  var opt2style = null;
  if (list.options.length == 1)
  {
    return false;
  }
  if (new_ix >= list.options.length)
  {
    new_ix = list.options.length-1;
  } else {
    opt2 = list.options[new_ix];
    opt2style = opt2.getAttribute('style');
  }
  if (new_ix >= list.options.length)
  {
    new_ix = list.options.length-1;
  }
  list.options[new_ix] = new Option(opt.text, opt.value);
  var optstyle = opt.getAttribute('style');
  list.options[new_ix].setAttribute('style', optstyle);
  if (opt2)
  {
    list.options[ix] = new Option(opt2.text, opt2.value);
    list.options[ix].setAttribute('style', opt2style);
  }
  if (keep_highlighted)
  {
    list.selectedIndex = new_ix;
  } else {
    list.selectedIndex == -1;
    if (text) { text_set(text, ""); }
  }

  return false;
}

function multiList_up(list)
{
  list = get_field(list);
  var text = arguments[1];
  var keep_highlighted = arguments[2];
  var ix = list.selectedIndex;
  var new_ix = ix-1;
  var opt = list.options[ix];
  var opt2 = null;
  var opt2style = null;
  if (list.options.length == 1)
  {
    return false;
  }
  if (new_ix < 0)
  {
    new_ix = 0;
  } else {
    opt2 = list.options[new_ix];
    opt2style = opt2.getAttribute('style');
  }
  list.options[new_ix] = new Option(opt.text, opt.value);
  var optstyle = opt.getAttribute('style');
  list.options[new_ix].setAttribute('style', optstyle);
  if (opt2)
  {
    list.options[ix] = new Option(opt2.text, opt2.value);
    list.options[ix].setAttribute('style', opt2style);
  }
  if (keep_highlighted)
  {
    list.selectedIndex = new_ix;
  } else {
    list.selectedIndex == -1;
    if (text) { text_set(text, ""); }
  }

  return false;
}

function multiList_remove(list, text)
{
  list = get_field(list);
  for(var i = list.options.length-1; i>=0; i--)
  {
    if (list.options[i].selected) { list.options[i] = null; }
  }
  text_set(text, "");
  if (list.options.length == 0) { list.className = "arealist"; } // Keep fixed width.
  return false;
}

// Takes two multi select lists, clicking on the left will transfer all the encoded values to the right.
// In which the right is a multiList, where each can be edited using a text box below.
function dualMultiList_edit(mainlist, sublist)
{
  mainlist = get_field(mainlist);
  sublist = get_field(sublist);
  var optional_box = arguments[2];


  if (!mainlist || !sublist)
  {
    return false;
  }

  var option = mainlist.options[mainlist.selectedIndex];
  if (!option)
  {
    return false;
  }

  var values = new Array();
  var parts = option.value.split("|");
  var list = parts[1]; // 0 is the name of the real field.

  if (list)
  {
    values = list.split(':');
  } // Else, it doesnt have any values yet.

  clear_select(sublist);

  for (var i = 0; i < values.length; i++)
  {
    sublist.options[i] = new Option(values[i] || '[ No Value ]', values[i]);
  }

  if (sublist.options[0] && sublist.options[0].value == '' && optional_box)
  {
    optional_box.checked = 1;
  } else {
    optional_box.checked = 0;
  }
  return true;
}

function dualMultiList_save(mainlist, sublist, sublist_text)
{
  mainlist = get_field(mainlist);
  sublist = get_field(sublist);
  var optional_box = arguments[3];
  if (!mainlist || !sublist || mainlist.selectedIndex == -1)
  {
    return false;
  }

  var values = new Array();

  for(var i = 0; i < sublist.length; i++)
  {
    values.push(sublist.options[i].value);
  }

  var concat_value = values.join(":");
  var old_value = mainlist.options[mainlist.selectedIndex].value;
  var parts = old_value.split("|");
  var key = parts[0]; 
  var new_value = key + "|" + concat_value;
  mainlist.options[mainlist.selectedIndex].value = new_value;
  mainlist.selectedIndex = -1;
  sublist.selectedIndex = -1;
  clear_select(sublist);
  sublist_text.value = "";
  if (optional_box) { optional_box.checked = 0; }
  return true;
}

function dualMultiList_optional(sublist, checkbox) // Takes checkbox value to either add or remove initial value of sublist, IF EMPTY VALUE!
{
  sublist = get_field(sublist);
  if (!sublist || !checkbox) { return false; }
  if (checkbox.checked && (!sublist.length || sublist.options[0].value != '')) // Add if not already there.
  {
    for(var i = sublist.length; i > 0; i--)
    {
      var prev = sublist.options[i-1];
      sublist.options[i] = new Option(prev.text, prev.value);
    }
    sublist.options[0] = new Option('[ No Value ]', "");
  } else if (! checkbox.checked && sublist.length && sublist.options[0].value == '') { // Remove if there.
    sublist.options[0] = null;
  }
}

// MUST BE PUT IN onChange ! IE apparently calls onClick BEFORE it gets changed.
function multiList_edit(list, text)
// Copy from list to text.
{
  list = get_field(list);
  text = get_field(text);
  var delim = arguments[2] || ':';
  if (list.type != 'select-multiple' || list.selectedIndex == -1)
  {
    return false;
  }

  var value = list.options[list.selectedIndex].value;

  if (text.length && ! text.type) // Array
  {
    text_set(text, value, delim);
  } else { // Just text.
    text.value = value;
  }
  return false;
}

function multiList_replace(list, text)
// Replace existing value.
{
  list = get_field(list);
  var format = arguments[2];
  var delim = arguments[3] || ':';
  multiList_modify(list, text, list.selectedIndex, format, delim);
  return false;
}


function multiList_add(list, text)
{
  var format = arguments[2];
  var delim = arguments[3] || ':';
  multiList_modify(list, text, -1, format, delim);
  return false;
}

// SPECIFY DISPLAY FORMAT VIA SPRINTF!!! PASSED TO MULTILIST ADD/REPLACE/EDIT!

function multiList_modify(list, text, replace_index)
{
  //list.className = ""; // Remove width info.
  list = get_field(list);
  var format = arguments[3];
  var delim = arguments[4] || ':';
  if (replace_index == -1) { replace_index = list.options.length; }
  // we get back a single colon (could be more).....
  var text_value = text_get(text, delim);
  if (text_value == "" || !text_value) { return false; }
  var text_text = text_format(format, text_value, delim);
  list.options[replace_index] = new Option(text_text, text_value);
  text_set(text, "");

  return false;
}

function text_format(format, value) // Takes format string with regexes and splits value at :, returning a string fitting the format.
{
  var values;
  var delim = arguments[2] || ':';
  if (format && typeof format != 'string')
  {
    return false;
  }

  if (typeof value == 'string')
  {
    values = value.split(delim);
  } else {
    values = value;
  }

  if (!format)
  {
    format = '%0%'; // Just the first one, by default/.
  }

  var output = format;

  // GO through format string, and do regex replace for #n# with values[n]
  for (var i = 0; i < values.length; i++)
  {
    output = output.replace(new RegExp("%"+i+"%", 'g'), values[i]);
  }
  output = output.replace(/%\d+%/g, "");
  return output;
}

function joined_list_to_hidden(list, hidden)
{
  // Update hidden field
  var hidden_value = "";
  for(var n=0; n<list.options.length; n++)
  {
    if (hidden_value != "") { hidden_value += "\n"; }
    hidden_value += list.options[n].value;
  }

  hidden.value = hidden_value;
}

function windowOpen(url)
{
  // Generation of unique names? way to get names from window object?
  // I.e., take name as prefix, or if no name, default to 'popup'
  // And append some unique number to end.

  // Need to add base tag, if it is defined and url doesnt start with http[s]:// or /

  var name = arguments[1];
  var w = arguments[2];
  var h = arguments[3];
  var scrollbars = arguments[4];

  if (arguments.length < 4) { scrollbars = 1; } // Assume we want unless say no.

  var absolute_url = url;
  var tags = document.getElementsByTagName("base");
  var base = tags.item(0);

  if ( 
   ( url.search(/^http[s]?:\/\//i) == -1 && url.search(/^\//) == -1) 
   && base && base.href
     )
  {
    absolute_url = base.href + url;
  }

  var win = window.open(absolute_url, name, 'status=0,toolbar=0'+
    ',width='+w+',height='+h+',scrollbars='+scrollbars);
  return win;
}


// Two lists, with a subset union. What is in one list is dependent on what is selected on the other.
function crossList_change(sel, othersel, otheroptmap, listmap)
{
  // We want to make sure that the OTHER field has a compa`
  // This should take the other list and populate it with an appropriate value.
  // We can assume that we wont run into conflicts, as populating the list takes into consideration this' value.

  var selval = null;
  if (sel.selectedIndex > 0)
  {
    selval = sel.options[sel.selectedIndex].value;
  } // ELSE, RESET OTHERSEL

  var otherselval = null;
  if (othersel.selectedIndex > 0)
  {
    otherselval = othersel.options[othersel.selectedIndex].value;
  }

  crossList_populate(othersel, otheroptmap, listmap, selval);
  set_select(othersel, otherselval);
}

// Arguments:
// The select list your populating, 
// the option map, 
// the crosslist map (the other list being the first element), 
// the specific key of the other list to restrict to (optional)
//
function crossList_populate(sel, optmap, listmap)
{
  var restrict = arguments[3]; // Restrictions, if any.
  var current_value = null;
  if (sel.selectedIndex >= 0)
  {
    current_value = sel.options[sel.selectedIndex].value;
  }

  var values = new Array();

  // Get a list of which ones to enable.

  for(var i = 0; i < listmap.length; i++)
  {
    var key = listmap[i][0];
    var value = listmap[i][1];
    if ((restrict == 0 || !restrict || restrict == null) || key == restrict)
    {
      values.push(value);
    }
  }

  if (!listmap.length || !restrict || !values.length) // Fill in all the way anyway.
  {
    for (var key in optmap)
    {
      values.push(key);
    }
  }

  // Now that we have the values of the options, create them.
  sel.options.length = 0;
  sel.options[0] = new Option("None", "");

  // XXX TODO WE MAY HAVE DUPS!
  var found = new Array();
  var k = 1;

  for (var j = 0; j < values.length; j++)
  {
    // Get the option's text from optmap
    var key = values[j];
    if (!found[key])
    {
      var text = optmap[key];
      var opt = new Option(text, key);
      found[key] = 1;
      sel.options[k] = opt;
      k++;
    }
  }
  alphabetize(sel);
}

function set_field(f, v) // Tries to figure out what is, calls appropriate function
{
  f = get_field(f); // If given ID, get the object.
  var d = arguments[2];
  if (!f) { return; }
  var type = f.type;
  if (!f.type) { return; }
  if (type == 'select-one')
  {
    set_select(f, v, d);
  } else if (type == 'select-multiple') {
    set_multiselect(f, v, d);
  } else if (type == 'text' || type == 'hidden') {
    set_text(f, v, d);
  } else if (type == 'textarea') {
    set_text(f, v, d);
  } else if (type == 'checkbox') {
    set_checkbox(f, v, d);
  } else if (type == 'radio') {
    set_radio(f, v, d);
  }
  return 1;
}

function require_field_value(f)
{
  var name = arguments[1];
  f = get_field(f);
  if (!f) { return true; }
  var value = get_field_value(f);
  if (value == '')
  {
    if (name)
    {
      alert("Must enter in value for "+name);
    } else {
      alert("Must enter in value.");
    }
    f.focus();
    return false;
  }
  return true;
}

function get_field_value(f)
{
  f = get_field(f);
  if (!f) { return; }
  var type = f.type;
  if (!type && f.length) // Loop over nodelist
  {
    var values = new Array();
    for (var i = 0; i < f.length; i++)
    {
      var value = get_field_value(f[i]);
      values.push(value);
    }
    return values;
  }

  if (!type) { return; }
  if (type == 'select-one')
  {
    if (f.selectedIndex != -1)
    {
      return f.options[f.selectedIndex].value;
    }
  } else if (type == 'select-multiple') {
    var values = new Array();
    for (var i = 0; i < f.length; i++)
    {
      if (f.options[i].selected)
      {
        values.push(f.options[i].value);
      }
    }
    return values;
  } else if (type == 'text' || type == 'hidden' || type == 'textarea') {
    return f.value;
  } else if (type == 'checkbox' || type == 'radio') {
    return f.checked ? f.value : null;
  }
  return undef;
}

function set_text(f, v, d)
{
  if (!f) { return; }
  if (! f.type && f.length)
  {
    var values = new Array();
    if (typeof v == 'object' && v.length) { values = v; }
    else { values.push(v); }

    var defaults = new Array();
    if (typeof d == 'object' && d.length) { defaults = d; }
    else { defaults.push(d); }

    for (var i = 0; i < f.length; i++)
    {
      set_text(f[i], values[i], defaults[i]);
    }
    return;
  }
  
  if (f.type != 'text' && f.type != 'textarea' && f.type != 'hidden') { return; }
  if (!v && d)
  {
    f.value = d;
  } else {
    f.value = v;
  }
}

  function hideSection(name)
  {
    var div = get_field(name);
    div.style.display = 'none';
  }
  
  function showSection(name)
  {
    var div = get_field(name);
    div.style.display = 'block';
  }

  function toggleSection(box, name)
  {
    if (!box) { return; }
    box.checked ? showSection(name) : hideSection(name);
  }


