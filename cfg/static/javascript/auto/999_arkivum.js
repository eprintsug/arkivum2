/*
var a = arkivum_config = {};
//api calls (via cgi proxies)
//astor
a.get_files //get the asor object direct from astor api
a.create_folder //create a folder corresonding to the eprintid
//owncloud
a.create_share //create an upload share for the astor folder
a.get_shares //get available shares for folder
//eprints
a.sync_metadata //loop through current astor files and add, update or remove document objects as appropriate
a.create_metadata //create a document object in eprints with some initial metadata for one of the astor files
a.update_metadata //update the document metadata for one of the astor files
a.remove_metadata //remove the document metadata one of the astor files
*/
glyph_opts = {
    map: {
      doc: "glyphicon glyphicon-file",
      docOpen: "glyphicon glyphicon-file",
      checkbox: "glyphicon glyphicon-unchecked",
      checkboxSelected: "glyphicon glyphicon-check",
      checkboxUnknown: "glyphicon glyphicon-share",
      dragHelper: "glyphicon glyphicon-play",
      dropMarker: "glyphicon glyphicon-arrow-right",
      error: "glyphicon glyphicon-warning-sign",
      expanderClosed: "glyphicon glyphicon-plus-sign",
      expanderLazy: "glyphicon glyphicon-plus-sign",  // glyphicon-expand
      expanderOpen: "glyphicon glyphicon-minus-sign",  // glyphicon-collapse-down
      folder: "glyphicon glyphicon-folder-close",
      folderOpen: "glyphicon glyphicon-folder-open",
      loading: "glyphicon glyphicon-refresh"
    }
};

