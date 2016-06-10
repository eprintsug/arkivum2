=head1 NAME

EPrints::Plugin::Export::ArkivumFiles

=cut

package EPrints::Plugin::Export::ArkivumFiles;

use EPrints::Plugin::Export::TextFile;
use JSON;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

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
	my $files = {title => $self->phrase("root_folder").EPrints::XML::to_string($eprint->render_citation("screen")), key => "ROOT", folder => "true", children => [] };
	#This will come from arkivum api...
#	my $file_info = $self->_astor_getFileInfo();
	my $json = $self->_astor_getFolder($eprint->get_id);
#	print STDERR $json."\n";
	if($json =~ /^404/){
		$self->_log("Could not create folder") unless $self->_astor_createFolder($eprint->get_id);
		$json = $self->_astor_getFolder($eprint->get_id);
	}

	#merge/sync astor and eprints file metadata... possibly we will do this elsewhere so it is no attempted at every export...  
	#but maybe doing it here is the best way to ensure a reliable picture
	my $ft_files = [];
	for my $f (@{$json->{files}}){
	#	print STDERR $f->{type}." **\n";

		if($f->{type} =~ /^Folder$/){
			push @$ft_files, {title=>$f->{name}, key=>$f->{id}, folder=>"true", children=> [] };
		}else{
			my $file_key = Digest::MD5::md5_hex($f->{path}); #key is default path as id not always available
			$file_key = $f->{id} if(defined $f->{id});
			push @$ft_files, {title=>$f->{name}, key=>$file_key, astor_md => $f, doc_md => 0 };
			#make file metadata from astor easily referencable by astorid
		}
	}
	#loop through existing documents and merge metadata from the astor and eprints
	for my $doc($eprint->get_all_documents){
		#NEED AN ALTERNATIVE KEY FOR WHEN THERE IS NO ASTORID (PROBABLY PATH IS BEST WE'VE GOT)
		if($doc->is_set("astorid")){
			#We have a file we need to merge with arkivum data
			#encode as json and
#			print STDERR "ASTORID: ".$doc->value("astorid")."\n";
			my ($ft_file) = grep { $_->{key} eq $doc->value("astorid") } @$ft_files;
#			print STDERR "FT_FILE - name : ".$ft_file->{title}."\n";
#			print STDERR "FT_FILE - doc_md : ".$ft_file->{doc_md}."\n";
			if(defined $ft_file){
				#merge existing sets of metadata 
				# (may need to process a subset of doc_md rather than shoce in the lot as below)
#				print STDERR "Merging $ft_file and ".$doc->{data}."\n";
				$ft_file->{doc_md} = $doc->{data};
			}else{
				#remove the eprints doc metadata as file no longer on astor...
				$doc->remove;
			}
		}
	}
	my $ds = $self->{repository}->get_dataset( "document" );
	#get all ft_files that have no doc_md defined (ie no eprint docuemnt object exists yet)
	my @files_with_no_md = grep { $_->{folder} ne "true" && $_->{doc_md} == 0 } @$ft_files;
	for my $ft_file (@files_with_no_md){
		print STDERR "FILENAME: ".$ft_file->{title}."\n";
#		print STDERR "MD5: ".$ft_file->{astor_md}->{MD5checksum}."\n"; #almost certain not to have this at this stage

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

sub _astor_getFileInfo
{
      my( $self, $filename) = @_;

      my $repo = $self->{repository};

      my $file_share_folder = $repo->get_conf("arkivum", "file_share_folder");

      my $api_url = "/api/2/files/fileInfo/" . $file_share_folder . $filename;
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
      my $req = HTTP::Request::Common::POST $server_url,
                $data;

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

