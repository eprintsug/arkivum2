=head1 NAME

EPrints::Plugin::Export::ArkivumFiles

=cut

package EPrints::Plugin::Export::ArkivumFiles;

use EPrints::Plugin::Export::TextFile;
use JSON;

use Data::Find qw( diter );
#this module makes spurious warnings 9comment this out if it starts to go screwy and you need to know why
$SIG{'__WARN__'} = sub { warn $_[0] unless (caller eq "Data::Find"); }; 
		
@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

#a string to use as a value for null doc_md (we can search for this string with Data::Find)
use constant NO_MD => "9rv1X5U96nCOUresFeDPJHH9rUs5Sk9A";

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "ArkivumFiles";
	$self->{accept} = [ 'dataobj/*' ];
	$self->{visible} = "all";
	$self->{suffix} = ".js";
	$self->{mimetype} = "application/json; charset=utf-8";
	$self->{arguments}->{json} = undef;
	$self->{arguments}->{jsonp} = undef;
	$self->{arguments}->{callback} = undef;
	$self->{arguments}->{hide_volatile} = 1;

	return $self;
}


sub _header
{
	my( $self, %opts ) = @_;

	my $jsonp = $opts{json} || $opts{jsonp} || $opts{callback};
	if( EPrints::Utils::is_set( $jsonp ) )
	{
		$jsonp =~ s/[^=A-Za-z0-9_]//g;
		return "$jsonp(";
	}

	return "";
}

sub _footer
{
	my( $self, %opts ) = @_;

	my $jsonp = $opts{json} || $opts{jsonp} || $opts{callback};
	if( EPrints::Utils::is_set( $jsonp ) )
	{
		return ");\n";
	}
	return "";
}
sub output_dataobj
{
	my( $self, $dataobj, %opts ) = @_;

	return $self->_header( %opts ).$self->_arkivum_to_json( $dataobj, %opts ).$self->_footer( %opts );
}

sub _arkivum_to_json
{
	my( $self, $eprint, %opts ) = @_;

	my $repo = $self->{repository};
	#Request to Arkivum API here when possible
	#here we have eprint and arkivum data and we will merge them into a fancytree ready json structure
	my $files = {title => $self->phrase("root_folder").EPrints::XML::to_string($eprint->render_citation("screen")), key => "ROOT", folder => "true", expanded => "true", children => [] };
	#This will come from arkivum api...
#	my $file_info = $self->_astor_getFileInfo();
	my $json = $self->_astor_getFolder($eprint->get_id);
	
	if($json =~ /^404/){
		$self->_log("Could not create folder") unless $self->_astor_createFolder($eprint->get_id);
		$json = $self->_astor_getFolder($eprint->get_id);
	}
	
	my $ft_files = $self->make_ft_files([], $json->{files}, $eprint->get_id, "");

	#loop through existing documents and merge metadata from the astor and eprints
	for my $doc($eprint->get_all_documents){
		
		if($doc->is_set("astorid")){
			#We have a file we need to merge with arkivum data
			#encode as json and
			my $ft_file = $self->_find_file_by_astorid($ft_files, $doc->value("astorid"));

#			print STDERR "FT_FILE - name : ".$ft_file->{title}."\n";
#			print STDERR "FT_FILE - doc_md : ".$ft_file->{doc_md}."\n";
			if(defined $ft_file){
				#merge existing sets of metadata 
				# (may need to process a subset of doc_md rather than shove in the lot as below)
				$ft_file->{doc_md} = $doc->{data};
			}else{
				#remove the eprints doc metadata as file no longer on astor...
				$doc->remove;
			}
		}
	}
	my $ds = $self->{repository}->get_dataset( "document" );
	
	#get all ft_files that have no doc_md defined (ie no eprint docuemnt object exists yet)
	my $files_with_no_md = $self->_filter_files_by_md($ft_files);

	for my $ft_file (@$files_with_no_md){

		#print STDERR "##### FILENAME: ".$ft_file->{title}." #######\n";
		#print STDERR "MD5: ".$ft_file->{astor_md}->{MD5checksum}."\n"; #almost certain not to have this at this stage

		my $epdata = {eprintid => $eprint->get_id, 
				astorid=> $ft_file->{key}, 
				security=> $repo->get_conf("arkivum", "default_document_security"),
				license=> $repo->get_conf("arkivum", "default_document_license"),
				format=> $repo->get_conf("arkivum", "default_document_format"),
				main=> $ft_file->{title},
			 };
		$epdata->{eprintid} = $eprint->get_id;
		$ft_file->{doc_md} = $epdata;
		my $doc = EPrints::DataObj::Document->create_from_data( $self->{session}, $epdata, $ds );
		$ft_file->{doc_md} = $doc->{data};
	}
	
	$files->{children} = $ft_files;
	return encode_json $files;
}

