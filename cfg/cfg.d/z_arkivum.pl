
my $arkivum = {};
$c->{arkivum} = $arkivum;

$arkivum->{archive_api} = "https://172.18.10.121:8443";
$arkivum->{file_share_api} = "https://82.144.240.135";

$c->{plugins}->{"Screen::EPrint::UploadMethod::Arkivum"}->{params}->{disable} = 0;

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
EOJ
			(map { EPrints::Utils::js_string( $_ ) }
				 $eprintid ),
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

