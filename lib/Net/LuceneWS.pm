package Net::LuceneWS;

use 5.006;
use strict;
use warnings;
use Carp;
use Net::LuceneWS::Parser;
use LWP;
use URI::Escape;

our $VERSION = '0.01';


use constant REQUIRED_ARGS => [ qw(host port context index) ];

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = {
		args => \%args,
	};

	return bless($self, $class);
}


sub GetError {
	return $_[0]->{error};
}

sub SetError {
	$_[0]->{error} = $_[1];
}


sub Search {
	my ($self, $query, %args) = @_;

	croak "Search(): empty or undefined query parameter not allowed"
		unless defined $query and $query =~ m/\S/;

	%args = _merge_args(\%args, $self->{args});
	_check_args(\%args, @{ &REQUIRED_ARGS }, 'max_hits', 'default_field');

	#
	# Contstruct URI:
	# 	http://host:port/context/index/searchresult?params
	#
	my $url = _make_service_url('searchresult', %args)
		. "?maxhits=$args{max_hits}"
		. '&defaultfield=' . uri_escape($args{default_field})
		. '&query=' . uri_escape($query);

	my $ua = new LWP::UserAgent();
	my $request = new HTTP::Request(GET => $url);

	my $response = $ua->request($request);

	unless ( $response->is_success() ) {
		$self->SetError($response->status_line());
		return undef;
	}

	# Parse the returned XML document and convert it to objects.
	#
	my $parser = new Net::LuceneWS::Parser();
	my ($result, $error) = $parser->Parse($response->content());

	$self->SetError($error) if defined $error;
	
	print STDERR $response->content(), "\n", if $args{debug};

	return $result;
}


sub AddDocuments {
	my ($self, $documents, %args) = @_;

	%args = _merge_args(\%args, $self->{args});
	_check_args(\%args, @{ &REQUIRED_ARGS });

	#
	# Create the input XML
	#
	my $content = '<?xml version="1.0" encoding="UTF-8"?>' . "\n";

	if ( $args{analyzer} ) {
		$content .= '<documents analyzer="'
				. _xml_escape($args{analyzer}, 1) . "\">\n";
	}
	else {
		$content .= "<documents>\n";
	}

	$content .= _make_index_documents(@$documents);
	$content .= "</documents>\n";

	print STDERR $content, "\n" if $args{debug};

	#
	# Send the XML data
	#
	my $url = _make_service_url('documentindexer', %args);
	my $response = _post_data($url, $content);

	# Doesn't work. lucene-ws doesn't use HTTP error codes.
	#
	unless ( $response->is_success() ) {
		$self->SetError('TODO');
		croak 'Trouble';
	}

	print STDERR $response->content(), "\n" if $args{debug};
}


sub UpdateDocuments {
	my ($self, $update_cmds, %args) = @_;

	%args = _merge_args(\%args, $self->{args});
	_check_args(\%args, @{ &REQUIRED_ARGS });

	#
	# Create the input XML
	#
	my $content = '<?xml version="1.0" encoding="UTF-8"?>' . "\n"
			. "<documents>\n";

	$content .= _make_update_documents(@$update_cmds);

	$content .= "</documents>\n";

	print STDERR $content if $args{debug};

	#
	# Send the XML data
	#
	my $url = _make_service_url('documentupdater', %args);
	my $response = _post_data($url, $content);

	# Doesn't work. lucene-ws doesn't use HTTP error codes.
	#
	unless ( $response->is_success() ) {
		$self->SetError('TODO');
		croak 'Trouble';
	}

	print STDERR $response->content(), "\n" if $args{debug};
}


sub DeleteDocuments {
	my ($self, $delete_cmds, %args) = @_;

	%args = _merge_args(\%args, $self->{args});
	_check_args(\%args, @{ &REQUIRED_ARGS });

	#
	# Create the input XML
	#
	my $content = '<?xml version="1.0" encoding="UTF-8"?>' . "\n"
			. "<documents>\n";

	$content .= _make_update_documents(@$delete_cmds);

	$content .= "</documents>\n";

	print STDERR $content if $args{debug};

	#
	# Send the XML data
	#
	my $url = _make_service_url('documentremover', %args);
	my $response = _post_data($url, $content);

	# Doesn't work. lucene-ws doesn't use HTTP error codes.
	#
	unless ( $response->is_success() ) {
		$self->SetError('TODO');
		croak 'Trouble';
	}

	print STDERR $response->content(), "\n" if $args{debug};
}


sub Optimize {
	my ($self, %args) = @_;

	%args = _merge_args(\%args, $self->{args});
	_check_args(\%args, @{ &REQUIRED_ARGS });

	my $url = _make_service_url('optimizer', %args);
	my $response = _post_data($url, '');

	print STDERR $response->content(), "\n" if $args{debug};

	# TODO: no error handling yet.
	return 1;
}


#
# Utils
#

# Merge two hashes. $args take precedence.
#
sub _merge_args($$) {
	my ($args, $defaults) = @_;

	my %result = %$defaults;

	while ( my ($key, $val) = each %$args ) {
		$result{$key} = $val;
	}

	return %result;
}

sub _check_args {
	my ($args, @required) = @_;

	foreach my $key ( @required ) {
		croak "Argument '$key' missing"
			unless defined $args->{$key} and $args->{$key} =~ m/\S/;
	}
}


sub _xml_escape($;$) {
	my $str = shift;
	my $is_attr = shift; # if true, escape ' and ", too

	study $str;
	$str =~ s/\&/\&amp/g;
	$str =~ s/</\&lt/g;
	$str =~ s/>/\&gt/g;

	if ( $is_attr ) {
		$str =~ s/\"/\&quot;/g;
		$str =~ s/\'/\&apos;/g;
	}

	return $str;
}


