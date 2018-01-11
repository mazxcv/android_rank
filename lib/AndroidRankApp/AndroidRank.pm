package AndroidRankApp::AndroidRank;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::URL;
use JSON;
use Mojo::DOM;

sub suggest {

	my $self = shift;
	my $p    = $self->req->params->to_hash;
	return $self->render(
		status => 431,
		json   => { error => 'query_string is empty' }
	) unless $p->{q};

	my $config = $self->config('android_rank_app');
	my $url
		= Mojo::URL->new( $config->{url} )->path( $config->{api}->{suggest} )
		->query(
		{   callback        => 'jQuery',
			name_startsWith => $p->{q}
		}
		);

	my $tx   = $self->ua->get($url);
	my $res  = $tx->result;
	my $json = JSON->new;

# глухой костыль возвращается почти json типа: "jQuery({__module__: "searchjson", __doc__: null,geonames:[{ranks: 4142298, name: "Uber", appid: "com.ubercab"},…]});"
	my $data;
	if ( $res->is_success && $res->code == 200 ) {
		my ($answer) = $res->body =~ /\{.*\}/g;
		$data = $json->decode($answer)->{geonames};
		$data = [ map { { ext_id => $_->{appid}, title => $_->{name} } }
				@$data ];
	}

	return $self->render(
		status => $res->code,
		json   => { error => 'Server unavailable' }
	) unless scalar @$data;

	return $self->render( json => $data );

}

sub get_app_details {

	my $self = shift;
	my $p    = $self->req->params->to_hash;
	return $self->render(
		status => 431,
		json   => { error => 'query_string is empty' }
	) unless $p->{ext_id};

	# Будем использовать их 301 с /details?id=
	my $config = $self->config('android_rank_app');
	my $url
		= Mojo::URL->new( $config->{url} )
		->path( $config->{api}->{get_app_details} )
		->query( { id => $p->{ext_id} } );

	my $tx  = $self->ua->max_redirects(3)->get($url);
	my $res = $tx->res;

	my $data;
	if ( $res->is_success && $res->code == 200 ) {
		my $dom = $res->dom->find('[itemprop]');

		my $artist = [ grep { $_ =~ /developer/ }
				@{ $res->dom->find('div[itemscope] small a') } ]->[0];
		my $app_all = $res->dom->find('div[itemscope] table.appstat');

		$data = {
			title       => $res->dom->find('[itemprop=name]')->[0]->text,
			artist_id   => $artist->attr('href') =~ /id=(\w+)/ ? $1 : 0,
			artist_name => $artist->text,
			short_text  => $res->dom->find('div[itemscope] div p')->[0]->text,
			icon => $res->dom->find('[itemprop=image]')->[0]->attr('src'),

			app_info => $app_all->[0]->find('tr')->map(
				sub {
					my $d = Mojo::DOM->new->parse(shift);
					+{         $d->at('th')->text => $d->at('td')->text
							|| $d->at('a')->text };
				}
			),
			rating_score => $app_all->[1]->find('tr')->map(
				sub {
					my $d = Mojo::DOM->new->parse(shift);
					+{ $d->at('th')->text => $d->at('td')->text };
				}
			),
			app_installs => $app_all->[2]->find('tbody')->map(
				sub {
					my $d = Mojo::DOM->new->parse(shift);
					+{ $d->at('th')->text => $d->at('td')->text };
				}
			),
			rating_values => $app_all->[3]->find('tbody')->map(
				sub {
					my $d = Mojo::DOM->new->parse(shift);
					+{ $d->at('th')->text => $d->at('td')->text };
				}
			),
			country_rankings =>
				$res->dom->find('div[itemscope] div span.flagholder')->map(
				sub {
					my $d = Mojo::DOM->new->parse(shift);
					+{  title => $d->at('span')->attr('title'),
						value => $d->at('span')->text,
						img   => +{
							map { $_ => $d->at('img')->attr($_) }
								qw/alt class src/
						},
					};
				}
				),
		};

	}

	return $self->render(
		status => $res->code,
		json   => { error => 'Server unavailable' }
	) unless scalar keys %$data;

	return $self->render( json => $data );

}

1;