function Arkivum(config){

	self = this;
	//set default options here:
        self.defaults = {};

	this.init = function(config){
		self.set_options(config);
		console.log("Arkivum initalised for eprint: ",self.eprintid);
		self.get_files_data();
		self.get_shares();
		self.get_user();

	};
	this.set_options = function(config){
                //set any unset options that have defaults
                for(var opt in self.defaults){
                        if(config[opt] == undefined){
                                config[opt] = defaults[opt];
                        }
                }
                //then set config opts
                for(var opt in config){
                        console.log("setting option - "+opt+":"+config[opt]);
                        self[opt] = config[opt];
                }
        };

	//Call export on the ArkivumFiles Plugin, if an item folder doesn't already exist it will do after this
	this.get_files_data = function(){
		var url="/cgi/export/eprint/"+eprintid+"/ArkivumFiles/"+repoid+"-eprint-"+eprintid+".js";
		console.log("url", url);
		self.ArkivumFiles_call = j.ajax( url )
		  .done(function(data) {
		    console.log( "success", data );
		    self.files_data = data;
		    self.render_file_tree();
		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "get_files_data complete" );
		  });

	};
	this.render_file_tree = function(){
		
		j("#file_tree").fancytree({
		  //TODO plug source in from TSWS
		  source: [self.files_data ],
		  extensions: ["glyph", "wide"],
		  glyph: glyph_opts,
		  checkbox: true,
		  selectMode: 2,
		  lazyLoad: function(event,data) {
            		var node = data.node;   
//			console.log(data);
            		//data.node.load(true);             
            		// Issue an ajax request to load child nodes
//            		data.result = { cache:false, url: "myurl/jsonoutput", data: {key: node.key } }
        	  }, 
		});	
		self.init_buttons();
	};


	//Check for shares that already exist for this item
	this.get_shares = function(){
		var url="/cgi/arkivum/shares";
		console.log("url", url);
		self.ArkivumFiles_call = j.ajax( url, {data: {eprintid: eprintid, action: 'get'}, dataType: "xml" } )
		  .done(function(data) {
		    self.shares = j("data > element", data);
		    self.render_shares();
		    console.log( "success", data );
		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "get_shares complete" );
		  });

	};
	this.render_shares = function(){
		console.log(self.shares);
		j("ul#shares_list").empty();
		j(self.shares).each(function(i){
			if(j("share_type", this).text() == "3") //public
				j("ul#shares_list").append('<li>Public share link: <a href="'+file_share_url+'/s/'+j("token", this).text()+'">'+j("token", this).text()+'</a></li>');
			if(j("share_type", this).text() == "0") //user
				j("ul#shares_list").append('<li>User share with <a href="'+file_share_url+'/apps/files/?dir=/'+eprintid+'">'+j("share_with_displayname", this).text()+'</a></li>');

//			index.php/apps/files/?dir=%2F
		})
	}
	this.create_share = function(sw_username){

		var url="/cgi/arkivum/shares";
		var data = {eprintid: eprintid, action: 'create'};
		if(j("input[name='share_pw']").val())
			data.password = j("input[name='share_pw']").val();
		if(sw_username)
			data.username = sw_username;
		self.ArkivumFiles_call = j.ajax( url, {data: data, dataType: "xml" } )
		  .done(function(data) {
			console.log(data);
		    if(j("meta > statuscode", data).text() !== "100")
			alert("Could not create a share: "+j("meta > message", data).text());
		    else
			self.get_shares();
		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "create_share complete" );
		  });
		return false;

	};

	//Check for shares that already exist for this item
	this.get_user = function(){
		var url="/cgi/arkivum/users";
		j.ajax( url, {data: {username: username, action: 'get'}, dataType: "xml" } )
		  .done(function(data) {
		    console.log( "success", data, username );
	  	    j(".ep_username").html(username);
		    if(j("meta > statuscode", data).text() == "998"){
			j("input[name='oc_user']").val(username);
			j("#have_not_oc_user").show();
			j("#have_oc_user").hide();
		    }else{
			j("#have_oc_user").show();
			j("#have_not_oc_user").hide();
		    }

		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "get_user complete" );
		  });

	};
	this.render_user = function(){
		j("p#oc_user").html( );
		j(self.shares).each(function(i){
			console.log(i,j("token", this).text());
			j("ul#shares_list").append('<li><a href="'+file_share_url+'/'+j("token", this).text()+'">'+j("token", this).text()+'</a></li>');
		})
	}
	this.create_user = function(){

		var url="/cgi/arkivum/users";
		var data = {action: 'create', username: username};
		if(j("input[name='oc_pw']").val())
			data.password = j("input[name='oc_pw']").val();
		j.ajax( url, {data: data, dataType: "xml" } )
		  .done(function(data) {
		    console.log(data);
		    if(j("meta > statuscode", data).text() !== "100")
			alert("Could not create a user: "+j("meta > message", data).text());
		    else
			self.get_user();
		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "create_share complete" );
		  });
		return false;

	};
	this.create_user_share = function(){
		self.create_share(username);
		return false;
	};
	this.init_buttons = function(){
		j("#ft_expand_all").on("click", function(){
		   j("#file_tree").fancytree("getTree").visit(function(node){
		    	node.setExpanded(true);
		  });
		return false;
		});
		j("#ft_collapse_all").on("click", function(){
		   j("#file_tree").fancytree("getTree").visit(function(node){
		    	node.setExpanded(false);
		  });
		return false;
		});
		j("#ft_select_all").on("click", function(){
		   j("#file_tree").fancytree("getTree").visit(function(node){
		    	node.setSelected(true);
		  });
		return false;
		});
		j("#ft_deselect_all").on("click", function(){
		   j("#file_tree").fancytree("getTree").visit(function(node){
		    	node.setSelected(false);
		  });
		return false;
		});
		j("#oc_create_share").on("click", self.create_share);
		j("#oc_create_user").on("click", self.create_user);
		j("#oc_create_user_share").on("click", self.create_user_share);
	};
	self.init();
}



var j = jQuery;

j(document).ready(function(){

	if(typeof eprintid === "undefined"){
		return;
	}
	Arkivum({eprintid: eprintid});
//	console.log("hello eprint: ",eprintid);

});
