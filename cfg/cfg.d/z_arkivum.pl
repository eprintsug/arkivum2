
my $arkivum = {};
$c->{arkivum} = $arkivum;

$arkivum->{archive_api} = "https://82.144.240.138:8443";
$arkivum->{file_share_host} = "82.144.240.135/owncloud";
$arkivum->{file_share_user} = "astoradmin";
$arkivum->{file_share_password} = "arkivum";


$arkivum->{file_share_api} = "https://".$arkivum->{file_share_user}.":".$arkivum->{file_share_password}."\@".$arkivum->{file_share_host}."/ocs/v1.php/apps/files_sharing/api/v1";
$arkivum->{file_share_url} = "https://".$arkivum->{file_share_host}."/index.php";
$arkivum->{'symlink'} = "symlink_to_astor"; #Must exist and be symlinked to file_share platform
$arkivum->{oc_users_api} = "https://".$arkivum->{file_share_user}.":".$arkivum->{file_share_password}."\@".$arkivum->{file_share_host}."/ocs/v1.php/cloud";

$arkivum->{default_document_security} = "public";
$arkivum->{default_document_license} = "cc_by_nd";

#This is actually just a sub dir in this case
$arkivum->{datapool} = "owncloud_astoradmin";

#NOT USED #TODO remove this and pm
$c->{plugins}->{"Screen::EPrint::UploadMethod::Arkivum"}->{params}->{disable} = 1;

$c->{plugins}->{"Export::ArkivumFiles"}->{params}->{disable} = 0;

$c->{plugin_alias_map}->{"InputForm::Component::Documents"} = "InputForm::Component::ArkivumDocuments";
$c->{plugin_alias_map}->{"InputForm::Component::ArkivumDocuments"} = undef;

$arkivum->{libs} = {
		    cdn => [
			"https://code.jquery.com/jquery-2.2.3.min.js",
			"https://code.jquery.com/ui/1.10.4/jquery-ui.min.js",
			"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js",
			"https://cdnjs.cloudflare.com/ajax/libs/jquery.fancytree/2.17.0/jquery.fancytree-all.min.js",
			"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css",
			"https://cdnjs.cloudflare.com/ajax/libs/jquery.fancytree/2.17.0/skin-bootstrap/ui.fancytree.min.css"
			],
		#Add refs for local libs here if necessary
		local => [],
		};
$arkivum->{lib_source} = "cdn"; #set to "local" ro use local libs

#TODO pull this straught fdrom namedset config
$arkivum->{licenses} = [qw(cc_by_nd 
cc_by 
cc_by_nc
cc_by_nc_nd
cc_by_nc_sa
cc_by_sa
cc_by_nd_4
cc_by_4
cc_by_nc_4
cc_by_nc_nd_4
cc_by_nc_sa_4
cc_by_sa_4
cc_public_domain
cc_gnu_gpl
cc_gnu_lgpl
)];
$arkivum->{days} = [1..31];
#dynamic_template_trigger to add js/css libraries
$c->add_trigger( EP_TRIGGER_DYNAMIC_TEMPLATE, sub {
	my %params = @_;

	my $repo = $params{repository};
	my $pins = $params{pins};
	my $xhtml = $repo->xhtml;

        my $head = $repo->make_doc_fragment;

	# dynamic CSS/JS settings
	my $eprintid;
	if(defined $repo->param("eprintid")){
		$eprintid = $repo->param("eprintid");
	}elsif($repo->current_url =~ /\/(\d+)$/){
		$eprintid = $1;
	}

	if(defined $eprintid){	
		$head->appendChild( $repo->make_javascript(sprintf(<<'EOJ',
var eprintid = %s;
var repoid = %s;
var file_share_url = %s;
var username = %s;
EOJ
			(map { EPrints::Utils::js_string( $_ ) }
				 $eprintid ),
			(map { EPrints::Utils::js_string( $_ ) }
				 $repo->get_id ),
			(map { EPrints::Utils::js_string( $_ ) }
				 $repo->get_conf("arkivum","file_share_url") ),
			(map { EPrints::Utils::js_string( $_ ) }
				 $repo->current_user->value("username") ),
		)) );
	}
	my $libs = $arkivum->{libs}->{$arkivum->{lib_source}};
	for my $lib(@{$libs}){
		if($lib =~ /\.js$/){
			$head->appendChild( $repo->make_javascript( undef,
				src => "$lib"
			) );
		}else{
			$head->appendChild( $repo->xml->create_element( "link",
				rel => "stylesheet",
				href => $lib,
			) );
		}
		$head->appendChild( $repo->xml->create_text_node( "\n    " ) );
	}
=comment
        $head->appendChild( $repo->make_javascript( undef,
                src => "https://code.jquery.com/jquery-2.2.3.min.js"
        ) );
	$head->appendChild( $repo->xml->create_text_node( "\n    " ) );
        $head->appendChild( $repo->make_javascript( undef,
                src => "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"
        ) );


	$head->appendChild( $repo->xml->create_text_node( "\n    " ) );
	$head->appendChild( $repo->xml->create_element( "link",
			rel => "stylesheet",
			href => "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css",
		) );
	$head->appendChild( $repo->xml->create_text_node( "\n    " ) );
=cut
	# Reset the font-size to 100% after bootstrap
	$head->appendChild( my $style = $repo->xml->create_element( "style") );
	$style->appendChild( $repo->make_text( "html { font-size: 100%; }" ) );

	$head->appendChild( $repo->xml->create_text_node( "\n    " ) );

	if( defined $pins->{'utf-8.head'} )
	{
#		$pins->{'utf-8.head'} .= $xhtml->to_xhtml( $head );
		$pins->{'utf-8.head'} =  $xhtml->to_xhtml( $head ).$pins->{'utf-8.head'};

	}
	if( defined $pins->{head} )
	{
		$head->appendChild( $pins->{head} );
		$pins->{head} = $head;
	}
	else
	{
		$pins->{head} = $head;
	}
	return;

}, priority => 2000);

$c->add_dataset_field( "document", {name=>"astorid", type=>"id"});

=comment
#undecided about need for this... we can update status direct from api surely?
$c->add_dataset_field( "document", {
		name => "archive_status",
		type => 'set',
		options => [ qw(
			archive_requested
			archive_approved
			archived
			archive_failed
			delete_requested
			delete_approved
			deleted
			delete_failed
			restore_requested
			restore_approved
			restored
			restore_failed
		) ],
	}, 
);
=cut