## Construct an abitrary depth structure that is compatible with the jquer filetree plugin
# files_arr - the files part of the arkivum api call
# parent - the parent directory
# path - the current path (as a string) to this point of the structure
#

sub make_ft_files {
	
	my ($self, $ft_files, $files_arr, $parent, $path) = @_;
	
	for my $f (@{$files_arr}){
		
		if($f->{type} =~ /^Folder$/){
			#we have a folder, so we re-request the contents from arkivum api
			my $sub_json = $self->_astor_getFolder($parent."/".$f->{name});
			#get the next index
			my $i = scalar @{eval "\$ft_files$path"};
			#push on the folder (using the $path string to put it in the correct level of the structure)
			push @{eval "\$ft_files$path"}, {title=>$f->{name}, key=>$f->{id}, folder=>"true", children=> [] };
			#re-call this sub with the next level of files
			$self->make_ft_files($ft_files, $sub_json->{files}, $parent."/".$f->{name},$path."->[$i]->{children}");
		}else{
			#make an id from path and name
			my $file_key = Digest::MD5::md5_hex($f->{path}."/".$f->{name});
			#we have a file, lets add it (using the $path string to put it in the correct level)
			push @{eval "\$ft_files$path"}, {title=>$f->{name}, key=>$file_key, astor_md => $f, doc_md => NO_MD };
		}
	}
	return $ft_files;
}

