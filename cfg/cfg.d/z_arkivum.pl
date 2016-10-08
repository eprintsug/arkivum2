
my $arkivum = {};
$c->{arkivum} = $arkivum;

$arkivum->{archive_api} = "ADDRESS_OF_ASTOR_DEVICE"; # eg https://astor.institution.ac.uk:8443";
$arkivum->{file_share_host} = "ADDRESS_OF_OWNCLOUD_SERVICE"; #eg owncloud.institution.ac.uk/owncloud
$arkivum->{file_share_user} = "ARKIVUM_USER";
$arkivum->{file_share_password} = "ARKIVUM_PASSWORD";

$arkivum->{default_document_security} = "public";
$arkivum->{default_document_license} = "cc_by_nd";
$arkivum->{default_document_format} = "text"; #TODO add to updatable set of doc_md

#checksumAlgorithm (astor default md5)
$arkivum->{checksumAlgorithm} = "md5";

#What Owncloud calls it
#This is the folder name of the external storage location (type==local) configured in on the owncloud external storage app
$arkivum->{ext_storage_name} = "ARKIVUM_DIR_THAT_OWNCLOUD_CAN_SEE"; 
#What arkivum calls it
#This is the path from the astor root to the "configurtion" set in the owncloud external storage app
$arkivum->{file_share_folder} = "ARKIVUM_DIR_OR_DATAPOOL";



