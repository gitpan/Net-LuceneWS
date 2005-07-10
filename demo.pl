#! /usr/bin/perl -w
use strict;
use lib 'lib'; # no longer necessary when Net::LuceneWS is installed
use Net::LuceneWS;

#
# Create the object.
#
my $ws = new Net::LuceneWS(
	host	=> 'localhost',
	port	=> 8080,
	context	=> 'lucene',
	index	=> 'test',
	debug	=> 1,
);


#
# Add some documents to the default index.
#
# Note: If these are the first documents added we have to pass the analyzer!
#
my @docs = (
	{ id => '1', artist => 'U2', album => 'October', track => 'Gloria' },
	{ id => '2', artist => 'R.E.M.', album => 'Up', track => 'Hope' },
);

$ws->AddDocuments(\@docs, analyzer => 'WithStopAnalyzer');


#
# Optimize the index to speed up queries.
#
#$ws->Optimize();


#
# Query the web service.
#
my $ret = $ws->Search('october', max_hits => 5, default_field => 'album')
	or die "Error: " . $ws->GetError(), "\n";

printf "Hits: %d/%d\n", $ret->GetNumHitsReturned(), $ret->GetNumHitsTotal();

foreach my $hit ( $ret->GetHits() ) {
	printf "%3d %s - %s\n", $hit->GetScore(), $hit->GetField('artist'),
				$hit->GetField('track');
}


my %args = ( );

my %update = (
	default_field => 'album',
	query => 'October',
	document => { artist => 'U2', album => 'October', track => 'Gloria2' },
);

$ws->UpdateDocuments([\%update], %args);


my %delete = (
	default_field => 'album',
	query => 'October',
);


$ws->DeleteDocuments([\%delete], %args);