#This will return the ft_file from the abitraily deep ft_files object
sub _find_file_by_astorid {
	my ($self, $ft_files, $astorid) = @_;
	
	my $iter = diter $ft_files, $astorid; 
  	#we only xpect one... retun on first match
	while ( my ( $path, $obj ) = $iter->() ) {
		#make path work on refs	
		$path =~ s/\[/->[/g;
		$path =~ s/\{/->{/g;
		#and knock the last bit off to get...
		$path =~ s/->\{key\}$//;
		#the ft_file
		return eval "\$ft_files$path";
	}
}

#This will return the ft_files that have no md set... from the abitraily deep ft_files object
sub _filter_files_by_md {
	my ($self,  $ft_files) = @_;

	my $filtered = [];	
	my $iter = diter $ft_files, NO_MD; 
	while ( my ( $path, $obj ) = $iter->() ) {

		#make path work on refs	
		$path =~ s/\[/->[/g;
		$path =~ s/\{/->{/g;
		#and knock the last bit off to get...
		$path =~ s/->\{doc_md\}$//;

		#the ft_file
		push @$filtered, eval "\$ft_files$path";
  	}

	return $filtered;
}

sub _astor_getFileInfo
{
      my( $self, $filename) = @_;

      my $repo = $self->{repository};

      my $file_share_folder = $repo->get_conf("arkivum", "file_share_folder");

      my $api_url = "/api/2/files/fileInfo/" . $file_share_folder . $filename;
      print STDERR "API_URL: $api_url\n";
      my $response = $self->_astor_getRequest($api_url);

      if ( not defined $response )
      {
            $self->_log("_astor_getFileInfo: Invalid response returned...");
            return;
      }

      if ($response->is_error)
      {
            $self->_log("_astor_getFileInfo: Invalid response returned: ".$response->status_line);
            return $response->status_line;
      }

      # Get the content which should be a json string
      my $json = decode_json($response->content);
      if ( not defined $json)
      {
            $self->_log("_astor_getFileInfo: Invalid response returned...");
            return;
      }

      return $json;
}

sub _astor_getFolder
{
      my( $self, $foldername) = @_;

      my $repo = $self->{repository};

      my $file_share_folder = $repo->get_conf("arkivum", "file_share_folder");

      my $api_url = "/files/" . $file_share_folder ."/". $foldername;
      my $response = $self->_astor_getRequest($api_url);

      if ( not defined $response )
      {
            $self->_log("_astor_getFileInfo: Invalid response returned...");
            return;
      }

      if ($response->is_error)
      {
            $self->_log("_astor_getFileInfo: Invalid response returned: ".$response->status_line);
            return $response->status_line;
      }

      # Get the content which should be a json string
      my $json = decode_json($response->content);
      if ( not defined $json)
      {
            $self->_log("_astor_getFileInfo: Invalid response returned...");
            return;
      }

      return $json;
}

sub _astor_createFolder
{
      my( $self, $foldername) = @_;

      my $repo = $self->{repository};

      my $file_share_folder = $repo->get_conf("arkivum", "file_share_folder");

      my $api_url = "/files/";
 #     my $response = $self->_astor_postRequest($api_url,{action=>"create-folder", basePath=>"/".$file_share_folder."/", folderName=>$foldername});
      return $self->_astor_postRequest($api_url,{action=>"create-folder", basePath=>"/".$file_share_folder."/", folderName=>$foldername});

=comment
      if ( not defined $response )
      {
            $self->_log("_astor_createFolder: Invalid response returned...");
            return;
      }

      if ($response->is_error)
      {
            $self->_log("_astor_createFolder: Invalid response returned: ".$response->status_line);
#		print STDERR $response->content."#### \n";
            return $response->status_line;
      }

      # Get the content which should be a json string
      my $json = decode_json($response->content);
      if ( not defined $json)
      {
            $self->_log("_astor_createFolder: Invalid response returned...");
            return;
      }

      return $json;
=cut
}

sub _astor_releaseForIngest
{
      my( $self, $path) = @_;

      my $repo = $self->{repository};

      my $file_share_folder = $self->{repository}->get_conf("arkivum", "file_share_folder");

      my $api_url = "/files/release/".$path;
      
      my $ark_server = $self->{repository}->get_conf("arkivum", "archive_api");

      my $server_url = $ark_server . $api_url;
      print STDERR "POST: ".$server_url."\n";
	#not ideal but...
#	my $curl_cmd = "curl -k -X POST $server_url ";
#	while(my($k,$v) = each %{$data}){
#		$curl_cmd .=" -d ".$k."=".$v;
#	}
#	print STDERR $curl_cmd."\n";
#	system($curl_cmd)==0 or return 0;
#	return 1;
     
}




sub _astor_getRequest
{
	my( $self, $url ) = @_;

	my $ark_server = $self->{repository}->get_conf("arkivum", "archive_api");

	my $server_url = $ark_server . $url;
	my $ua       = LWP::UserAgent->new();
#	print STDERR "GET: ".$server_url."\n";
	my $response = $ua->get( $server_url );

	return $response;
}

sub _astor_postRequest
{
      my( $self, $url, $data ) = @_;

      my $ark_server = $self->{repository}->get_conf("arkivum", "archive_api");

      my $server_url = $ark_server . $url;
      print STDERR "POST: ".$server_url."\n";
	#not ideal but...
	my $curl_cmd = "curl -k -X POST $server_url ";
	while(my($k,$v) = each %{$data}){
		$curl_cmd .=" -d ".$k."=".$v;
	}
	print STDERR $curl_cmd."\n";
	system($curl_cmd)==0 or return 0;
	return 1;
     
	#...need libwww6.0
      my $ua = LWP::UserAgent->new();
      $ua->default_header( "Content-Type" =>  "application/x-www-form-urlencoded");
	#to do this...?
     # $ua->ssl_opts( verify_hostname => 0 ,SSL_verify_mode => 0x00);
      my $req = HTTP::Request::Common::POST($server_url,$data);

      my $response = $ua->request($req);
	print STDERR $response->status_line."**\n";
      return $response;
}

sub _log
{
	my ( $self, $msg) = @_;

	$self->{repository}->log($msg);
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

