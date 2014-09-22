function lineWithError(e, equation) {
    if( e.line !== undefined && e.column !== undefined ){    	
    	var lines = equation.split("\n");    	
    	return lines[ e.line - 1  ] + '\n' +Array(e.column).join(" ") + '^';    	    	
    }else{
    	return '';
    }        
}


function errorInfo(e) {
    if( e.line !== undefined && e.column !== undefined ){
    	return 'Error on:'    	    	
    }else{
    	return 'Unrecognizable genotype equation!';
    }        
}



jQuery(document).ready(function() {

// Validate genotype equation
jQuery("#query_db").submit(function( event ) {
	
	  var equation = jQuery('textarea[name=genotype_equation]').val(); 
	  try {
		    // Using PEG.js to validate equation
		    peg_genotype_equation.parse(equation)
		    
	  }catch(err) {
		  	jQuery('#ge_info').text(errorInfo(err));
		    jQuery('#ge_error').html(lineWithError(err,equation));
		    jQuery('#ge_error_border').css({"border-style":"solid","border-color": "red", "border-width": "2px", "background-color":"#FFD6D6"});
		    jQuery('textarea[name=genotype_equation]').focus();
		    event.preventDefault();
		    return false;
	  }
	  return true;
});

   
});