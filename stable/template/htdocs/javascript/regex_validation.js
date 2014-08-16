function validate_required(field,alerttxt)
{
with (field)
  {
  if (value==null||value=="")
    {
    alert(alerttxt);return false;
    }
  else
    {
    return true;
    }
  }
}

function validate_form(thisform)
{
with (thisform)
  {

  if (validate_required(seq_file,"You must upload a sequence file")==false)
  {seq_file.focus();return false;}
  
  if (validate_required(regex,"You must fill in a regular expression")==false)
  {regex.focus();return false;}
  
  if (validate_required(qual_file,"You must upload a quality file")==false)
  {qual_file.focus();return false;}

  if( ref_file.value == "" && refseq_db.value == "no_selection" ){
  	alert("You must either upload a reference sequence file or chose a reference sequence database");
  	ref_file.focus();
  	return false;
  }	
  
  return true;

  }
}
