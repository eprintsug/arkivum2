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
	//TODO stop hard coding this ;p
        self.defaults = {user : {type: "validuser"}};

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
	this.get_files_data = function(in_loop=false){
		var url="/cgi/export/eprint/"+eprintid+"/ArkivumFiles/"+repoid+"-eprint-"+(new Date).getTime()+".js";
		//console.log("url", url);
		self.ArkivumFiles_call = j.ajax( url )
		  .done(function(data) {
		    //console.log( "success", data, in_loop );
		//JSON.stringify comparison reports constant change after actual change. I imagine that the object is too complex for simpler comparison :(
		//Ideally something like this would allow us to pick changes to the astor_md (or doc_md) for each child but...
//		    if(in_loop && JSON.stringify(data.children) !== JSON.stringify(self.files_data.children)){
		//This will only trigger if a file has been added or removed
		    if(in_loop && data.children.length != self.files_data.children.length){
			//change detected reload tree with new data
			j("#file_tree").fancytree("getTree").reload([data]);
			//no need to init_buttons again here...
		    }

		    self.files_data = data;
		    if(!in_loop){
			//initial tree render:
			console.log("INIT FILE DATA",data);
		 	self.render_file_tree();
		    }
		    setTimeout(self.get_files_data, 10000, true);
		  })
		  .fail(function(jqXHR, textStatus) {
            
            j("#file_tree").before('<div class="ep_msg_warning"><div class="ep_msg_warning_content"><table><tbody><tr><td><img class="ep_msg_warning_icon" src="/style/images/warning.png" alt="Warning"></td><td><h3>Arkivum2 service parameters incorrect or unconfigured</h3><p>The Arkivum2 plugin cannot access the the Arkivum astor API. This is most likely because thee API URLS have not yet been entered in to the <strong><a target="_new" href="/cgi/users/home?screen=Admin::Config::View::Perl&configfile=cfg.d/z_arkivum.pl">cfg.d/z_arkivum.pl</a></strong> file.</p></td></tr></tbody></table></div></div>');
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "get_files_data complete" );
		  });

	};

	this.render_file_tree = function(){
		
		j("#file_tree").fancytree({
		  //TODO plug source in from TSWS
		  source: [self.files_data],
		  extensions: ["glyph", "wide", "persist", "table"],
		  glyph: glyph_opts,
		  checkbox: true,
		  selectMode: 3,
		  persist: {
		    // Available options with their default:
		    cookieDelimiter: "~",    // character used to join key strings
		    cookiePrefix: undefined, // 'fancytree-<treeId>-' by default
		    cookie: { // settings passed to jquery.cookie plugin
		      raw: false,
		      expires: "",
		      path: "",
		      domain: "",
		      secure: false
		    },
		    expandLazy: false, // true: recursively expand and load lazy nodes
  	  	    overrideSource: true,  // true: cookie takes precedence over `source` data attributes.
    		    store: "auto",     // 'cookie': use cookie, 'local': use localStore, 'session': use sessionStore
    		    types: "active expanded focus selected"  // which status types to store
  		  },
		table: {
        	checkboxColumnIdx: 1,
        	nodeColumnIdx: 2
      		},
 		renderColumns: self.render_columns,
		init: function(){
			self.file_tree = j("#file_tree").fancytree("getTree");
			self.file_tree.visit(function(node){
				node.setExpanded();
			});
		},
		
           });	
	   self.init_buttons();
	};
	this.render_columns = function(event,data){
	
		var node = data.node,
		tdList = j(node.tr).find(">td");
		thList = j(node.tr).parents("table").find("th");

		tdList.eq(0).text(node.getIndexHier());
		//adjust the visibility of the folder columns here
		if(node.isFolder() && self.page_type !== "dynamic"){
			tdList.eq(10).hide();
			tdList.eq(11).hide();
		}

		if(node.isFolder()) return true;

		tdList.eq(3).html(self.render_size(node));

		tdList.eq(4).html('<span class="glyphicon glyphicon-hdd '+node.data.astor_md.replicationState+'"></span>');
		var accessed = node.data.astor_md.accessed.split(/T/);
		tdList.eq(5).html('<span class="astor_accessed">'+accessed[0]+'</span>');
		tdList.eq(6).html('<span class="glyphicon glyphicon-option-vertical"></span>');

		//EPrints doc md	
		tdList.eq(7).html(self.render_link(node,"license",self.render_license(node)));
		tdList.eq(8).html(self.render_link(node,"security",self.render_security(node)));
		tdList.eq(9).html(self.render_link(node,"date_embargo",self.render_date_embargo(node)));
		if(self.page_type == "dynamic"){
			if(!self.ingested(node)){
				tdList.eq(10).html(self.render_link(node,"ingest",self.render_ingest(node)));
				tdList.eq(11).html(self.render_link(node,"delete",self.render_delete(node)));

			}else{
				tdList.eq(10).html(self.render_ingest(node));
				tdList.eq(11).html(self.render_delete(node));
			}
		}else{
			thList.eq(10).html("Download");
			tdList.eq(10).html(self.render_download_link(node,"download",render_download(node)));
			thList.eq(11).hide();
			tdList.eq(11).hide();

		}
	      };
	//******************************
	// File share API interaction
	//*****************************

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
	this.get_share = function(share_id){
		var url="/cgi/arkivum/shares";
		var data = {share_id: share_id, action: 'get'};
		console.log("url", url, data);

		j.ajax( url, {data: data, dataType: "xml" } )
		  .done(function(data) {
			//TODO better share rendering with render_share
	//	    self.shares = j("data > element", data);
	//	    self.render_shares();
		    console.log( "success", data );
		    j("#public_share_link").html('Download data: <a href="'+file_share_url+'/apps/files/?dir='+j("data file_target",data).text()+'">'+j("data file_target",data).text()+'</a>');

		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "get_share error", textStatus );
		  })
		  .always(function() {
		    console.log( "get_share complete" );
		  });
	};

	this.render_shares = function(){
		console.log(self.shares);
		j("ul.shares_list").empty();
		j(self.shares).each(function(i){
			if(j("share_type", this).text() == "3") //public
				j("ul.shares_list").append('<li>Public share link: <a href="'+file_share_url+'/s/'+j("token", this).text()+'">'+j("token", this).text()+'</a></li>');
			if(j("share_type", this).text() == "0") //user
				j("ul.shares_list").append('<li>User share with <a href="'+file_share_url+'/apps/files/?dir=/'+eprintid+'">'+j("share_with_displayname", this).text()+'</a></li>');

		})
	}
	//create share (with user)
	this.create_share = function(sw_username){
		var data = {eprintid: eprintid, action: 'create'};
		self._create_share(sw_username,data);		
		return false;
	};
	this.create_public_share = function(e){
		console.log("IN CREATE PUBLIC");
		var url="/cgi/arkivum/shares";
		var target = j(e.target); // Clicked button element (from the modal)
		var modal = j(target).closest('.modal'); //the modal

		var data = {eprintid: eprintid, action: 'create_download'};
		data.astorids = j(modal).data("astorids");
		//Need to assess  the whole  public/usershare piece properly		
		if(typeof username === "string")
			data.username = username;

		console.log("CALLING",url, data);
		j.ajax( url, {data: data, dataType: "xml" } )
		  .done(function(data) {
		    if(j("meta > statuscode", data).text() !== "100")
			console.log("Could not create a share: "+j("meta > message", data).text());
		    else{
			console.log("USERNAME: ",username);
			if(username !== "NO_USERNAME"){
				console.log("THIS IS WHAT WE KNOW:",data);			
				self.get_share(j("data > id", data).text());
			}else{
				j("#public_share_link").html('Download data: <a href="'+j("data > url",data).text()+'">'+j("data > token",data).text()+'</a>');
			}
		    }
		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "create_share complete" );
		  });
		return false;

	};
	this._create_share = function(sw_username,data){
		var url="/cgi/arkivum/shares";

		//TODO get this data contextually as we are calling by class and there are two....
		if(j("input[name='share_pw']")){
			j("input[name='share_pw']").each(function(){
				if(j(this).val()) data.password = j(this).val();
			});
		}

//		if(j("input[name='share_pw']").val())
//			data.password = j("input[name='share_pw']").val();
		if(typeof sw_username === "string")
			data.username = sw_username;

		console.log("CALLING",url, data);
		j.ajax( url, {data: data, dataType: "xml" } )
		  .done(function(data) {
			console.log(data);
		    if(j("meta > statuscode", data).text() !== "100")
			console.log("Could not create a share: "+j("meta > message", data).text());
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
		if(username === "NO_USERNAME"){
			j(".have_oc_user").hide();		
			j(".have_not_oc_user").hide();
			 return false;
		}
		j.ajax( url, {data: {username: username, action: 'get'}, dataType: "xml" } )
		  .done(function(data) {
		    console.log( "success", data, username );
	  	    j(".ep_username").html(username);
		    if(j("meta > statuscode", data).text() == "998"){
			console.log("HAVE NOT USER");
			j("input[name='oc_user']").val(username);
			j(".have_not_oc_user").show();
			j(".have_oc_user").hide();
		    }else{
			console.log("HAVE USER");
			j(".have_oc_user").show();
			j(".have_not_oc_user").hide();
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
		j("p.oc_user").html( );
		j(self.shares).each(function(i){
			j("ul.shares_list").append('<li><a href="'+file_share_url+'/'+j("token", this).text()+'">'+j("token", this).text()+'</a></li>');
		})
	}
	this.create_user = function(){

		var url="/cgi/arkivum/users";
		var data = {action: 'create', username: username};
		if(j("input[name='oc_pw']")){
			j("input[name='oc_pw']").each(function(){
				if(j(this).val()) data.password = j(this).val();
			});
		}
		j.ajax( url, {data: data, dataType: "xml" } )
		  .done(function(data) {
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

	//********************************
	// File metadata updating 
	//*******************************
	//is a file ingested into Arkivum?
	this.ingested = function(node){
/*
		    SYNC,            // File is on synchronized storage
		    UNINIT,          // Uninitialised (for backward compatibility)
		    PRIMARY_IP,      // primary ingest in progress
		    PRIMARY,       // primary ingest completed
		    SECONDARY_IP,    // secondary ingest in progress
		    SECONDARY,     // secondary ingest completed
		    FINAL,          // file has been fully ingested
		    PENDING, // file added to the pending archive package
		    ARCHIVED   // file added to a closed archive package
*/
	        if(node.isFolder()) return false;
		if(j.inArray(node.data.astor_md.ingestState,["NOTINGESTED","SYNC","UNINIT","PRIMARY_IP","PRIMARY"])>=0)
			return false;
		return true;
	}
	this.downloadable = function(node){
	        if(node.isFolder()) return false;
		//I'll workout bit gates another time
		if(self.user.staffonly)
			return true;
		if(j.inArray(self.user.type,["validuser","staffonly"])>=0  && j.inArray(node.data.doc_md.security,["public","validuser"])>=0)
			return true;
		if(j.inArray(self.user.type,["public","validuser","staffonly"])>=0 && j.inArray(node.data.doc_md.security,["public"])>=0)
			return true;

		return false;
	}

/*
	this.ingest_file = function(e){
	    	var target = j(e.target); // Clicked button element

		j(target).closest('.modal').on('hidden.bs.modal', function () {
			console.log("Time to ingest ", j(this).data("key"));
			var node = j("#file_tree").fancytree("getTree").getNodeByKey(j(this).data("key"));
			console.log("NODE: ",node.data.astor_md.name);
			var url = "/cgi/arkivum/ingest";
			var data = {astorid: j(this).data("key"), md5sum: "??", size: "??",checksumAlgorithm: "", compressionAlgorithm: "" };

			j(this).unbind('hidden.bs.modal');
	    	});

	};
	this.ark_ingest = function(){
		var data = {};
		data.astorids = [];
		j("#file_tree").fancytree("getTree").getSelectedNodes().each(function(node){
		     if(node.isFolder()) return false;
		     data.astorids.push(node.key);
		});

		data.eprintid = eprintid;
		var url="/cgi/arkivum/ingest";

		j.ajax( url, {data: data, dataType: "json" } )
		  .done(function(data) {
		    console.log( "success", data );
		    j("#file_tree").fancytree("getTree").reload([data]);
		    self.init_buttons();
		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "get_user complete" );
		  });
	
		return false;
	};
*/
	this.update_astor = function(e){
		var target = j(e.target); // Clicked button element (from the modal)
		var modal = j(target).closest('.modal'); //the modal
		var data = {};
		//value to update passed as event data
		data[e.data.md]=j(e.data.selector).val();
		//TODO this better:
		if(data.action === "ingest"){
			//TODO interface for getting hold of checksums and sizes
			//TODO handle multiple checksums
			data.checksums = [j("#ingest_checksum",modal).val()];	
			//TODO handle multiple sizes
			data.sizes = [7];
			//This is a cheap trick to show that ingest has been requested (NB won't work for batches)
			j(modal).on('hidden.bs.modal', function () {
				console.log("KEY:",j(this).data("astorids")[0],this);
				var node = j("#file_tree").fancytree("getTree").getNodeByKey(j(this).data("astorids")[0]);
				console.log(j(target));
//				j(target).parentd").html(self.render_ingest(node,true));
	    		});

		}
		//array of astorids
		data.astorids = j(modal).data("astorids");
		self._update_astor(data);

	};
	this._update_astor = function(data){
		//the eprintid
		data.eprintid = eprintid;

		var url = "/cgi/arkivum/update_astor";
		console.log("DATA TO update_astor: ",data);
		j.ajax( url, {data: data } )
		  .done(function(data) {
		    j("#file_tree").fancytree("getTree").reload([data]);
		    self.init_buttons();
		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "update_astor complete" );
		  });
	
//		return false;
	};

	this.update = function(e){
		var target = j(e.target); // Clicked button element (from the modal)
		var modal = j(target).closest('.modal'); //the modal
		var data = {};
		//value to update passed as event data
		data[e.data.md]=j(e.data.selector).val();
		//array of astorids
		data.astorids = j(modal).data("astorids");
		//the eprintid
		self._update(data);

	};
	this._update = function(data){
		data.eprintid = eprintid;

		var url = "/cgi/arkivum/update_doc_md";
		//console.log("DATA TO update_doc_md: ",data);
		j.ajax( url, {data: data, dataType: "json" } )
		  .done(function(data) {
		    j("#file_tree").fancytree("getTree").reload([data]);
		    self.init_buttons();
		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "update complete" );
		  });
	}

	this.show_modal = function(md, files){
		var data = {"astorids": []};
		var files_display = j("<ul></ul>");
		console.log(files);
		files.forEach(function(node){
 		     console.log(node);
		     if(node.isFolder()) return false;
		     data.astorids.push(node.key);
		     li = j("<li>"+node.data.astor_md.name+": </li>");
		     j(li).append(eval("self.render_"+md+"(node)"));
		     j(files_display).append(li);

		});
		console.log(j("#"+md+"_modal"));
		j('#'+md+'_modal').modal('show').data(data);
		j('#'+md+'_modal').on('shown.bs.modal', function () {
			j(".modal_filename").html(files_display);
//			console.log(files.length,files[0].data.doc_md[md])
			if(files.length == 1 && files[0].data.doc_md[md] != undefined){
				j("option[value='"+files[0].data.doc_md[md]+"']",this).prop("selected",true);
				j("input[value='"+security+"']",this).prop("checked",true);
			}

		});

		return false;
	};
	//*****************************
	// Render the metadata (icons)
	//*****************************
	this.render_size = function(node){
		size = node.data.astor_md.size.replace(/bytes/, 'B');
		var size_span = j('<span>'+size+'</span>');
		
		return size_span;
	};

	this.render_security = function(node){

		var security_span=j('<span class="glyphicon"></span>');
		security = false;
		if(node)
			security = node.data.doc_md.security;
		switch(security) {
		    case "staffonly":
			j(security_span).addClass("red glyphicon-lock").attr("title","Restricted to repository staff only");
			break;
    		    case "validuser":
			j(security_span).addClass("amber glyphicon-user").attr("title","Restricted to registered users only");
        		break;
		    case "public":
			j(security_span).addClass("green glyphicon-globe").attr("title","Accessible by all");
			break;
		    default : 
			j(security_span).addClass("glyphicon-lock");
		}
		return security_span;
	};

	this.render_license = function(node){
		var license_span = j('<span class="license '+node.data.doc_md.license+'"></span>');

		if(self.getCSS("backgroundImage",node.data.doc_md.license)=="none"){
			j(license_span).html(node.data.doc_md.license);
//			//phrase is available from doing the below... but too long in this context
//			//self.set_phrase("licenses_typename_"+node.data.doc_md.license,license_span);
		}
		self.set_attr_phrase("licenses_typename_"+node.data.doc_md.license,license_span,"title");
//		j(license_span).attr("title","expl here");
		return license_span;
	};

	this.render_date_embargo = function(node){
		var date_embargo_span = j('<span class="date_embargo not_set">No embargo</span>');


		if(node.data.doc_md.date_embargo != undefined){
			j(date_embargo_span).html(node.data.doc_md.date_embargo).removeClass("not_set");
			if(node.data.doc_md.security === "public")
				j(date_embargo_span).append('<span class="glyphicon glyphicon-exclamation-sign amber"></span> security is still public');
		}
		return date_embargo_span;
	};
	this.render_ingest = function(node,requested){
		var ingest_span = j('<span class="glyphicon glyphicon-import"></span>');
		if(!self.ingested(node))
			j(ingest_span).addClass("red");
		if(requested)
			j(ingest_span).addClass("amber");
		if(self.ingested(node))
			j(ingest_span).addClass("green");

		return ingest_span;
	};
	this.render_delete = function(node){
		var delete_span = j('<span class="glyphicon"></span>');
		if(!self.ingested(node))
			j(delete_span).addClass("glyphicon-trash");
		else
			j(delete_span).addClass("glyphicon-ban-circle red");

		return delete_span;
	};
	this.render_download = function(node){
		var download_span ="";
		if(self.downloadable(node))
			download_span = j('<span class="glyphicon glyphicon-cloud-download"></span>');
		return download_span;
	};

	this.render_link = function(node, md, content){
		if(self.page_type !== "dynamic"){
			return content;
		}
		var link = j('<a href="#" class="update_'+md+'" data-key="'+node.key+'"></a>');
		j(link).append(content);	
		return link;
	};

	this.render_download_link = function(node, md, content){
		var link = j('<a href="#" class="do_'+md+'" data-key="'+node.key+'"></a>');
		j(link).append(content);	
		return link;
	};

	
	this.init_buttons = function(){
//		console.log("############ INIT_BUTTONS #################");
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
		j("#download_share .oc_create_public_share").on("click", self.create_public_share);
		j("#upload_share .oc_create_share").on("click", self.create_share);

		j(".oc_create_user").on("click", self.create_user);
		j(".oc_create_user_share").on("click", self.create_user_share);

		//delete file from arkivum (if still in ingest-held)
		j("#batch_update_delete").on("click",function(){
			//apply filter for ingested things for this and delete
			self.show_modal("delete", j.grep(j("#file_tree").fancytree("getTree").getSelectedNodes(),function(node,i){ if(!self.ingested(node)) return node;}));
			return false;
		});
		j(".update_delete").on("click",function(){
			self.show_modal("delete", [self.file_tree.getNodeByKey(j(this).data("key"))]);
			return false;
		});
		j('#delete_submit').on('click',{md: "action", selector: "#delete"}, self.update_astor);

		//ingest file to arkivum (release from ingest-held)
		j("#batch_update_ingest").on("click",function(){
			//apply filter for ingested things for this and delete
			self.show_modal("ingest", j.grep(j("#file_tree").fancytree("getTree").getSelectedNodes(),function(node,i){ if(!self.ingested(node)) return node;}));
			return false;
		});
		j(".update_ingest").on("click",function(){
			self.show_modal("ingest", [self.file_tree.getNodeByKey(j(this).data("key"))]);
			return false;
		});
		j('#ingest_submit').on('click',{md: "action", selector: "#ingest"}, self.update_astor);

		//interface to update security
		j("#batch_update_security").on("click",function(){
			self.show_modal("security", j("#file_tree").fancytree("getTree").getSelectedNodes());
			return false;
		});
		j(".update_security").on("click",function(){
			self.show_modal("security", [self.file_tree.getNodeByKey(j(this).data("key"))]);
			return false;
		});
		j('#security_submit').on('click',{md: "security", selector: "#security_modal input[name='security']:checked"}, self.update);
		
		//interface to update license
		j("#batch_update_license").on("click",function(){
			self.show_modal("license", j("#file_tree").fancytree("getTree").getSelectedNodes());
			return false;
		});
		j(".update_license").on("click",function(){
			console.log("key: ",j(this).data("key"));
			self.show_modal("license", [self.file_tree.getNodeByKey(j(this).data("key"))]);
			return false;
		});
		j('#license_submit').on('click', {md: "license", selector: "#license_modal option:selected"},self.update);
		
		//interface to update embargo date
		j('#batch_update_date_embargo').on("click", function(){
			self.show_modal("date_embargo", j("#file_tree").fancytree("getTree").getSelectedNodes());
			return false;
		});
		j(".update_date_embargo").on("click",function(){
			self.show_modal("date_embargo", [self.file_tree.getNodeByKey(j(this).data("key"))]);
			return false;
		});
		j('#date_embargo_submit').on('click',{md: "date_embargo", selector:"#date_embargo"},self.update);

		j('#date_embargo').datepicker({format: 'yyyy-mm-dd'}).on('changeDate', function(ev){
  		  	j(this).datepicker('hide');
			j(this).show();
		});


		//interface to do download
		j("#batch_do_download").on("click",function(){
//			self.show_modal("download", j("#file_tree").fancytree("getTree").getSelectedNodes());
			self.show_modal("download", j.grep(j("#file_tree").fancytree("getTree").getSelectedNodes(),function(node,i){ if(self.downloadable(node)) return node;}));
			return false;
		});
		j(".do_download").on("click",function(){
			console.log("key: ",j(this).data("key"));
			self.show_modal("download", [self.file_tree.getNodeByKey(j(this).data("key"))]);
			return false;
		});
//		j('#download_submit').on('click', {md: "download", selector: "#download"},self.create_share);

/* not used
		//update the security if embargo is set
		j("#date_embargo_year").on("keyup",function(){
			console.log("changed", j(this).val());
			if(j(this).val().match(/\d{4}/)){
				console.log("valid year");
				j("#security").val("staffonly");
			}else{
				j("#security").val("public");
			}
		});
*/
	}; //end init_buttons

	//************************
	// Util functions
	//************************
	this.get_value = function(key,field){
		var node_data = self.file_tree.getNodeByKey(key).data;
		if(node_data.doc_md[field] != undefined)
			return node_data.doc_md[field];

		if(node_data.astor_md[field] != undefined)
			return node_data.astor_md[field];

	};
	this.getCSS = function (prop, fromClass) {
		var inspector = j("<div>").css('display', 'none').addClass(fromClass);
		j("body").append(inspector); // add to DOM, in order to read the CSS property
		try {
			return inspector.css(prop);
		} finally {
			inspector.remove(); // and remove from DOM
		}
	};
	this.set_phrase = function(phraseid, selector, context){
		var url="/cgi/arkivum/get_phrase";
		if(context == undefined) context = document;
		j.ajax( url, {data : {phraseid: phraseid}, dataType: "json" } )
		  .done(function(data) {
			j(selector, context).html(data[phraseid]);
		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "set_phrase complete" );
		  });

	};
	this.set_attr_phrase = function(phraseid, selector, attr, context){
		var url="/cgi/arkivum/get_phrase";
		if(context == undefined) context = document;
		j.ajax( url, {data : {phraseid: phraseid}, dataType: "json" } )
		  .done(function(data) {
			j(selector, context).attr(attr, data[phraseid]);
		  })
		  .fail(function(jqXHR, textStatus) {
		    console.log( "error", textStatus );
		  })
		  .always(function() {
		    console.log( "set_phrase complete" );
		  });

	};

	//boot...
	self.init(config);
}



var j = jQuery;

j.urlParam = function(name){
	var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
	if(results === null) return 0;
	return results[1] || 0;
}
j(document).ready(function(){

	//restrict (at the moment) to pages that can tell us an eprintid and are either the upload page or...
	console.log("Stage: ",j.urlParam("stage"));
	console.log("eprintid: ", eprintid);
	var page_type = "dynamic";
	var eprint_regex = /\/(\d+)(?:\/)$/;
	if((typeof eprintid == undefined || eprintid == null || eprintid === "NO_EPRINTID") && document.location.pathname.match(eprint_regex)!=null){
		//Looks like an abstract...
		eprintid = document.location.pathname.match(eprint_regex)[1];
		page_type = "static";
	}
	if(j.urlParam("stage") == 0 && page_type === "dynamic"){
		//looks like a preview
		page_type = "preview";
	}
	console.log("typeof eprintid: ", typeof eprintid);
	console.log("eprintid: ", eprintid);


	if((typeof eprintid === "undefined" || eprintid === null || eprintid === "NO_EPRINTID") && j.urlParam("stage") !== "files"){
		console.log("NO");
		return;
	}
	console.log("PAGETYPE:",page_type);
	Arkivum({eprintid: eprintid, page_type: page_type});
//	console.log("hello eprint: ",eprintid);

});
