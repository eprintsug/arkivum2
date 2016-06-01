=head1 NAME

EPrints::Plugin::InputForm::Component::ArkivumDocuments

=cut

package EPrints::Plugin::InputForm::Component::ArkivumDocuments;

use EPrints::Plugin::InputForm::Component;
@ISA = ( "EPrints::Plugin::InputForm::Component::Documents" );

use strict;

sub render_content
{
	my( $self, $surround ) = @_;
	
	my $session = $self->{session};
	my $eprint = $self->{workflow}->{item};
	# cache documents
	$eprint->set_value( "documents", $eprint->value( "documents" ) );

	my $f = $session->make_doc_fragment;
	
	$f->appendChild( $self->{session}->make_javascript(
		"Event.observe(window, 'load', function() { new Component_Documents('".$self->{prefix}."') });"
	) );

	my @docs = $eprint->get_all_documents;

	my %unroll = map { $_ => 1 } $session->param( $self->{prefix}."_view" );

	# this overrides the prefix-dependent view. It's used when
	# we're coming in from outside the form and is, to be honest,
	# a dirty little hack.
	if( defined(my $docid = $session->param( "docid" ) ) )
	{
		$unroll{$docid} = 1;
	}

	my $panel = $session->make_element( "div",
		id=>$self->{prefix}."_panels",
	);
	$f->appendChild( $panel );

	foreach my $doc ( @docs )
	{
		my $hide = @docs > 1 && !$unroll{$doc->id};
		$panel->appendChild( $self->_render_doc_div( $doc, $hide )) if(!$doc->is_set("astorid"));
	}

	$f->appendChild( $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:Arkivum" ) );

	return $f;
}