sub _make_index_documents {
	my @documents = @_;
	my $content = '';

	foreach my $doc ( @documents ) {
		croak 'Document is no hash ref' unless ref($doc) eq 'HASH';

		$content .= "  <document>\n";

		while ( my ($key, $value) = each %$doc ) {
			$content .=  '    <field name="'
				. _xml_escape($key, 1) . '">'
				. _xml_escape($value)
				. "</field>\n";
		}

		$content .= "  </document>\n";
	}
	
	return $content;
}


sub _make_update_documents {
	my @update_cmds = @_;
	my $content = '';

	foreach my $cmd ( @update_cmds ) {
		croak 'Document is no hash ref' unless ref($cmd) eq 'HASH';

		my $default_field = $cmd->{default_field};
		my $query = $cmd->{query};
		my $document = $cmd->{document};

		#croak 'Document incomplete' unless defined $default_field
			#and defined $query and defined $document;

		$content .= "  <document>\n";

		$content .= '    <removequery defaultfield="'
			. _xml_escape($default_field, 1) . '">'
			. _xml_escape($query) . "</removequery>\n";

		while ( my ($key, $value) = each %$document ) {
			$content .=  '    <field name="'
				. _xml_escape($key, 1) . '">'
				. _xml_escape($value)
				. "</field>\n";
		}

		$content .= "  </document>\n";
	}
	
	return $content;
}


sub _make_service_url
{
	my ($method, %args) = @_;

	return "http://$args{host}:$args{port}/"
		. uri_escape($args{context})
		. '/' . uri_escape($args{index}) . "/$method";
}


sub _post_data
{
	my ($url, $content) = @_;

	my $request = HTTP::Request->new(POST => $url);
	$request->content($content);

	my $ua = new LWP::UserAgent();

	return $ua->request($request);
}


1;
__END__

=head1 NAME

Net::LuceneWS - Interface to the Lucene Web Service

=head1 SYNOPSIS

  use Net::LuceneWS;

  my $ws = new Net::LuceneWS(
    host     => 'localhost',
    port     => 8080,
    index    => 'musicindex',
    context  => 'context',
  );

  my $ret = $ws->Search('R.E.M.', max_hits=>5, default_field=>'artist')
    or die "Error: " . $ws->GetError() . "\n";

  foreach my $hit ( $ret->GetHits() ) {
	printf "%3d %s\n", $hit->GetScore(), $hit->GetField('artist');
  }

=head1 DESCRIPTION

Interface to the Lucene indexing and searching package via lucene-ws,
the Lucene Web Service.


=head1 METHODS

=over 4

=item new()

  new Net::LuceneWS(
      host           => 'localhost',
      port           => 8080,
      context        => 'lucene',
      index          => 'musicindex',
      max_hits       => 25,
      default_field  => 'artist',
      debug          => 1,
  );

Create a new Net::LuceneWS object. This constructor expects a hash of
configuration settings. Alternatively, you can pass the same arguments
to each of the methods described above. In this case they take
precedence over arguments passed to the constructor.

C<host>, C<port>, C<context> and C<index> are always required, either
when calling the constructor or for each method call.

If you set up lucene-ws as suggested, C<context> has to be set to
"lucene". C<index> is the name of the index directory. C<max_hits>
set the maximum number of hits returned by the C<Search()> method.
C<default_field> is the default field that is used for the query. If
C<debug> is set to 1 the network dialog is printed to I<stderr>.


=item Search()

  my $results = $ws->Search('Tori Amos', %args);

Search the web service. The first parameter is the query string,
the other parameters are the same as those for the constructor. The
arguments C<max_hits> and C<default_field> are required, additional to
those listed in C<new()>.

This method returns a Net::LuceneWS::SearchResults object or undef
on error. In this case an error message is available via C<GetError()>.


=item AddDocuments()

  my @docs = (
    { id => '1', artist => 'Tori Amos', track => 'Northern Lad' },
    { id => '2', artist => 'R.E.M.', track => 'Falls to Climb' },
  );
  $ws->AddDocuments(\@docs, %args);

Add one or more documents to the index. Each document is a hashref


If the index doesn't exist yet it is created. In this case you have to
pass an C<analyzer> argument. Valid values are "SimpleAnalyzer",
"StopAnalyzer", "StandardAnalyzer" and "WithStopAnalyzer". After the
analyzer argument is no longer required.


=item UpdateDocuments()

  my %update = (
    default_field => 'id',
    query => '1',
    document => { id => 1, artist => 'Heather Nova', track => 'Storm' },
  );

  $ws->UpdateDocuments([\%update], %args);

Update the matching documents. This is basically a combination of
the delete and add methods.


=item DeleteDocuments()

  my @delete = (
    { default_field => 'artist', query => 'R.E.M.' },
  );
  $ws->DeleteDocuments(\@delete, %args);

Delete all documents matching the queries.


=item Optimize()

  $ws->Optimize();

Optimize the index which results in a speedup of queries. This method
should be called after making larger changes to the index.


=item GetError()

Get the error message returned by lucene-ws.


=head1 BUGS

Diagnostics could be better but that is partly due to lucene-ws.


=head1 SEE ALSO

http://lucene-ws.sourceforge.net
http://lucene.apache.org

=head1 AUTHOR

Matthias Friedrich, E<lt>matt@mafr.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Matthias Friedrich

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
