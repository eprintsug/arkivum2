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
		self.render_file_tree();
	}
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

	this.render_file_tree = function(){
		
		j("#file_tree").fancytree({
		  //TODO plug source in from TSWS
		  source: [
		    {title: "Root folder for item #"+eprintid, key: "ROOT", folder: true, children: [
			    {title: "Folder", key: "1", folder: true, children: [
				      {title: "File", key: "pcks-nfsf-3f9d20-i2n0"},
				      {title: "File", key: "dvon-pueb-v49bpw-uv94"}
			    ]},
			    {title: "Folder", key: "2", folder: true, children: [
			      {title: "File", key: "wef4-33yh-43fefe3-f3ff"},
			      {title: "File", key: "wefe-tjtr-gg4gshj-egw3"}
			    ]}
			  ]}
		    ],
		  extensions: ["glyph", "wide"],
		  glyph: glyph_opts,
		  checkbox: true,
		  selectMode: 2,
		});	
		self.init_buttons();
	}
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

	}
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
