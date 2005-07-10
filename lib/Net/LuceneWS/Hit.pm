package Net::LuceneWS::Hit;

use strict;
use warnings;


sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;
	my $self = {
		fields => { },
	};

	return bless($self, $class);
}

sub GetScore {
	return $_[0]->{score};
}

sub SetScore {
	$_[0]->{score} = $_[1];
}

sub GetField {
	my ($self, $name) = @_;
	return $self->{fields}->{$name};
}

sub SetField {
	my ($self, $name, $value) = @_;
	$self->{fields}->{$name} = $value;
}

sub GetFields {
	return %{ $_[0]->{fields} };
}

sub SetFields {
	my ($self, %fields);
	$self->{fields} = \%fields
}

1;
