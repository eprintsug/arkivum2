package EPrints::Plugin::ArkivumDoc;
@ISA = ( 'EPrints::Plugin' );
#now for the clever bit
package EPrints::DataObj::Document;

sub validate
{
	my( $self, $for_archive ) = @_;

	return [] if $self->get_parent->skip_validation;

	my @problems;

	unless( EPrints::Utils::is_set( $self->get_type() ) )
	{
		# No type specified
		my $fieldname = $self->{session}->make_element( "span", class=>"ep_problem_field:documents" );
		push @problems, $self->{session}->html_phrase( 
					"lib/document:no_type",
					fieldname=>$fieldname );
	}
	
	# System default checks:
	# Make sure there's at least one file!!
	my %files = $self->files();

	if( scalar keys %files ==0 && $self->is_set("astorid"))
	{
		my $fieldname = $self->{session}->make_element( "span", class=>"ep_problem_field:documents" );
#		push @problems, $self->{session}->html_phrase( "lib/document:no_files", fieldname=>$fieldname );
	}
	elsif( !$self->is_set( "main" ) )
	{
		# No file selected as main!
		my $fieldname = $self->{session}->make_element( "span", class=>"ep_problem_field:documents" );
		push @problems, $self->{session}->html_phrase( "lib/document:no_first", fieldname=>$fieldname );
	}
		
	# Site-specific checks
	push @problems, @{ $self->SUPER::validate( $for_archive ) };

	return( \@problems );
}

1;
