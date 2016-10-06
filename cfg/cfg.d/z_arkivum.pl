
my $arkivum = {};
$c->{arkivum} = $arkivum;

$arkivum->{archive_api} = "https://82.144.240.138:8443";
$arkivum->{file_share_host} = "82.144.240.135/owncloud";
$arkivum->{file_share_user} = "astoradmin";
$arkivum->{file_share_password} = "arkivum";

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



