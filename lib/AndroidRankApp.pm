package AndroidRankApp;
use Mojo::Base 'Mojolicious';
use Data::Dumper;

# This method will run once at server start
sub startup {
	my $self = shift;

	# Load configuration from hash returned by "my_app.conf"
	my $config = $self->plugin('Config');

	# Documentation browser under "/perldoc"
	$self->plugin('PODRenderer') if $config->{perldoc};

	push @{$self->static->paths}, $config->{path}->{data};

	my $r = $self->routes;
	$r->get('/')->to('hello#hello');
	$r->get('/suggest')->to('android_rank#suggest');
	$r->get('/get_app_details')->to('android_rank#get_app_details');
}

1;
