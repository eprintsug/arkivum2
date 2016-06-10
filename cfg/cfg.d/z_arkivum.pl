
my $arkivum = {};
$c->{arkivum} = $arkivum;

$arkivum->{archive_api} = "https://82.144.240.138:8443";
$arkivum->{file_share_host} = "82.144.240.135/owncloud";
$arkivum->{file_share_user} = "astoradmin";
$arkivum->{file_share_password} = "arkivum";


$arkivum->{file_share_api} = "https://".$arkivum->{file_share_user}.":".$arkivum->{file_share_password}."\@".$arkivum->{file_share_host}."/ocs/v1.php/apps/files_sharing/api/v1";
$arkivum->{file_share_url} = "https://".$arkivum->{file_share_host}."/index.php";
$arkivum->{file_share_webdav} = "https://".$arkivum->{file_share_user}.":".$arkivum->{file_share_password}."\@".$arkivum->{file_share_host}."/remote.php/webdav";
$arkivum->{file_share_symlink} = "https://".$arkivum->{file_share_user}.":".$arkivum->{file_share_password}."\@".$arkivum->{file_share_host}."/index.php/apps/symlinks/api/0.1/symlinks";



$arkivum->{oc_users_api} = "https://".$arkivum->{file_share_user}.":".$arkivum->{file_share_password}."\@".$arkivum->{file_share_host}."/ocs/v1.php/cloud";

$arkivum->{default_document_security} = "public";
$arkivum->{default_document_license} = "cc_by_nd";
$arkivum->{default_document_format} = "text"; #TODO add to updatable set of doc_md

#checksumAlgorithm (astor default md5)
$arkivum->{checksumAlgorithm} = "md5";

#What Owncloud calls it
#This is the folder name of the external storage location (type==local) configured in on the owncloud external storage app
$arkivum->{ext_storage_name} = "arkivum"; 
#What arkivum calls it
#This is the path from the astor root to the "configurtion" set in the owncloud external storage app
$arkivum->{file_share_folder} = "owncloud_datapool";

#NOT USED #TODO remove this and pm
$c->{plugins}->{"Screen::EPrint::UploadMethod::Arkivum"}->{params}->{disable} = 1;

$c->{plugins}->{"Export::ArkivumFiles"}->{params}->{disable} = 0;

$c->{plugin_alias_map}->{"InputForm::Component::Documents"} = "InputForm::Component::ArkivumDocuments";
$c->{plugin_alias_map}->{"InputForm::Component::ArkivumDocuments"} = undef;

$arkivum->{libs} = {
		    cdn => [
			"https://code.jquery.com/jquery-2.2.3.min.js",
			"https://cdnjs.cloudflare.com/ajax/libs/js-cookie/2.0.1/js.cookie.min.js",
			"https://code.jquery.com/ui/1.10.4/jquery-ui.min.js",
			"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js",
			"https://cdnjs.cloudflare.com/ajax/libs/jquery.fancytree/2.17.0/jquery.fancytree-all.min.js",
			"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css",
			"https://cdnjs.cloudflare.com/ajax/libs/jquery.fancytree/2.17.0/skin-bootstrap/ui.fancytree.min.css",
			"https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.13.0/moment.js",
			"https://cdnjs.cloudflare.com/ajax/libs/bootstrap-datepicker/1.6.1/js/bootstrap-datepicker.min.js",
			"https://cdnjs.cloudflare.com/ajax/libs/bootstrap-datepicker/1.6.1/css/bootstrap-datepicker.min.css",
			#NB this is not a CDN!
#			"http://wwwendt.de/tech/fancytree/src/jquery.fancytree.persist.js",
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
	my $eprintid="NO_EPRINTID";
	my $username="NO_USERNAME";
	unless($repo->{offline}){
		if(defined $repo->param("eprintid")){
			$eprintid = $repo->param("eprintid");
		}elsif($repo->current_url =~ /\/(\d+)$/){
			$eprintid = $1;
		}
		$username = $repo->current_user->value("username") if($repo->current_user);
	}
#	}else{
#		#there must be a way to access eprintid when generating abstract here....
#		$eprintid = "undefined"; #for now we'll do this and get from url with js
#		$username = "undefined"; #for now we'll do this and get from url with js
#
#	}
#	if(defined $eprintid){	
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
				 $username ),
		)) );
#	}
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
