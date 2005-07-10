package Net::LuceneWS::SearchResults;

use strict;
use warnings;


sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;
	my $self = {
		hits => [ ],
	};

	return bless($self, $class);
}

sub GetIndexName {
	return $_[0]->{index_name};
}

sub SetIndexName {
	$_[0]->{index_name} = $_[1];
}

sub GetNumHitsReturned {
	return $_[0]->{num_hits_returned};
}

sub SetNumHitsReturned {
	$_[0]->{num_hits_returned} = $_[1];
}

sub GetNumHitsTotal {
	return $_[0]->{num_hits_total};
}

sub SetNumHitsTotal {
	$_[0]->{num_hits_total} = $_[1];
}

sub GetHits {
	return @{ $_[0]->{hits} };
}

sub SetHits {
	$_[0]->{hits} = [ $_[1] ];
}

sub AddHit {
	push @{ $_[0]->{hits} }, $_[1];
}

sub GetLastHit {
	my $self = shift;
	my $hits = $self->{hits};

	return @{$hits}[ scalar(@$hits)-1 ];
}

1;
