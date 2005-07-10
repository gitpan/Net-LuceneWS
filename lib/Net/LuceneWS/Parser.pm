package Net::LuceneWS::Parser;

use strict;
use warnings;
use XML::Parser;
use Net::LuceneWS::SearchResults;
use Net::LuceneWS::Hit;


use constant RESULTS_KEY => 'LuceneWS_SearchResults';
use constant BUFFER_KEY => 'LuceneWS_Buffer';
use constant ATTRIBUTES_KEY => 'LuceneWS_Attributes';
use constant ERROR_KEY => 'LuceneWS_Error';


sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;
	my $self = { };

	# Set up the XML parser we are going to use.
	#
	my $parser = new XML::Parser(Handlers => {
		Start	=> \&_handle_start,
		End	=> \&_handle_end,
		Char	=> \&_handle_char,
		Final	=> \&_handle_final,
	});

	$self->{parser} = $parser;

	return bless($self, $class);
}


sub Parse {
	my ($self, $xmlstr) = @_;
	my $parser = $self->{parser};

	return $parser->parse($xmlstr);
}


sub _handle_start
{
	my ($parser, $element, %attrs) = @_;

	my $path = '/' . join('/', $parser->context(), $element);

	if ( $path eq '/searchresults' ) {
		$parser->{RESULTS_KEY} = new Net::LuceneWS::SearchResults();
	}
	elsif ( $path eq '/searchresults/searchresult/document' ) {
		my $results = $parser->{RESULTS_KEY};
		$results->AddHit(new Net::LuceneWS::Hit());
	}

	$parser->{BUFFER_KEY} = '';
	$parser->{ATTRIBUTES_KEY} = \%attrs;
}


sub _handle_char
{
	my ($parser, $content) = @_;

	$parser->{BUFFER_KEY} .= $content;
}


sub _handle_end
{
	my ($parser, $element) = @_;
	my $results = $parser->{RESULTS_KEY};
	my $buffer = $parser->{BUFFER_KEY};
	my $attrs = $parser->{ATTRIBUTES_KEY};

	my $path = '/' . join('/', $parser->context(), $element);

	if ( $path eq '/searchresults/index' ) {
		$results->SetIndexName($buffer);
	}
	elsif ( $path eq '/searchresults/hits' ) {
		$results->SetNumHitsReturned($buffer);
		$results->SetNumHitsTotal($attrs->{total});
	}
	elsif ( $path eq '/searchresults/searchresult/document/score' ) {
		$results->GetLastHit()->SetScore($buffer);
	}
	elsif ( $path eq '/searchresults/searchresult/document/field' ) {
		$results->GetLastHit()->SetField($attrs->{name}, $buffer);
	}
	elsif ( $path eq '/error' ) {
		$parser->{ERROR_KEY} = $buffer;
	}
}


sub _handle_final {
	my ($parser, $element) = @_;
	my $results = $parser->{RESULTS_KEY};
	my $error = $parser->{ERROR_KEY};

	delete $parser->{RESULTS_KEY};
	delete $parser->{BUFFER_KEY};
	delete $parser->{ATTRIBUTES_KEY};
	delete $parser->{ERROR_KEY};

	return ($results, $error);
}

1;
